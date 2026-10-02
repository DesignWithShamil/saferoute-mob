import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/utils/geo.dart';
import '../../models/parent_live.dart';
import '../../models/student.dart';
import '../../models/trip.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_map.dart';
import 'add_child_screen.dart';

String childStatusLabel(String status) => status.isEmpty ? 'Not marked' : AttendanceStatus.label(status);

/// The child's assigned pickup / drop stops (StudentSerializer's
/// RouteStopMiniSerializer coordinates). Stops already drawn as part of the
/// trip are skipped via [skipStopIds]; a shared stop becomes one marker.
List<MapPlace> childStopPlaces(Student student, {Set<String> skipStopIds = const {}}) {
  final pickup = student.pickupStop;
  final drop = student.dropStop;
  final places = <MapPlace>[];
  if (pickup != null && pickup.hasPosition && !skipStopIds.contains(pickup.publicId)) {
    final shared = drop != null && drop.publicId == pickup.publicId;
    places.add(MapPlace(
      position: LatLng(pickup.latitude!, pickup.longitude!),
      kind: MapPlaceKind.pickup,
      title: pickup.name,
      details: [
        shared ? '${student.fullName}\'s pickup and drop point' : '${student.fullName}\'s pickup point',
        ?scheduledTimeLine(morning: true, pickupTime: pickup.pickupTime),
        if (shared) ?scheduledTimeLine(morning: false, dropTime: pickup.dropTime),
        if (student.pickupBus != null) 'Bus ${student.pickupBus!.busNumber}',
      ],
    ));
  }
  if (drop != null && drop.hasPosition && drop.publicId != pickup?.publicId && !skipStopIds.contains(drop.publicId)) {
    places.add(MapPlace(
      position: LatLng(drop.latitude!, drop.longitude!),
      kind: MapPlaceKind.drop,
      title: drop.name,
      details: [
        '${student.fullName}\'s drop point',
        ?scheduledTimeLine(morning: false, dropTime: drop.dropTime),
        if (student.dropBus != null) 'Bus ${student.dropBus!.busNumber}',
      ],
    ));
  }
  return places;
}

/// Distance/ETA of the bus to [stop], or null when either position is unknown.
String? approachText(ParentLiveTrip live, LiveStop? stop) {
  final loc = live.location;
  if (loc == null || stop == null || stop.latitude == null || stop.longitude == null) return null;
  if (stop.status == TripStopStatus.departed) return null;
  final meters = haversineMeters(loc.latitude, loc.longitude, stop.latitude!, stop.longitude!);
  final eta = etaMinutes(meters, loc.speedKmh);
  return '${formatDistance(meters)} · ~${eta <= 1 ? '1 min' : '$eta min'}';
}

class LiveTripSummaryCard extends StatelessWidget {
  const LiveTripSummaryCard({super.key, required this.live, this.onTap});
  final ParentLiveTrip live;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final next = live.nextStop;
    final approach = approachText(live, live.childStop);
    final loc = live.location;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      live.schoolName.isEmpty ? live.childName : '${live.childName} - ${live.schoolName}',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  StatusChip(label: childStatusLabel(live.childStatus), color: AppColors.forStatus(live.childStatus)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  'Bus ${live.busNumber}',
                  if (live.routeName.isNotEmpty) live.routeName,
                  if (live.tripType.isNotEmpty) '${TripType.label(live.tripType)} trip',
                ].join(' · '),
                style: theme.textTheme.bodyMedium,
              ),
              const Divider(height: 20),
              _Line(icon: Icons.directions_bus, label: 'Trip', value: TripStatus.label(live.tripStatus)),
              _Line(icon: Icons.place_outlined, label: 'Next stop', value: next?.name ?? 'All stops completed'),
              if (live.childStop != null)
                _Line(
                  icon: Icons.home_outlined,
                  label: 'Your stop',
                  value: '${live.childStop!.name}${approach != null ? ' ($approach)' : ''}',
                ),
              _Line(
                icon: loc == null ? Icons.gps_off : Icons.gps_fixed,
                label: 'Location',
                value: loc == null ? 'Waiting for the bus GPS' : 'Updated ${formatAge(loc.age)}',
                color: loc == null || loc.isStale ? AppColors.amber : null,
              ),
              if (onTap != null)
                const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(padding: EdgeInsets.only(top: 4), child: Text('View live map ›')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Selected child: Rahul - ABC School  [Change child]". Every parent screen
/// shows the selected child; changing it reloads that child's data only.
class SelectedChildHeader extends StatelessWidget {
  const SelectedChildHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentController>();
    final child = c.selectedChild;
    if (child == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final bus = child.student.pickupBus?.busNumber ?? child.student.dropBus?.busNumber;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.brand.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.children.length > 1) ...[
              Text('Select child', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.slate)),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: c.children.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final link = c.children[i];
                    final selected = link.student.publicId == child.student.publicId;
                    return ChoiceChip(
                      label: Text(
                        link.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: selected,
                      onSelected: (_) => c.selectChild(link.student.publicId),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                CircleAvatar(child: Text(child.student.fullName.characters.firstOrNull ?? '?')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Viewing', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.slate)),
                      Text(child.label, style: theme.textTheme.titleMedium, key: const Key('selected-child-label')),
                      Text(
                        [
                          if (child.student.classLabel.isNotEmpty) 'Class ${child.student.classLabel}',
                          bus == null ? 'No bus assigned' : 'Bus $bus',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => showChildPicker(context),
                  child: Text(c.children.length > 1 ? 'More' : 'Add child'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showChildPicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final c = sheetContext.watch<ParentController>();
        final selectedId = c.selectedChild?.student.publicId;
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Choose a child', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              for (final child in c.children)
                ListTile(
                  leading: CircleAvatar(child: Text(child.student.fullName.characters.firstOrNull ?? '?')),
                  title: Text(child.label),
                  subtitle: Text([
                    if (child.student.classLabel.isNotEmpty) 'Class ${child.student.classLabel}',
                    if (child.student.pickupBus != null) 'Bus ${child.student.pickupBus!.busNumber}',
                  ].join(' · ')),
                  trailing: child.student.publicId == selectedId ? const Icon(Icons.check_circle, color: AppColors.green) : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    c.selectChild(child.student.publicId);
                  },
                ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.add)),
                title: const Text('Add a child'),
                subtitle: const Text('From any school, with the school\'s link code'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddChildScreen()));
                },
              ),
            ],
          ),
        );
      },
    );

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value, this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.slate),
            const SizedBox(width: 8),
            SizedBox(width: 84, child: Text(label, style: const TextStyle(color: AppColors.slate))),
            Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color))),
          ],
        ),
      );
}
