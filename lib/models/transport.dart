import 'json.dart';

class BusRef {
  const BusRef({required this.publicId, required this.busNumber, this.registrationNumber = ''});

  final String publicId;
  final String busNumber;
  final String registrationNumber;

  static BusRef? fromJsonOrNull(dynamic json) {
    if (json is! Map) return null;
    final map = asMap(json);
    return BusRef(
      publicId: asString(map['public_id']) ?? asString(map['id']) ?? '',
      busNumber: asString(map['bus_number']) ?? '',
      registrationNumber: asString(map['registration_number']) ?? '',
    );
  }
}

class PersonRef {
  const PersonRef({required this.fullName, this.phone = '', this.publicId});

  final String? publicId;
  final String fullName;
  final String phone;

  static PersonRef? fromJsonOrNull(dynamic json) {
    if (json is! Map) return null;
    final map = asMap(json);
    return PersonRef(
      publicId: asString(map['public_id']),
      fullName: asString(map['full_name']) ?? '',
      phone: asString(map['phone']) ?? '',
    );
  }
}

/// A route stop as returned by RouteStopSerializer / RouteStopMiniSerializer.
class StopRef {
  const StopRef({
    required this.publicId,
    required this.name,
    required this.sequence,
    this.latitude,
    this.longitude,
    this.pickupTime,
    this.dropTime,
    this.radius,
    this.address = '',
  });

  final String publicId;
  final String name;
  final int sequence;
  final double? latitude;
  final double? longitude;
  final String? pickupTime;
  final String? dropTime;
  final int? radius;
  final String address;

  bool get hasPosition => latitude != null && longitude != null;

  static StopRef? fromJsonOrNull(dynamic json) => json is Map ? StopRef.fromJson(asMap(json)) : null;

  factory StopRef.fromJson(Map<String, dynamic> json) => StopRef(
        publicId: asString(json['public_id']) ?? '',
        name: asString(json['name']) ?? 'Stop',
        sequence: asInt(json['sequence']) ?? 0,
        latitude: asDouble(json['latitude']),
        longitude: asDouble(json['longitude']),
        pickupTime: asString(json['pickup_time']),
        dropTime: asString(json['drop_time']),
        radius: asInt(json['radius']),
        address: asString(json['address']) ?? '',
      );
}

class RouteType {
  RouteType._();
  static const morning = 'MORNING';
  static const afternoon = 'AFTERNOON';
  static const both = 'BOTH';
}

class RouteInfo {
  const RouteInfo({
    required this.publicId,
    required this.name,
    required this.routeType,
    this.bus,
    this.driver,
    this.helper,
    this.stops = const [],
  });

  final String publicId;
  final String name;
  final String routeType;
  final BusRef? bus;
  final PersonRef? driver;
  final PersonRef? helper;
  final List<StopRef> stops;

  bool get runsMorning => routeType == RouteType.morning || routeType == RouteType.both;
  bool get runsAfternoon => routeType == RouteType.afternoon || routeType == RouteType.both;

  factory RouteInfo.fromJson(Map<String, dynamic> json) => RouteInfo(
        publicId: asString(json['public_id']) ?? '',
        name: asString(json['name']) ?? '',
        routeType: asString(json['route_type']) ?? RouteType.both,
        bus: BusRef.fromJsonOrNull(json['bus']),
        driver: PersonRef.fromJsonOrNull(json['driver']),
        helper: PersonRef.fromJsonOrNull(json['helper']),
        stops: asList(json['stops'], StopRef.fromJson)..sort((a, b) => a.sequence.compareTo(b.sequence)),
      );
}

class BusLocation {
  const BusLocation({
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    this.heading,
    this.accuracyMeters,
    this.recordedAt,
  });

  final double latitude;
  final double longitude;
  final double? speedKmh;
  final double? heading;
  final double? accuracyMeters;
  final DateTime? recordedAt;

  Duration? get age => recordedAt == null ? null : DateTime.now().difference(recordedAt!);

  /// Matches the web parent dashboard: older than 60s is shown as possibly outdated.
  bool get isStale => age == null || age!.inSeconds > 60;

  static BusLocation? fromJsonOrNull(dynamic json) {
    if (json is! Map) return null;
    final map = asMap(json);
    final lat = asDouble(map['latitude']);
    final lng = asDouble(map['longitude']);
    if (lat == null || lng == null) return null;
    return BusLocation(
      latitude: lat,
      longitude: lng,
      speedKmh: asDouble(map['speed_kmh'] ?? map['speed']),
      heading: asDouble(map['heading']),
      accuracyMeters: asDouble(map['accuracy_meters'] ?? map['accuracy']),
      recordedAt: asDate(map['recorded_at']),
    );
  }
}
