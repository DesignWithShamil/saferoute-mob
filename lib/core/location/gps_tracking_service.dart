import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../api/api_client.dart';
import '../api/api_endpoints.dart';
import '../api/api_exception.dart';
import '../notifications/notification_channels.dart';
import '../storage/token_storage.dart';

/// Tracking states surfaced to the driver UI.
class GpsState {
  GpsState._();
  static const starting = 'STARTING';
  static const active = 'ACTIVE';
  static const weakSignal = 'SIGNAL_WEAK';
  static const offline = 'OFFLINE';
  static const gpsOff = 'GPS_OFF';
  static const permissionDenied = 'PERMISSION_DENIED';
  static const error = 'ERROR';
  static const stopped = 'STOPPED';
}

class GpsStatus {
  const GpsStatus({
    required this.state,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.lastSentAt,
    this.queued = 0,
    this.message,
    this.stopReason,
  });

  final String state;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final DateTime? lastSentAt;
  final int queued;
  final String? message;

  /// Why the service stopped itself: NO_ACTIVE_TRIP, SESSION_EXPIRED, PERMISSION_DENIED.
  final String? stopReason;

  static const idle = GpsStatus(state: GpsState.stopped);

  factory GpsStatus.fromMap(Map<String, dynamic> m) => GpsStatus(
        state: m['state'] as String? ?? GpsState.stopped,
        latitude: (m['lat'] as num?)?.toDouble(),
        longitude: (m['lng'] as num?)?.toDouble(),
        accuracy: (m['accuracy'] as num?)?.toDouble(),
        lastSentAt: m['last_sent_at'] == null ? null : DateTime.tryParse(m['last_sent_at'] as String)?.toLocal(),
        queued: (m['queued'] as num?)?.toInt() ?? 0,
        message: m['message'] as String?,
        stopReason: m['stop_reason'] as String?,
      );
}

/// UI-side handle for the trip GPS foreground service.
///
/// The reporter itself runs in a separate isolate owned by an Android
/// foreground service of type `location`, so updates keep flowing while the
/// app is backgrounded or the screen is off. It is started only for an active
/// trip and stops itself when the backend reports no active trip.
class GpsTrackingService {
  final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> configure() async {
    await FlutterBackgroundService().configure(
      androidConfiguration: AndroidConfiguration(
        onStart: gpsServiceEntryPoint,
        autoStart: false,
        autoStartOnBoot: false,
        isForegroundMode: true,
        notificationChannelId: NotificationChannels.trackingId,
        initialNotificationTitle: 'SafeRoute trip in progress',
        initialNotificationContent: 'Sharing live bus location',
        foregroundServiceNotificationId: NotificationChannels.trackingNotificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: gpsServiceEntryPoint,
        onBackground: _iosBackground,
      ),
    );
  }

  Future<bool> get isRunning => _service.isRunning();

  Stream<GpsStatus> get statusStream => _service
      .on(_TripGpsReporter.statusEvent)
      .where((e) => e != null)
      .map((e) => GpsStatus.fromMap(e!));

  Future<void> start() async {
    if (!await _service.isRunning()) await _service.startService();
    _service.invoke(_TripGpsReporter.pingEvent);
  }

  void requestStatus() => _service.invoke(_TripGpsReporter.pingEvent);

  Future<void> stop() async {
    if (await _service.isRunning()) _service.invoke(_TripGpsReporter.stopEvent);
  }
}

@pragma('vm:entry-point')
Future<bool> _iosBackground(ServiceInstance service) async => true;

@pragma('vm:entry-point')
void gpsServiceEntryPoint(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  _TripGpsReporter(service).run();
}

class _QueuedPoint {
  _QueuedPoint(this.payload);
  final Map<String, dynamic> payload;
}

class _TripGpsReporter {
  _TripGpsReporter(this.service);

  static const statusEvent = 'gps_status';
  static const stopEvent = 'gps_stop';
  static const pingEvent = 'gps_ping';

  /// Same cadence as the web driver dashboard (useGpsReporter.js).
  static const reportInterval = Duration(seconds: 10);

  /// Bounded offline buffer: ~10 minutes of points at the report interval.
  static const maxQueued = 60;

  /// Stay well inside the backend's 120/min `gps` throttle when catching up.
  static const maxFlushPerReport = 10;

  final ServiceInstance service;
  late final ApiClient _api;
  final Queue<_QueuedPoint> _queue = Queue();

  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;
  Position? _last;
  DateTime? _lastFixAt;
  DateTime? _lastSentAt;
  DateTime? _lastAttemptAt;
  bool _sending = false;
  bool _stopping = false;
  String _state = GpsState.starting;
  String? _message;

  void run() {
    _api = ApiClient(
      storage: TokenStorage(),
      onSessionExpired: () async => _shutdown(reason: 'SESSION_EXPIRED', message: 'Session expired. Sign in again.'),
    );
    service.on(stopEvent).listen((_) => _shutdown(reason: null));
    service.on(pingEvent).listen((_) => _emit());
    _subscribe();
    _ticker = Timer.periodic(reportInterval, (_) => _tick());
    _emit();
  }

