import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../core/config/env.dart';
import '../core/location/location_service.dart';
import '../core/utils/geo.dart';
import '../models/trip.dart';
import '../models/user.dart';
import '../services/route_geometry_service.dart';
import 'state_views.dart';

/// A trip stop, in the order the backend returned it.
class MapStop {
  const MapStop({
    required this.position,
    required this.sequence,
    required this.name,
    required this.status,
    this.isCurrent = false,
    this.isHighlighted = false,
    this.isSchoolAnchor = false,
    this.isRouteStart = false,
    this.isRouteEnd = false,
    this.radiusMeters,
    this.badge,
    this.details = const [],
  });

  final LatLng position;
  final int sequence;
  final String name;
  final String status;
  final bool isCurrent;

  /// e.g. the parent's child's own stop.
  final bool isHighlighted;

  /// Morning: last stop (school). Afternoon: first stop (school).
  final bool isSchoolAnchor;
  final bool isRouteStart;
  final bool isRouteEnd;
  final int? radiusMeters;

  /// Text inside the marker; defaults to the sequence number.
  final String? badge;

  /// Lines shown in the sheet when the marker is tapped.
  final List<String> details;
}

enum MapPlaceKind { school, pickup, drop }

/// A point that is not a stop of the displayed trip: the school, or a
/// child's pickup/drop stop from their assignment.
class MapPlace {
  const MapPlace({required this.position, required this.kind, required this.title, this.details = const []});

  final LatLng position;
  final MapPlaceKind kind;
  final String title;
  final List<String> details;
}

MapPlace? schoolPlace(School? school) => school == null || !school.hasPosition
    ? null
    : MapPlace(
        position: LatLng(school.latitude!, school.longitude!),
        kind: MapPlaceKind.school,
        title: school.name,
        details: [if (school.address.isNotEmpty) school.address],
      );

/// Trip map shared by the driver, helper and parent screens. Draws the road
/// route (OSRM, same as the web app) through the backend-ordered stops, the
/// completed vs remaining path split at the current stop, the current stop's
/// geofence, the school, and the bus. Every coordinate comes from the API.
class TripMap extends StatefulWidget {
  const TripMap({
    super.key,
    this.stops = const [],
    this.places = const [],
    this.geometry,
    this.bus,
    this.busIsStale = false,
    this.busLabel = 'Bus',
    this.busDetails = const [],
    this.heightFraction = 0.3,
    this.followBusByDefault = true,
  });

  final List<MapStop> stops;
  final List<MapPlace> places;
  final RouteGeometry? geometry;
  final LatLng? bus;
  final bool busIsStale;
  final String busLabel;
  final List<String> busDetails;

  /// Share of the screen height; kept moderate so the surrounding list can
  /// still be scrolled on small phones (drags on the map pan the map).
  final double heightFraction;
  final bool followBusByDefault;

  @override
  State<TripMap> createState() => _TripMapState();
}

class _TripMapState extends State<TripMap> {
  final _controller = MapController();
  late bool _follow = widget.followBusByDefault;
  bool _ready = false;
  LatLng? _me;
  bool _locating = false;

  @override
  void didUpdateWidget(covariant TripMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bus = widget.bus;
    if (_ready && _follow && bus != null && bus != oldWidget.bus) {
      final zoom = _controller.camera.zoom;
      _controller.move(bus, oldWidget.bus == null && zoom < 15 ? 15 : zoom);
    }
  }

  List<LatLng> get _allPoints => [
        ...widget.stops.map((s) => s.position),
        ...widget.places.map((p) => p.position),
        ?widget.bus,
      ];

