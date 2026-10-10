import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../app_services.dart';
import '../core/api/api_exception.dart';
import '../core/location/gps_tracking_service.dart';
import '../core/location/location_service.dart';
import '../models/student.dart';
import '../models/transport.dart';
import '../models/trip.dart';
import '../models/user.dart';
import '../services/route_geometry_service.dart';

/// State for the Driver and Helper trip dashboards. It reproduces the web
/// dashboards' behaviour (pages/driver/Dashboard.jsx, pages/helper/Dashboard.jsx):
/// the backend decides every transition; this only calls the same endpoints
/// and shows what they return.
class OperatorTripController extends ChangeNotifier {
  OperatorTripController(this._s) {
    _gpsSub = _s.gps.statusStream.listen(_onGpsStatus);
    _setupWs();
  }

  final AppServices _s;
  StreamSubscription<GpsStatus>? _gpsSub;
  Timer? _poll;

  /// Same refresh cadence as the web dashboards.
  static const pollInterval = Duration(seconds: 10);

  AppUser? _user;
  bool loading = true;
  String? loadError;
  bool acting = false;

  List<RouteInfo> routes = const [];
  String? selectedRouteId;
  List<Trip> todaysTrips = const [];
  Trip? trip;
  List<AttendanceRecord> roster = const [];
  SchoolSettings settings = const SchoolSettings();
  BusLocation? busLocation;
  RouteGeometry? geometry;
  String? _geometryTripId;

  GpsStatus gpsStatus = GpsStatus.idle;
  bool locationAccessMissing = false;

  bool get isDriver => _user?.isDriver ?? false;
  bool get hasActiveTrip => trip?.isActive ?? false;

  RouteInfo? get selectedRoute {
    for (final r in routes) {
      if (r.publicId == selectedRouteId) return r;
    }
    return routes.isEmpty ? null : routes.first;
  }

  /// Mirrors the web's isMorningDone/isAfternoonDone: a route's morning or
  /// evening run is locked once today's run of that type completed or was cancelled.
  Trip? finishedTripFor(String routeId, String tripType) {
    for (final t in todaysTrips) {
      if (t.routeId == routeId && t.tripType == tripType && t.isFinished) return t;
    }
    return null;
  }

  /// Students expected at the current stop (the web shows the same subset).
  List<AttendanceRecord> get rosterAtCurrentStop {
    final stopId = trip?.currentStop?.publicId;
    if (stopId == null) return const [];
    return roster.where((r) => r.stop?.publicId == stopId).toList();
  }

  void attach(AppUser user) {
    if (_user?.publicId == user.publicId) return;
    reset();
    _user = user;
  }

  void selectRoute(String routeId) {
    selectedRouteId = routeId;
    notifyListeners();
  }