  Future<void> _subscribe() async {
    await _positionSub?.cancel();
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      await _shutdown(reason: 'PERMISSION_DENIED', message: 'Location permission was revoked.');
      return;
    }
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _settings(const Duration(seconds: 5)),
    ).listen(
      _onPosition,
      onError: (Object e) async {
        await _positionSub?.cancel();
        _positionSub = null;
        if (e is LocationServiceDisabledException && !_useLocationManager && await Geolocator.isLocationServiceEnabled()) {
          // Location is on, but the fused provider's settings check failed
          // (e.g. Google "Location Accuracy" declined) and can't be resolved
          // from a background service. The platform GPS provider has no such check.
          _useLocationManager = true;
          await _subscribe();
          return;
        }
        _setState(e is LocationServiceDisabledException ? GpsState.gpsOff : GpsState.error,
            e is LocationServiceDisabledException ? 'GPS is turned off.' : 'Unable to read GPS.');
      },
    );
  }

  bool _useLocationManager = false;

  AndroidSettings _settings(Duration interval, {Duration? timeLimit}) => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: interval,
        timeLimit: timeLimit,
        forceLocationManager: _useLocationManager,
      );

  void _onPosition(Position p) {
    _last = p;
    _lastFixAt = DateTime.now();
    if (_state == GpsState.gpsOff || _state == GpsState.starting || _state == GpsState.error) {
      _setState(GpsState.active, null);
    }
    final last = _lastAttemptAt;
    if (last == null || DateTime.now().difference(last) >= reportInterval) {
      _report(p);
    } else {
      _emit();
    }
  }

  Future<void> _tick() async {
    if (_stopping) return;
    if (_positionSub == null) await _subscribe();

    final fixAge = _lastFixAt == null ? null : DateTime.now().difference(_lastFixAt!);
    if (fixAge == null || fixAge > const Duration(seconds: 20)) {
      // Android may throttle the stream when stationary; ask for a fresh fix.
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: _settings(Duration.zero, timeLimit: const Duration(seconds: 8)),
        );
        _onPosition(p);
        return;
      } catch (_) {
        // Fall through to flushing whatever is queued.
      }
    }
    if (_queue.isNotEmpty) await _flush();
  }

  Map<String, dynamic> _payload(Position p) => {
        'latitude': double.parse(p.latitude.toStringAsFixed(6)),
        'longitude': double.parse(p.longitude.toStringAsFixed(6)),
        'speed_kmh': p.speed >= 0 ? double.parse((p.speed * 3.6).clamp(0, 999).toStringAsFixed(2)) : null,
        'heading': p.heading >= 0 ? double.parse(p.heading.toStringAsFixed(2)) : null,
        'accuracy_meters': double.parse(p.accuracy.clamp(0, 9999).toStringAsFixed(2)),
        'recorded_at': p.timestamp.toUtc().toIso8601String(),
      };

  Future<void> _report(Position p) async {
    _lastAttemptAt = DateTime.now();
    _enqueue(_payload(p));
    await _flush();
  }

  void _enqueue(Map<String, dynamic> payload) {
    _queue.addLast(_QueuedPoint(payload));
    while (_queue.length > maxQueued) {
      _queue.removeFirst();
    }
  }

  /// Sends queued points oldest-first so the server sees them in order.
  Future<void> _flush() async {
    if (_sending || _stopping) return;
    _sending = true;
    var sent = 0;
    try {
      while (_queue.isNotEmpty && sent < maxFlushPerReport && !_stopping) {
        final point = _queue.first;
        try {
          await _api.post(ApiEndpoints.gpsLocation, data: point.payload);
          _queue.removeFirst();
          sent++;
          _lastSentAt = DateTime.now();
          final acc = _last?.accuracy ?? 0;
          _setState(acc > 50 ? GpsState.weakSignal : GpsState.active, null, notify: false);
        } on ApiException catch (e) {
          if (e.kind == ApiErrorKind.conflict) {
            await _shutdown(reason: 'NO_ACTIVE_TRIP', message: 'Trip is no longer active.');
            return;
          }
          if (e.kind == ApiErrorKind.unauthorized) {
            await _shutdown(reason: 'SESSION_EXPIRED', message: 'Session expired. Sign in again.');
            return;
          }
          if (e.kind == ApiErrorKind.validation) {
            _queue.removeFirst(); // A rejected point will never succeed; drop it.
            continue;
          }
          // Offline, timeout, 5xx or throttled: keep the point and retry next tick.
          _setState(e.kind == ApiErrorKind.network ? GpsState.offline : GpsState.error, e.message, notify: false);
          break;
        }
      }
    } finally {
      _sending = false;
      _emit();
      _updateNotification();
    }
  }

  void _setState(String state, String? message, {bool notify = true}) {
    _state = state;
    _message = message;
    if (notify) _emit();
  }

  void _emit({String? stopReason}) {
    service.invoke(statusEvent, {
      'state': _state,
      'lat': _last?.latitude,
      'lng': _last?.longitude,
      'accuracy': _last?.accuracy,
      'last_sent_at': _lastSentAt?.toUtc().toIso8601String(),
      'queued': _queue.length,
      'message': _message,
      'stop_reason': stopReason,
    });
  }

  void _updateNotification() {
    final s = service;
    if (s is! AndroidServiceInstance) return;
    final sent = _lastSentAt;
    final time = sent == null
        ? 'waiting for first update'
        : 'last sent ${sent.hour.toString().padLeft(2, '0')}:${sent.minute.toString().padLeft(2, '0')}';
    final content = switch (_state) {
      GpsState.offline => 'No connection – ${_queue.length} update(s) queued',
      GpsState.gpsOff => 'GPS is off – turn on location',
      _ => 'Sharing live bus location · $time',
    };
    s.setForegroundNotificationInfo(title: 'SafeRoute trip in progress', content: content);
  }

  Future<void> _shutdown({required String? reason, String? message}) async {
    if (_stopping) return;
    _stopping = true;
    _ticker?.cancel();
    await _positionSub?.cancel();
    _state = GpsState.stopped;
    _message = message;
    _emit(stopReason: reason);
    await service.stopSelf();
  }
}
