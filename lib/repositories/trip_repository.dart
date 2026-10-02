import 'package:intl/intl.dart';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/json.dart';
import '../models/transport.dart';
import '../models/trip.dart';

class TripRepository {
  TripRepository(this._api);

  final ApiClient _api;

  /// The caller's active trip, else today's latest, else null (`/api/trips/today/`).
  Future<Trip?> today() async {
    final data = await _api.get(ApiEndpoints.tripToday);
    return data is Map && data.isNotEmpty ? Trip.fromJson(asMap(data)) : null;
  }

  /// Recent trips for driver/helper history (queryset is scoped server-side).
  Future<List<Trip>> recent({int pageSize = 50}) async {
    final rows = await _api.getList(ApiEndpoints.trips, query: {'page_size': pageSize});
    return rows.whereType<Map>().map((e) => Trip.fromJson(asMap(e))).toList();
  }

  /// The caller's own trips for [date] (driver/helper querysets are scoped server-side).
  Future<List<Trip>> forDate(DateTime date) async {
    final rows = await _api.getList(ApiEndpoints.trips, query: {
      'date': DateFormat('yyyy-MM-dd').format(date),
      'page_size': 50,
    });
    return rows.whereType<Map>().map((e) => Trip.fromJson(asMap(e))).toList();
  }

  Future<List<RouteInfo>> myRoutes() async {
    final rows = await _api.getList(ApiEndpoints.routes, query: {'page_size': 20});
    return rows.whereType<Map>().map((e) => RouteInfo.fromJson(asMap(e))).toList();
  }

  Future<Trip> start({required String routeId, required String tripType, double? latitude, double? longitude}) async {
    final data = await _api.post(ApiEndpoints.tripStart, data: {
      'route_public_id': routeId,
      'trip_type': tripType,
      'latitude': _coord(latitude),
      'longitude': _coord(longitude),
    });
    return Trip.fromJson(asMap(data));
  }

  Future<Trip> begin(String tripId) => _action(tripId, 'begin');

  Future<Trip> cancel(String tripId, String reason) => _action(tripId, 'cancel', {'reason': reason});

  Future<Trip> end(String tripId, {double? latitude, double? longitude}) =>
      _action(tripId, 'end', {'latitude': _coord(latitude), 'longitude': _coord(longitude)});

  Future<Trip> advanceStop(String tripId) => _action(tripId, 'advance-stop');

  Future<Trip> _action(String tripId, String action, [Map<String, dynamic>? body]) async =>
      Trip.fromJson(asMap(await _api.post(ApiEndpoints.tripAction(tripId, action), data: body)));

  /// Backend DecimalField(max_digits=9, decimal_places=6).
  static double? _coord(double? v) => v == null ? null : double.parse(v.toStringAsFixed(6));
}