  void _fitAll() {
    final points = _allPoints;
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.first, 15);
      return;
    }
    _controller.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: _fitPadding));
  }

  /// Extra room on the right and bottom keeps markers clear of the map
  /// buttons and the attribution strip.
  static const _fitPadding = EdgeInsets.fromLTRB(40, 48, 80, 72);

  /// View-only: shows where this phone is right now and centres the map on it.
  Future<void> _locateMe() async {
    if (_locating) return;
    HapticFeedback.selectionClick();
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) showSnack(context, 'Turn on your phone\'s location (GPS) to see your live position.', error: true);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) showSnack(context, 'Location permission is needed to show your live position.', error: true);
        return;
      }
      final fix = await LocationService().currentPosition();
      if (!mounted) return;
      if (fix == null) {
        showSnack(context, 'Could not get your location yet. Try again in a moment.', error: true);
        return;
      }
      final me = LatLng(fix.latitude, fix.longitude);
      setState(() {
        _me = me;
        _follow = false;
      });
      _controller.move(me, _controller.camera.zoom < 15 ? 16 : _controller.camera.zoom);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _zoom(double delta) {
    final camera = _controller.camera;
    _controller.move(camera.center, (camera.zoom + delta).clamp(3.0, 19.0));
  }

  void _showDetails(IconData icon, Color color, String title, List<String> lines) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: Theme.of(ctx).textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 8),
              for (final line in lines)
                Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(line)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * widget.heightFraction).clamp(180.0, 420.0);
    final points = _allPoints;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const EmptyView(icon: Icons.map_outlined, title: 'No map data yet'),
      );
    }

    final geometry = widget.geometry;
    final fallback = geometry?.isFallback ?? false;
    final path = geometry?.points ?? const <LatLng>[];
    final (done, remaining) = fallback ? (const <LatLng>[], path) : _splitPath(path);
    final current = widget.stops.where((s) => s.isCurrent).firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(22.5),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCameraFit: points.length > 1 && !(_follow && widget.bus != null)
                    ? CameraFit.bounds(bounds: LatLngBounds.fromPoints(points), padding: _fitPadding)
                    : null,
                initialCenter: (_follow ? widget.bus : null) ?? points.first,
                initialZoom: 15,
                onMapReady: () => _ready = true,
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _follow) setState(() => _follow = false);
                },
              ),
              children: [
                TileLayer(urlTemplate: Env.mapTileUrl, userAgentPackageName: 'com.saferoute.app'),
                PolylineLayer(polylines: [
                  if (done.length > 1) Polyline(points: done, color: AppColors.green, strokeWidth: 5),
                  if (remaining.length > 1)
                    Polyline(
                      points: remaining,
                      color: fallback ? AppColors.slate : AppColors.brand,
                      strokeWidth: fallback ? 3 : 4,
                      pattern: fallback
                          ? StrokePattern.dashed(segments: const [10, 8])
                          : const StrokePattern.dotted(),
                    ),
                ]),
                if (current != null)
                  CircleLayer(circles: [
                    CircleMarker(
                      point: current.position,
                      radius: (current.radiusMeters ?? 100).toDouble(),
                      useRadiusInMeter: true,
                      color: AppColors.amber.withValues(alpha: 0.18),
                      borderColor: AppColors.amber,
                      borderStrokeWidth: 2,
                    ),
                  ]),
                MarkerLayer(markers: [
                  for (final p in widget.places)
                    Marker(
                      point: p.position,
                      width: 38,
                      height: 38,
                      child: GestureDetector(
                        onTap: () => _showDetails(_placeIcon(p.kind), _placeColor(p.kind), p.title, [
                          _placeLabel(p.kind),
                          ...p.details,
                        ]),
                        child: _PlaceMarker(kind: p.kind),
                      ),
                    ),
                  for (final s in widget.stops)
                    Marker(
                      point: s.position,
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => _showDetails(
                          Icons.place,
                          s.isCurrent ? AppColors.amber : AppColors.brand,
                          '${s.sequence}. ${s.name}',
                          ['Status: ${TripStopStatus.label(s.status)}${s.isCurrent ? ' (current / next stop)' : ''}', ...s.details],
                        ),
                        child: _StopMarker(stop: s),
                      ),
                    ),
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: 48,
                      height: 48,
                      child: const _MeMarker(),
                    ),
                  if (widget.bus != null)
                    Marker(
                      point: widget.bus!,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showDetails(Icons.directions_bus, AppColors.brand, widget.busLabel, [
                          if (widget.busIsStale) 'Location may be outdated.',
                          ...widget.busDetails,
                        ]),
                        child: _BusMarker(stale: widget.busIsStale),
                      ),
                    ),
                ]),
                const SimpleAttributionWidget(
                  source: Text('OpenStreetMap contributors', style: TextStyle(fontSize: 11)),
                  backgroundColor: Color(0xCCFFFFFF),
                ),
              ],
            ),
            Positioned(
              right: 10,
              top: 10,
              child: Column(
                children: [
                  _MapButton(
                    icon: Icons.my_location_rounded,
                    tooltip: 'Show my live location',
                    busy: _locating,
                    highlighted: _me != null,
                    onPressed: _locateMe,
                  ),
                  if (widget.bus != null) ...[
                    const SizedBox(height: 8),
                    _MapButton(
                      icon: Icons.directions_bus_rounded,
                      tooltip: _follow ? 'Following bus' : 'Go to bus location',
                      highlighted: _follow,
                      onPressed: () {
                        setState(() => _follow = true);
                        _controller.move(widget.bus!, _controller.camera.zoom < 14 ? 15 : _controller.camera.zoom);
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  _MapButton(
                    icon: Icons.fit_screen_rounded,
                    tooltip: 'Show whole route',
                    onPressed: () {
                      setState(() => _follow = false);
                      _fitAll();
                    },
                  ),
                  if (height >= 300) ...[
                    const SizedBox(height: 8),
                    _MapButton(icon: Icons.add_rounded, tooltip: 'Zoom in', onPressed: () => _zoom(1)),
                    const SizedBox(height: 8),
                    _MapButton(icon: Icons.remove_rounded, tooltip: 'Zoom out', onPressed: () => _zoom(-1)),
                  ],
                ],
              ),
            ),
            if (fallback)
              const Positioned(
                left: 10,
                top: 10,
                right: 64,
                child: _MapNote(text: 'Road route unavailable – dashed line joins stops in order'),
              ),
          ],
        ),
      ),
      ),
    );
  }

  /// Same approach as the web dashboards: split the route polyline at the
  /// point closest to the current stop.
  (List<LatLng>, List<LatLng>) _splitPath(List<LatLng> path) {
    if (path.isEmpty) return (const [], const []);
    final current = widget.stops.where((s) => s.isCurrent).firstOrNull;
    final allDone = widget.stops.isNotEmpty && widget.stops.every((s) => s.status == TripStopStatus.departed);
    if (allDone) return (path, const []);
    if (current == null) return (const [], path);
    var best = 0;
    var bestDistance = double.infinity;
    for (var i = 0; i < path.length; i++) {
      final d = haversineMeters(path[i].latitude, path[i].longitude, current.position.latitude, current.position.longitude);
      if (d < bestDistance) {
        bestDistance = d;
        best = i;
      }
    }
    return (path.sublist(0, best + 1), path.sublist(best));
  }
}

