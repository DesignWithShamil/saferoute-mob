import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/utils/geo.dart';
import '../../models/parent_live.dart';
import '../../models/trip.dart';
import '../../providers/parent_controller.dart';
import '../../services/route_geometry_service.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_map.dart';
import 'child_detail_screen.dart';
import 'parent_widgets.dart';

/// Live bus map for one of the parent's children. Data comes only from
/// `/gps/parent-live/`, which the backend limits to the parent's own children
/// on active trips; ids from a notification are just lookup keys into it.
class LiveTripScreen extends StatefulWidget {
  const LiveTripScreen({super.key, required this.tripId, this.studentId});
  final String tripId;
  final String? studentId;

  @override
  State<LiveTripScreen> createState() => _LiveTripScreenState();
}

class _LiveTripScreenState extends State<LiveTripScreen> {
  late final ParentController _c = context.read<ParentController>();
  RouteGeometry? _geometry;
  bool _geometryRequested = false;

  @override
  void initState() {
    super.initState();
    _c.startPolling();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_c.children.isEmpty) await _c.load();
      final studentId = widget.studentId;
      if (studentId != null && studentId != _c.selectedChild?.student.publicId) {
        // Live data is fetched for the selected child, so a notification about
        // another child switches to that child first.
        await _c.selectChild(studentId);
      } else {
        await _c.refreshLive();
      }
    });
  }

  @override
  void dispose() {
    _c.stopPolling();
    super.dispose();
  }

  void _ensureGeometry(ParentLiveTrip live) {
    if (_geometryRequested) return;
    final points = live.stops
        .where((s) => s.latitude != null && s.longitude != null)
        .map((s) => LatLng(s.latitude!, s.longitude!))
        .toList();
    if (points.length < 2) return;
    _geometryRequested = true;
    context.read<AppServices>().geometry.forStops(points).then((g) {
      if (mounted) setState(() => _geometry = g);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentController>();
    final live = c.liveFor(widget.tripId, studentId: widget.studentId);

    Widget body;
    if (live == null) {
      if (c.loading || c.liveUpdatedAt == null) {
        body = const LoadingView(label: 'Loading live trip…');
      } else if (c.error != null) {
        body = ErrorView(message: c.error!, onRetry: c.load);
      } else {
        body = _TripNotLive(studentId: widget.studentId);
      }
    } else {
      _ensureGeometry(live);
      body = _LiveBody(live: live, geometry: _geometry, liveError: c.liveError, updatedAt: c.liveUpdatedAt);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(live == null
            ? 'Live trip'
            : '${live.childName}${live.schoolName.isEmpty ? '' : ' - ${live.schoolName}'} · Bus ${live.busNumber}'),
      ),
      body: body,
    );
  }
}

class _TripNotLive extends StatelessWidget {
  const _TripNotLive({this.studentId});
  final String? studentId;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyView(
              icon: Icons.directions_bus_outlined,
              title: 'This trip is not active',
              message: 'It may have ended, or it isn\'t linked to your children.',
            ),
            if (studentId != null)
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => ChildDetailScreen(studentId: studentId!)),
                ),
                child: const Text('View child details'),
              ),
          ],
        ),
      );
}

class _LiveBody extends StatelessWidget {
  const _LiveBody({required this.live, required this.geometry, required this.liveError, required this.updatedAt});
  final ParentLiveTrip live;
  final RouteGeometry? geometry;
  final String? liveError;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final next = live.nextStop;
    final childStopId = live.childStopId;
    final loc = live.location;
    final link = context.read<ParentController>().childById(live.childId);
    final student = link?.student;
    final stops = [
      for (final s in live.stops)
        if (s.latitude != null && s.longitude != null)
          MapStop(
            position: LatLng(s.latitude!, s.longitude!),
            sequence: s.sequence,
            name: s.name,
            status: s.status,
            isCurrent: identical(s, next),
            isHighlighted: s.publicId != null && s.publicId == childStopId,
            radiusMeters: s.radius,
            details: [
              if (s.publicId == childStopId) '${live.childName}\'s stop on this trip',
              ?scheduledTimeLine(morning: true, pickupTime: s.pickupTime),
              ?scheduledTimeLine(morning: false, dropTime: s.dropTime),
              if (s.arrivedAt != null) 'Arrived ${DateFormat.jm().format(s.arrivedAt!)}',
              if (s.departedAt != null) 'Departed ${DateFormat.jm().format(s.departedAt!)}',
              ?approachText(live, s),
            ],
          ),
    ];
    final places = [
      ?schoolPlace(link?.school),
      if (student != null)
        ...childStopPlaces(student, skipStopIds: {for (final s in live.stops) ?s.publicId}),
    ];

    return RefreshIndicator(
      onRefresh: context.read<ParentController>().refreshLive,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TripMap(
            stops: stops,
            places: places,
            geometry: geometry,
            bus: loc == null ? null : LatLng(loc.latitude, loc.longitude),
            busIsStale: loc?.isStale ?? true,
            busLabel: 'Bus ${live.busNumber}',
            busDetails: [
              if (live.routeName.isNotEmpty) 'Route ${live.routeName}',
              'Trip: ${TripStatus.label(live.tripStatus)}',
              if (loc != null) 'Updated ${formatAge(loc.age)}',
              if (loc?.speedKmh != null) '${loc!.speedKmh!.round()} km/h',
            ],
            heightFraction: 0.45,
          ),
          const SizedBox(height: 8),
          Text(
            loc == null
                ? 'Waiting for the bus to share its location.'
                : loc.isStale
                    ? 'Bus location may be outdated (last update ${formatAge(loc.age)}).'
                    : 'Bus location updated ${formatAge(loc.age)}'
                        '${loc.speedKmh != null ? ' · ${loc.speedKmh!.round()} km/h' : ''}',
            style: TextStyle(color: loc == null || loc.isStale ? AppColors.amber : AppColors.slate),
          ),
          if (liveError != null)
            Text('Couldn\'t refresh: $liveError', style: const TextStyle(color: AppColors.red)),
          const SizedBox(height: 12),
          LiveTripSummaryCard(live: live),
          if (next != null)
            SectionCard(
              title: 'Next stop',
              trailing: Text(approachText(live, next) ?? ''),
              child: Text(next.name, style: Theme.of(context).textTheme.titleMedium),
            ),
          SectionCard(
            title: 'Stops',
            child: Column(
              children: [
                for (final s in live.stops)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: identical(s, next)
                          ? AppColors.amber
                          : s.status == TripStopStatus.departed
                              ? AppColors.green
                              : AppColors.slate.withValues(alpha: 0.25),
                      child: Text('${s.sequence}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                    ),
                    title: Text(
                      s.name,
                      style: TextStyle(fontWeight: s.publicId == childStopId ? FontWeight.w800 : FontWeight.normal),
                    ),
                    subtitle: Text([
                      if (s.publicId == childStopId) 'Your child\'s stop',
                      if (s.arrivedAt != null) 'Arrived ${DateFormat.jm().format(s.arrivedAt!)}',
                      if (s.departedAt != null) 'Departed ${DateFormat.jm().format(s.departedAt!)}',
                    ].join(' · ')),
                    trailing: StatusChip(label: s.status, color: AppColors.forStatus(s.status)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
