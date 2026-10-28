import 'dart:math' as math;

/// Same formulas as the web app's utils/distance.js, so distances and ETAs
/// shown on mobile match the web dashboards.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadius = 6371000.0;
  double toRad(double v) => v * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String formatDistance(double meters) =>
    meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

/// Minutes to cover [meters]; assumes 30 km/h when the bus is stopped or slow.
int etaMinutes(double meters, double? speedKmh) {
  final speed = (speedKmh != null && speedKmh > 5) ? speedKmh : 30.0;
  return (meters / (speed * 1000 / 3600) / 60).round();
}

String formatAge(Duration? age) {
  if (age == null) return 'never';
  if (age.inSeconds < 60) return '${age.inSeconds.clamp(0, 59)}s ago';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  return 'a while ago';
}

/// Checks whether a coordinate is the Android Emulator default (Mountain View, CA ~37.422, -122.084)
/// or unreasonably far (> 300 km) from an anchor point (e.g. school or route stops).
bool isEmulatorOrFarCoord(double lat, double lon, {double? anchorLat, double? anchorLon}) {
  if ((lat - 37.422).abs() < 0.1 && (lon - (-122.084)).abs() < 0.1) {
    return true;
  }
  if (anchorLat != null && anchorLon != null) {
    final dist = haversineMeters(lat, lon, anchorLat, anchorLon);
    if (dist > 300000) {
      return true;
    }
  }
  return false;
}