IconData _placeIcon(MapPlaceKind kind) => switch (kind) {
      MapPlaceKind.school => Icons.school,
      MapPlaceKind.pickup => Icons.wb_sunny,
      MapPlaceKind.drop => Icons.home,
    };

Color _placeColor(MapPlaceKind kind) => switch (kind) {
      MapPlaceKind.school => AppColors.teal,
      MapPlaceKind.pickup => AppColors.amber,
      MapPlaceKind.drop => AppColors.green,
    };

String _placeLabel(MapPlaceKind kind) => switch (kind) {
      MapPlaceKind.school => 'School',
      MapPlaceKind.pickup => 'Pickup point',
      MapPlaceKind.drop => 'Drop point',
    };

class _PlaceMarker extends StatelessWidget {
  const _PlaceMarker({required this.kind});
  final MapPlaceKind kind;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _placeColor(kind),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
        ),
        child: Icon(_placeIcon(kind), color: Colors.white, size: 20),
      );
}

class _StopMarker extends StatelessWidget {
  const _StopMarker({required this.stop});
  final MapStop stop;

  @override
  Widget build(BuildContext context) {
    final departed = stop.status == TripStopStatus.departed;
    final school = stop.isSchoolAnchor;
    final Color fill = school
        ? AppColors.teal
        : departed
            ? AppColors.green
            : stop.isCurrent
                ? AppColors.amber
                : stop.isRouteStart
                    ? AppColors.green
                    : stop.isRouteEnd
                        ? AppColors.brand
                        : AppColors.brandTint;
    final Color border = stop.isHighlighted
        ? Colors.purple
        : (departed || stop.isCurrent || school ? Colors.white : AppColors.brand);
    final textColor = departed || stop.isCurrent || school || stop.isRouteStart || stop.isRouteEnd
        ? Colors.white
        : AppColors.brand;
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: stop.isHighlighted ? 4 : 3),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
      ),
      child: school
          ? Icon(Icons.school, size: 16, color: textColor)
          : Text(
              stop.badge ?? (stop.isRouteStart ? 'S' : stop.isRouteEnd ? 'E' : '${stop.sequence}'),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: stop.badge != null && stop.badge!.length > 2 ? 10 : 12, color: textColor),
            ),
    );
  }
}