  Future<void> load() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _s.trips.today(),
        _s.trips.myRoutes(),
        _s.transport.schoolSettings().catchError((_) => const SchoolSettings()),
        _s.trips.forDate(DateTime.now()).catchError((_) => <Trip>[]),
      ]);
      trip = results[0] as Trip?;
      routes = results[1] as List<RouteInfo>;
      settings = results[2] as SchoolSettings;
      todaysTrips = results[3] as List<Trip>;
      if (selectedRouteId == null || !routes.any((r) => r.publicId == selectedRouteId)) {
        selectedRouteId = routes.isEmpty ? null : routes.first.publicId;
      }
      await _loadTripDetails();
    } catch (e) {
      loadError = describeError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
    await _syncTracking();
    _restartPolling();
  }

  Future<void> refresh() async {
    try {
      final previousStatus = trip?.status;
      final previousId = trip?.publicId;
      trip = await _s.trips.today();
      if (trip?.status != previousStatus || trip?.publicId != previousId) {
        todaysTrips = await _s.trips.forDate(DateTime.now()).catchError((_) => todaysTrips);
      }
      await _loadTripDetails();
      loadError = null;
    } catch (e) {
      // Keep showing the last known state; polling retries.
      if (e is ApiException && !e.isRetryable) loadError = e.message;
    }
    notifyListeners();
    await _syncTracking();
    _restartPolling();
  }

  Future<void> _loadTripDetails() async {
    final t = trip;
    if (t == null || !t.isActive) {
      roster = const [];
      busLocation = null;
      return;
    }
    roster = await _s.attendance.roster().catchError((_) => roster);
    final busId = t.bus?.publicId;
    if (!isDriver && busId != null && busId.isNotEmpty) {
      busLocation = await _s.transport.busLocation(busId).catchError((_) => busLocation);
    }
    if (_geometryTripId != t.publicId) {
      _geometryTripId = t.publicId;
      final points = t.tripStops
          .map((ts) => ts.stop)
          .whereType<StopRef>()
          .where((s) => s.hasPosition)
          .map((s) => LatLng(s.latitude!, s.longitude!))
          .toList();
      geometry = await _s.geometry.forStops(points);
    }
  }

  void _restartPolling() {
    // Polling removed in favour of WebSocket events.
  }

  void pausePolling() {}
  void resumePolling() {}

  void _onWsEvent(Map<String, dynamic> data) {
    if (_user == null) return;
    
    // We can infer the event type from the payload keys, but better to let the service pass it if needed.
    // However, for bus.location.updated, we check if it has latitude.
    if (data.containsKey('latitude') && data.containsKey('longitude') && data.containsKey('bus_id')) {
      if (trip?.publicId == data['trip_id'] && !isDriver) {
        busLocation = BusLocation.fromJsonOrNull(data);
        notifyListeners();
      }
      return;
    }
    
    refresh();
  }

  void _setupWs() {
    _s.webSocket.subscribe('trip.started', _onWsEvent);
    _s.webSocket.subscribe('trip.ended', _onWsEvent);
    _s.webSocket.subscribe('trip.stop.updated', _onWsEvent);
    _s.webSocket.subscribe('route.updated', _onWsEvent);
    _s.webSocket.subscribe('attendance.updated', _onWsEvent);
    _s.webSocket.subscribe('bus.location.updated', _onWsEvent);
  }

  void _teardownWs() {
    _s.webSocket.unsubscribe('trip.started', _onWsEvent);
    _s.webSocket.unsubscribe('trip.ended', _onWsEvent);
    _s.webSocket.unsubscribe('trip.stop.updated', _onWsEvent);
    _s.webSocket.unsubscribe('route.updated', _onWsEvent);
    _s.webSocket.unsubscribe('attendance.updated', _onWsEvent);
    _s.webSocket.unsubscribe('bus.location.updated', _onWsEvent);
  }

  // ---------------------------------------------------------------------------
  // GPS (driver only)
  // ---------------------------------------------------------------------------

  bool get _shouldTrack => isDriver && hasActiveTrip && settings.gpsTrackingEnabled;

  Future<void> _syncTracking() async {
    if (!isDriver) return;
    if (_shouldTrack) {
      final access = await _s.location.currentAccess();
      locationAccessMissing = access != LocationAccess.granted;
      if (!locationAccessMissing) await _s.gps.start();
    } else {
      locationAccessMissing = false;
      await _s.gps.stop();
    }
    notifyListeners();
  }

  /// "Enable location" banner action when tracking couldn't start.
  Future<void> requestLocationAndTrack(BuildContext context) async {
    await _s.location.ensureAccess(context);
    await _syncTracking();
  }

  void _onGpsStatus(GpsStatus status) {
    gpsStatus = status;
    if (status.stopReason == 'NO_ACTIVE_TRIP') refresh();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Actions. Each returns null on success or a user-readable error.
  // ---------------------------------------------------------------------------

  Future<String?> _act(Future<void> Function() body) async {
    if (acting) return null;
    acting = true;
    notifyListeners();
    try {
      await body();
      return null;
    } catch (e) {
      return describeError(e);
    } finally {
      acting = false;
      notifyListeners();
    }
  }

  /// Driver: Start Trip → location permission → current fix → POST /trips/start/ → live GPS.
  Future<String?> startTrip(BuildContext context, RouteInfo route, String tripType) async {
    final access = await _s.location.ensureAccess(context);
    if (access != LocationAccess.granted) {
      return 'Location permission is required to start a trip, so the bus can be tracked.';
    }
    return _act(() async {
      final position = await _s.location.currentPosition();
      if (position == null) {
        throw ApiException(ApiErrorKind.unknown, 'Could not get your GPS position. Check the signal and try again.');
      }
      trip = await _s.trips.start(
        routeId: route.publicId,
        tripType: tripType,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _geometryTripId = null;
      todaysTrips = await _s.trips.forDate(DateTime.now()).catchError((_) => todaysTrips);
      await _loadTripDetails();
      await _syncTracking();
      _restartPolling();
    });
  }

  Future<String?> beginDriving() => _tripAction((id) => _s.trips.begin(id));

  Future<String?> cancelTrip(String reason) => _tripAction((id) => _s.trips.cancel(id, reason));

  Future<String?> endTrip() => _tripAction((id) async {
        final position = await _s.location.currentPosition(timeout: const Duration(seconds: 8));
        return _s.trips.end(id, latitude: position?.latitude, longitude: position?.longitude);
      });

  Future<String?> advanceStop() => _tripAction((id) => _s.trips.advanceStop(id));

  Future<String?> notifyDelay(String message) async {
    final id = trip?.publicId;
    if (id == null) return 'No trip loaded.';
    return _act(() async {
      await _s.trips.notifyDelay(id, message: message);
    });
  }

  Future<String?> _tripAction(Future<Trip> Function(String tripId) call) {
    final id = trip?.publicId;
    if (id == null) return Future.value('No trip loaded.');
    return _act(() async {
      trip = await call(id);
      if (trip!.isFinished) {
        todaysTrips = await _s.trips.forDate(DateTime.now()).catchError((_) => todaysTrips);
      }
      await _loadTripDetails();
      await _syncTracking();
      _restartPolling();
    });
  }

  Future<String?> markStudent(String studentId, String status) => _act(() async {
        await _s.attendance.markManual(studentId, status);
        roster = await _s.attendance.roster();
      });

  Future<String?> verifyDrop(String studentId, String code) => _act(() async {
        await _s.attendance.verifyDrop(studentId, code);
        roster = await _s.attendance.roster();
      });

  /// Returns (message, isError).
  Future<(String, bool)> scanQr(String token) async {
    try {
      final message = await _s.attendance.scanQr(token);
      roster = await _s.attendance.roster().catchError((_) => roster);
      notifyListeners();
      return (message, false);
    } catch (e) {
      return (describeError(e), true);
    }
  }

  Future<String?> raiseSos(String message) => _act(() async {
        await _s.transport.raiseSos(message);
        trip = await _s.trips.today();
      });

  void reset() {
    _poll?.cancel();
    _user = null;
    loading = true;
    loadError = null;
    routes = const [];
    selectedRouteId = null;
    todaysTrips = const [];
    trip = null;
    roster = const [];
    busLocation = null;
    geometry = null;
    _geometryTripId = null;
    gpsStatus = GpsStatus.idle;
    locationAccessMissing = false;
  }

  @override
  void dispose() {
    _poll?.cancel();
    _gpsSub?.cancel();
    _teardownWs();
    super.dispose();
  }
}
