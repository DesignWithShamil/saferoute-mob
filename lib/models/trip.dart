import 'json.dart';
import 'transport.dart';

/// Values of `Trip.trip_type` / `Trip.status` / `TripStop.status` exactly as
/// the backend defines them (apps/trips/models.py).
class TripType {
  TripType._();
  static const morning = 'MORNING';
  static const afternoon = 'AFTERNOON';

  /// The web app labels AFTERNOON as "Evening"; mobile uses the same wording.
  static String label(String type) => type == morning ? 'Morning' : 'Evening';
}

class TripStatus {
  TripStatus._();
  static const scheduled = 'SCHEDULED';
  static const ready = 'READY';
  static const started = 'STARTED';
  static const inProgress = 'IN_PROGRESS';
  static const paused = 'PAUSED';
  static const completed = 'COMPLETED';
  static const cancelled = 'CANCELLED';
  static const emergency = 'EMERGENCY';

  /// Trip.ACTIVE_STATUSES on the backend.
  static const active = {started, inProgress, paused, emergency};
  static const finished = {completed, cancelled};

  static String label(String status) => switch (status) {
        started => 'Started',
        inProgress => 'In progress',
        paused => 'Paused',
        completed => 'Completed',
        cancelled => 'Cancelled',
        emergency => 'Emergency',
        scheduled => 'Scheduled',
        ready => 'Ready',
        _ => status,
      };
}

class TripStopStatus {
  TripStopStatus._();
  static const pending = 'PENDING';
  static const arrived = 'ARRIVED';
  static const departed = 'DEPARTED';
  static const skipped = 'SKIPPED';

  static String label(String status) => switch (status) {
        pending => 'Pending',
        arrived => 'Arrived',
        departed => 'Departed',
        skipped => 'Skipped',
        _ => status,
      };
}

class TripStop {
  const TripStop({
    required this.publicId,
    required this.sequence,
    required this.status,
    this.stop,
    this.arrivedAt,
    this.departedAt,
  });

  final String publicId;
  final StopRef? stop;
  final int sequence;
  final String status;
  final DateTime? arrivedAt;
  final DateTime? departedAt;

  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
        publicId: asString(json['public_id']) ?? '',
        stop: StopRef.fromJsonOrNull(json['stop']),
        sequence: asInt(json['sequence']) ?? 0,
        status: asString(json['status']) ?? TripStopStatus.pending,
        arrivedAt: asDate(json['arrived_at']),
        departedAt: asDate(json['departed_at']),
      );
}

class Trip {
  const Trip({
    required this.publicId,
    required this.tripType,
    required this.status,
    this.routeId,
    this.routeName = '',
    this.routeType,
    this.bus,
    this.driver,
    this.helper,
    this.date,
    this.currentStop,
    this.startedAt,
    this.endedAt,
    this.cancellationReason = '',
    this.tripStops = const [],
  });

  final String publicId;
  final String? routeId;
  final String routeName;
  final String? routeType;
  final BusRef? bus;
  final PersonRef? driver;
  final PersonRef? helper;
  final String tripType;
  final String? date;
  final String status;
  final StopRef? currentStop;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String cancellationReason;

  /// Already in the order the backend computed at trip start (afternoon runs
  /// of BOTH routes are reversed server-side). Never re-ordered on the client.
  final List<TripStop> tripStops;

  bool get isActive => TripStatus.active.contains(status);
  bool get isFinished => TripStatus.finished.contains(status);
  bool get isMorning => tripType == TripType.morning;
  bool get isAfternoon => tripType == TripType.afternoon;

  TripStop? get currentTripStop {
    final id = currentStop?.publicId;
    if (id == null) return null;
    for (final ts in tripStops) {
      if (ts.stop?.publicId == id) return ts;
    }
    return null;
  }

  factory Trip.fromJson(Map<String, dynamic> json) {
    final route = asMap(json['route']);
    return Trip(
      publicId: asString(json['public_id']) ?? '',
      routeId: asString(route['public_id']),
      routeName: asString(route['name']) ?? '',
      routeType: asString(route['route_type']),
      bus: BusRef.fromJsonOrNull(json['bus']),
      driver: PersonRef.fromJsonOrNull(json['driver']),
      helper: PersonRef.fromJsonOrNull(json['helper']),
      tripType: asString(json['trip_type']) ?? TripType.morning,
      date: asString(json['date']),
      status: asString(json['status']) ?? '',
      currentStop: StopRef.fromJsonOrNull(json['current_stop']),
      startedAt: asDate(json['started_at']),
      endedAt: asDate(json['ended_at']),
      cancellationReason: asString(json['cancellation_reason']) ?? '',
      tripStops: asList(json['trip_stops'], TripStop.fromJson)..sort((a, b) => a.sequence.compareTo(b.sequence)),
    );
  }
}
