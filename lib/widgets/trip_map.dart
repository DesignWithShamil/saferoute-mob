import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../core/config/env.dart';
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
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
                      color: fallback ? AppColors.slate : const Color(0xFF3B82F6),
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
                const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
              ],
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Column(
                children: [
                  if (widget.bus != null) ...[
                    _MapButton(
                      icon: _follow ? Icons.my_location : Icons.location_searching,
                      tooltip: _follow ? 'Following bus' : 'Go to bus location',
                      onPressed: () {
                        setState(() => _follow = true);
                        _controller.move(widget.bus!, _controller.camera.zoom < 14 ? 15 : _controller.camera.zoom);
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                  _MapButton(
                    icon: Icons.fit_screen_outlined,
                    tooltip: 'Show whole route',
                    onPressed: () {
                      setState(() => _follow = false);
                      _fitAll();
                    },
                  ),
                  const SizedBox(height: 6),
                  _MapButton(icon: Icons.add, tooltip: 'Zoom in', onPressed: () => _zoom(1)),
                  const SizedBox(height: 6),
                  _MapButton(icon: Icons.remove, tooltip: 'Zoom out', onPressed: () => _zoom(-1)),
                ],
              ),
            ),
            if (fallback)
              const Positioned(
                left: 8,
                top: 8,
                child: _MapNote(text: 'Road route unavailable – dashed line joins stops in order'),
              ),
          ],
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
      MapPlaceKind.school => const Color(0xFF7C3AED),
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
    final Color fill = departed
        ? AppColors.green
        : stop.isCurrent
            ? AppColors.amber
            : const Color(0xFFDBEAFE);
    final Color border = stop.isHighlighted ? Colors.purple : (departed || stop.isCurrent ? Colors.white : AppColors.brand);
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: stop.isHighlighted ? 4 : 3),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26)],
      ),
      child: Text(
        stop.badge ?? '${stop.sequence}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          color: departed || stop.isCurrent ? Colors.white : AppColors.brand,
        ),
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
  const _MapButton({required this.icon, required this.tooltip, required this.onPressed});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        elevation: 2,
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon, size: 20),
          tooltip: tooltip,
          onPressed: onPressed,
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            fixedSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      );
}

class _MapNote extends StatelessWidget {
  const _MapNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: const TextStyle(fontSize: 11)),
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
  return [
    for (final ts in trip.tripStops)
      if (ts.stop?.hasPosition ?? false)
        MapStop(
          position: LatLng(ts.stop!.latitude!, ts.stop!.longitude!),
          sequence: ts.sequence,
          name: ts.stop!.name,
          status: ts.status,
          isCurrent: ts.stop!.publicId == currentId,
          radiusMeters: ts.stop!.radius,
          badge: studentCounts[ts.stop!.publicId]?.toString(),
          details: [
            ?scheduledTimeLine(morning: trip.isMorning, pickupTime: ts.stop!.pickupTime, dropTime: ts.stop!.dropTime),
            if (ts.stop!.address.isNotEmpty) ts.stop!.address,
            if (ts.arrivedAt != null) 'Arrived ${DateFormat.jm().format(ts.arrivedAt!)}',
            if (ts.departedAt != null) 'Departed ${DateFormat.jm().format(ts.departedAt!)}',
            if ((studentsByStop[ts.stop!.publicId] ?? const []).isNotEmpty)
              'Students: ${studentsByStop[ts.stop!.publicId]!.join(', ')}',
          ],
        ),
  ];
}