class _BusMarker extends StatelessWidget {
  const _BusMarker({required this.stale});
  final bool stale;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: stale ? AppColors.slate : AppColors.brand,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
        ),
        child: const Icon(Icons.directions_bus, color: Colors.white, size: 22),
      );
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
    this.highlighted = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool busy;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: highlighted ? AppColors.brand : Colors.white,
          elevation: 3,
          shadowColor: Colors.black38,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: busy ? null : onPressed,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : Icon(icon, size: 21, color: highlighted ? Colors.white : AppColors.ink),
              ),
            ),
          ),
        ),
      );
}

/// Blue "you are here" dot with a soft halo.
class _MeMarker extends StatelessWidget {
  const _MeMarker();

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.18), shape: BoxShape.circle)),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF1E88FF),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
            ),
          ),
        ],
      );
}

class _MapNote extends StatelessWidget {
  const _MapNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(fontSize: 12)),
      );
}

String _hhmm(String? backendTime) {
  if (backendTime == null || backendTime.isEmpty) return '';
  final parts = backendTime.split(':');
  if (parts.length < 2) return backendTime;
  return DateFormat.jm().format(DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0));
}

/// Scheduled time line for a stop: pickup time on morning runs, drop time on evening runs.
String? scheduledTimeLine({required bool morning, String? pickupTime, String? dropTime}) {
  final t = _hhmm(morning ? pickupTime : dropTime);
  return t.isEmpty ? null : '${morning ? 'Pickup' : 'Drop'} time: $t';
}

/// Map stops for a driver/helper trip, straight from backend TripStops.
/// [studentsByStop] feeds both the marker badge and the tap details.
List<MapStop> mapStopsForTrip(
  Trip trip, {
  Map<String, int> studentCounts = const {},
  Map<String, List<String>> studentsByStop = const {},
}) {
  final currentId = trip.currentStop?.publicId;
  final sequences = trip.tripStops.map((e) => e.sequence);
  final maxSeq = sequences.isEmpty ? 0 : sequences.reduce((a, b) => a > b ? a : b);
  final out = <MapStop>[];
  for (final ts in trip.tripStops) {
    if (!(ts.stop?.hasPosition ?? false)) continue;
    final isFirst = ts.sequence == 1;
    final isLast = ts.sequence == maxSeq;
    final schoolAnchor = (trip.isMorning && isLast) || (trip.isAfternoon && isFirst);
    final routeStart = trip.isMorning ? isFirst : schoolAnchor;
    final routeEnd = trip.isMorning ? schoolAnchor : isLast;
    final stopId = ts.stop!.publicId;
    final count = studentCounts[stopId];
    out.add(
      MapStop(
        position: LatLng(ts.stop!.latitude!, ts.stop!.longitude!),
        sequence: ts.sequence,
        name: ts.stop!.name,
        status: ts.status,
        isCurrent: stopId == currentId,
        isSchoolAnchor: schoolAnchor,
        isRouteStart: routeStart && !schoolAnchor,
        isRouteEnd: routeEnd && !schoolAnchor,
        radiusMeters: ts.stop!.radius,
        badge: schoolAnchor ? null : (count != null && count > 0 ? '$count' : null),
        details: [
          if (schoolAnchor) 'School (${trip.isMorning ? 'morning drop-off' : 'evening pickup'})',
          if (routeStart && !schoolAnchor) 'Route start',
          if (routeEnd && !schoolAnchor) 'Route end',
          ?scheduledTimeLine(morning: trip.isMorning, pickupTime: ts.stop!.pickupTime, dropTime: ts.stop!.dropTime),
          if (count != null && count > 0) '$count student${count == 1 ? '' : 's'} at this stop',
          if (ts.stop!.address.isNotEmpty) ts.stop!.address,
          if (ts.arrivedAt != null) 'Arrived ${DateFormat.jm().format(ts.arrivedAt!)}',
          if (ts.departedAt != null) 'Departed ${DateFormat.jm().format(ts.departedAt!)}',
          if ((studentsByStop[stopId] ?? const []).isNotEmpty) 'Students: ${studentsByStop[stopId]!.join(', ')}',
        ],
      ),
    );
  }
  return out;
}
