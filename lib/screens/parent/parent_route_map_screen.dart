import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../models/student.dart';
import '../../models/trip.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_map.dart';
import 'parent_widgets.dart';

/// React `/parent/route`: the selected child's morning or evening route.
class ParentRouteMapScreen extends StatefulWidget {
  const ParentRouteMapScreen({super.key});

  @override
  State<ParentRouteMapScreen> createState() => _ParentRouteMapScreenState();
}

class _ParentRouteMapScreenState extends State<ParentRouteMapScreen> {
  late final ParentController _c = context.read<ParentController>();
  bool _morning = true;
  ParentLink? _detail;
  String? _error;
  bool _loading = true;
  String? _loadedFor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final id = _c.selectedChild?.student.publicId;
    if (id == null) {
      setState(() {
        _loading = false;
        _detail = null;
        _error = null;
        _loadedFor = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await _c.childWithStops(id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loadedFor = id;
        _loading = false;
        if (_morning && detail.pickupRoute == null && detail.dropRoute != null) _morning = false;
        if (!_morning && detail.dropRoute == null && detail.pickupRoute != null) _morning = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = describeError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ParentController>();
    final currentId = _c.selectedChild?.student.publicId;
    if (currentId != _loadedFor && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    if (_c.selectedChild == null) {
      return const EmptyView(icon: Icons.map_outlined, title: 'Add a child to see their route');
    }
    if (_loading) return const LoadingView(label: 'Loading route…');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final link = _detail ?? _c.selectedChild!;
    final route = _morning ? link.pickupRoute : link.dropRoute;
    final student = link.student;
    final highlightId = _morning ? student.pickupStop?.publicId : student.dropStop?.publicId;
    final stops = [
      for (final s in route?.stops ?? const [])
        if (s.hasPosition)
          MapStop(
            position: LatLng(s.latitude!, s.longitude!),
            sequence: s.sequence,
            name: s.name,
            status: TripStopStatus.pending,
            isHighlighted: s.publicId == highlightId,
            details: [
              if (s.publicId == highlightId) 'Your stop',
              ?scheduledTimeLine(morning: _morning, pickupTime: s.pickupTime, dropTime: s.dropTime),
            ],
          ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SelectedChildHeader(),
          Row(
            children: [
              if (link.pickupRoute != null)
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Morning trip'),
                    selected: _morning,
                    onSelected: (_) => setState(() => _morning = true),
                  ),
                ),
              if (link.pickupRoute != null && link.dropRoute != null) const SizedBox(width: 8),
              if (link.dropRoute != null)
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Evening trip'),
                    selected: !_morning,
                    onSelected: (_) => setState(() => _morning = false),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (route == null || stops.isEmpty)
            const EmptyView(icon: Icons.alt_route, title: 'No route assigned to this student')
          else ...[
            Text(
              [
                route.name,
                if (student.pickupBus != null && _morning) 'Bus ${student.pickupBus!.busNumber}',
                if (student.dropBus != null && !_morning) 'Bus ${student.dropBus!.busNumber}',
              ].join(' · '),
            ),
            const SizedBox(height: 8),
            TripMap(
              stops: stops,
              places: [?schoolPlace(link.school), ...childStopPlaces(student, skipStopIds: {for (final s in route.stops) s.publicId})],
              followBusByDefault: false,
              heightFraction: 0.35,
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Stops',
              child: Column(
                children: [
                  for (final s in route.stops)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${s.sequence}. ${s.name}',
                        style: TextStyle(fontWeight: s.publicId == highlightId ? FontWeight.w800 : FontWeight.normal),
                      ),
                      subtitle: Text(_morning ? (s.pickupTime ?? '') : (s.dropTime ?? '')),
                      trailing: s.publicId == highlightId
                          ? const StatusChip(label: 'Your stop', color: AppColors.green)
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
