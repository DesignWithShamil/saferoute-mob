import 'json.dart';
import 'transport.dart';
import 'trip.dart';

/// One stop inside a `/api/gps/parent-live/` trip payload.
class LiveStop {
  const LiveStop({
    required this.sequence,
    required this.status,
    required this.name,
    this.publicId,
    this.latitude,
    this.longitude,
    this.radius,
    this.arrivedAt,
    this.departedAt,
    this.pickupTime,
    this.dropTime,
  });

  final int sequence;
  final String status;
  final String name;
  final String? publicId;
  final double? latitude;
  final double? longitude;
  final int? radius;
  final DateTime? arrivedAt;
  final DateTime? departedAt;
  final String? pickupTime;
  final String? dropTime;

  factory LiveStop.fromJson(Map<String, dynamic> json) => LiveStop(
        sequence: asInt(json['sequence']) ?? 0,
        status: asString(json['status']) ?? TripStopStatus.pending,
        name: asString(json['name']) ?? 'Stop',
        publicId: asString(json['public_id']),
        latitude: asDouble(json['latitude']),
        longitude: asDouble(json['longitude']),
        radius: asInt(json['radius']),
        arrivedAt: asDate(json['arrived_at']),
        departedAt: asDate(json['departed_at']),
        pickupTime: asString(json['pickup_time']),
        dropTime: asString(json['drop_time']),
      );
}

/// One element of `/api/gps/parent-live/`: a child on a currently active trip.
class ParentLiveTrip {
  const ParentLiveTrip({
    required this.childId,
    required this.childName,
    required this.childStatus,
    required this.tripId,
    required this.tripStatus,
    this.childStopId,
    this.schoolName = '',
    this.tripType = '',
    this.busNumber = '',
    this.routeName = '',
    this.currentStopName,
    this.startedAt,
    this.endedAt,
    this.stops = const [],
    this.location,
  });

  final String childId;
  final String childName;
  final String childStatus;
  final String? childStopId;
  final String schoolName;
  final String tripType;
  final String tripId;
  final String tripStatus;
  final String busNumber;
  final String routeName;
  final String? currentStopName;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final List<LiveStop> stops;
  final BusLocation? location;

  /// The backend sets Trip.current_stop to the first stop not yet departed,
  /// so the same rule identifies it here (the payload only carries its name).
  LiveStop? get nextStop {
    for (final s in stops) {
      if (s.status == TripStopStatus.pending || s.status == TripStopStatus.arrived) return s;
    }
    return null;
  }

  LiveStop? get childStop {
    if (childStopId == null) return null;
    for (final s in stops) {
      if (s.publicId == childStopId) return s;
    }
    return null;
  }

  factory ParentLiveTrip.fromJson(Map<String, dynamic> json) {
    final child = asMap(json['child']);
    final trip = asMap(json['trip']);
    return ParentLiveTrip(
      childId: asString(child['public_id']) ?? '',
      childName: asString(child['name']) ?? '',
      childStatus: asString(child['status']) ?? '',
      childStopId: asString(child['stop_id']),
      schoolName: asString(asMap(child['school'])['name']) ?? '',
      tripType: asString(trip['trip_type']) ?? '',
      tripId: asString(trip['public_id']) ?? '',
      tripStatus: asString(trip['status']) ?? '',
      busNumber: asString(trip['bus_number']) ?? '',
      routeName: asString(trip['route_name']) ?? '',
      currentStopName: asString(trip['current_stop']),
      startedAt: asDate(trip['started_at']),
      endedAt: asDate(trip['ended_at']),
      stops: asList(trip['stops'], LiveStop.fromJson)..sort((a, b) => a.sequence.compareTo(b.sequence)),
      location: BusLocation.fromJsonOrNull(json['location']),
    );
  }
}
