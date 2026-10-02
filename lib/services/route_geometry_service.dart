import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../core/config/env.dart';

class RouteGeometry {
  const RouteGeometry(this.points, {required this.isFallback});

  final List<LatLng> points;

  /// True when OSRM was unreachable and the stops are joined by straight lines.
  final bool isFallback;
}

/// Road-following polyline through a trip's stops, using the same public
/// OSRM service and straight-line fallback as the web app
/// (frontend/src/services/mapProviderService.js). Results are cached per
/// stop sequence because stops don't move during a trip.
class RouteGeometryService {
  RouteGeometryService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: Env.osrmBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
            ));

  final Dio _dio;
  final Map<String, RouteGeometry> _cache = {};

  Future<RouteGeometry?> forStops(List<LatLng> stops) async {
    if (stops.length < 2) return null;
    final coordinates = stops.map((p) => '${p.longitude},${p.latitude}').join(';');
    final cached = _cache[coordinates];
    if (cached != null) return cached;

    try {
      final res = await _dio.get(
        '/route/v1/driving/$coordinates',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final routes = (res.data as Map)['routes'] as List?;
      if (routes == null || routes.isEmpty) return RouteGeometry(stops, isFallback: true);
      final coords = ((routes.first as Map)['geometry'] as Map)['coordinates'] as List;
      final geometry = RouteGeometry(
        coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList(),
        isFallback: false,
      );
      _cache[coordinates] = geometry;
      return geometry;
    } catch (_) {
      return RouteGeometry(stops, isFallback: true);
    }
  }
}
