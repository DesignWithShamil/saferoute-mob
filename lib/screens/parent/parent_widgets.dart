import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

Color studentAvatarColor(String name) {
  const palette = [
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF7C3AED), // Purple
    Color(0xFF059669), // Emerald
    Color(0xFFD97706), // Amber
    Color(0xFFDC2626), // Rose
    Color(0xFF0891B2), // Cyan
    Color(0xFF4F46E5), // Indigo
  ];
  final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
  return palette[hash % palette.length];
}

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
      avatarUrl: student.photo,
      studentName: student.fullName,
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
      avatarUrl: student.photo,
      studentName: student.fullName,
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
    final next = live.nextStop;
    final approach = approachText(live, live.childStop);
    final loc = live.location;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.directions_bus_rounded, size: 22, color: AppColors.brand),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          live.schoolName.isEmpty ? live.childName : '${live.childName} - ${live.schoolName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            'Bus ${live.busNumber}',
                            if (live.routeName.isNotEmpty) live.routeName,
                            if (live.tripType.isNotEmpty) '${TripType.label(live.tripType)} trip',
                          ].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: StatusChip(label: childStatusLabel(live.childStatus), color: AppColors.forStatus(live.childStatus)),
                  ),
                ],
              ),
              const Divider(height: 26, color: AppColors.border),
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
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View live map', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.brand)),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right, size: 20, color: AppColors.brand),
                      ],
                    ),
                  ),
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
      margin: const EdgeInsets.only(bottom: 14),
      color: AppColors.brandTint,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.children.length > 1) ...[
              Text('Select child', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.slate)),
              const SizedBox(height: 8),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: c.children.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final link = c.children[i];
                    final selected = link.student.publicId == child.student.publicId;
                    return ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      label: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          link.student.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => showStudentPhotoDialog(context, child.student),
                  child: Tooltip(
                    message: 'Tap to update student profile photo',
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: studentAvatarColor(child.student.fullName),
                          foregroundColor: Colors.white,
                          backgroundImage: (child.student.photo != null && child.student.photo!.isNotEmpty)
                              ? NetworkImage(child.student.photo!)
                              : null,
                          child: (child.student.photo == null || child.student.photo!.isEmpty)
                              ? Text(
                                  child.student.fullName.characters.firstOrNull?.toUpperCase() ?? '?',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                                )
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: const BoxDecoration(color: AppColors.brand, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Viewing', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.slate)),
                      Text(
                        child.student.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(height: 1.2, fontSize: 18),
                        key: const Key('selected-child-label'),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (child.student.classLabel.isNotEmpty) child.student.displayClass,
                          bus == null ? 'No bus assigned' : 'Bus $bus',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      if (child.school.name.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (child.school.logo != null && child.school.logo!.isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    child.school.logo!,
                                    width: 13,
                                    height: 13,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  child.school.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.slate,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.brand,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
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
                  title: Text(child.student.fullName),
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
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color ?? AppColors.slate),
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
            ),
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? AppColors.ink),
              ),
            ),
          ],
        ),
      );
}

Future<void> showStudentPhotoDialog(BuildContext context, Student student) async {
  final initial = student.fullName.isNotEmpty ? student.fullName.characters.first.toUpperCase() : '?';

  Color avatarColor(String name) {
    const palette = [
      Color(0xFF2563EB), // Royal Blue
      Color(0xFF7C3AED), // Purple
      Color(0xFF059669), // Emerald
      Color(0xFFD97706), // Amber
      Color(0xFFDC2626), // Rose
      Color(0xFF0891B2), // Cyan
      Color(0xFF4F46E5), // Indigo
    ];
    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    return palette[hash % palette.length];
  }

  String? currentPhoto = student.photo;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      bool isSaving = false;
      String? savingMessage;
      final picker = ImagePicker();

      return StatefulBuilder(
        builder: (context, setState) {
          final hasPhoto = currentPhoto != null && currentPhoto!.trim().isNotEmpty;
          final color = avatarColor(student.fullName);

          Future<void> pickAndUpload(ImageSource source) async {
            final controller = dialogContext.read<ParentController>();
            final messenger = ScaffoldMessenger.of(context);
            try {
              final picked = await picker.pickImage(
                source: source,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 85,
              );
              if (picked == null) return;

              if (context.mounted) {
                setState(() {
                  isSaving = true;
                  savingMessage = 'Uploading student photo...';
                });
              }

              final newUrl = await controller.uploadChildPhotoFile(student.publicId, picked.path);

              if (context.mounted) {
                setState(() {
                  currentPhoto = newUrl;
                  isSaving = false;
                  savingMessage = null;
                });
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Student profile photo uploaded successfully.'),
                    backgroundColor: AppColors.green,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                setState(() {
                  isSaving = false;
                  savingMessage = null;
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to upload photo: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          Future<void> removePhoto() async {
            final controller = dialogContext.read<ParentController>();
            final messenger = ScaffoldMessenger.of(context);
            if (context.mounted) {
              setState(() {
                isSaving = true;
                savingMessage = 'Removing photo...';
              });
            }
            try {
              await controller.updateChildPhoto(student.publicId, '');

              if (context.mounted) {
                setState(() {
                  currentPhoto = null;
                  isSaving = false;
                  savingMessage = null;
                });
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Student profile photo removed. Letter avatar active.'),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                setState(() {
                  isSaving = false;
                  savingMessage = null;
                });
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Failed to remove photo: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              'Student Profile: ${student.fullName}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Live Avatar Preview Circle
                  Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasPhoto ? Colors.transparent : color,
                      border: Border.all(
                        color: hasPhoto ? AppColors.brand : color.withValues(alpha: 0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (hasPhoto ? AppColors.brand : color).withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: hasPhoto
                          ? Image.network(
                              currentPhoto!,
                              key: ValueKey(currentPhoto),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: color,
                                alignment: Alignment.center,
                                child: Text(
                                  initial,
                                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            )
                          : Container(
                              color: color,
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Text(
                    hasPhoto ? 'Photo Uploaded' : 'Letter Avatar ("$initial") Active',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: hasPhoto ? AppColors.brand : color,
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (isSaving)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            savingMessage ?? 'Processing...',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.slate.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Upload Portrait Photo',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Take a fresh photo or choose from gallery for the school transport map.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.slate, height: 1.3),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    side: const BorderSide(color: AppColors.brand, width: 1.2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.photo_library_rounded, size: 18, color: AppColors.brand),
                                  label: const Text(
                                    'Gallery',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.brand),
                                  ),
                                  onPressed: () => pickAndUpload(ImageSource.gallery),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 18, color: Colors.white),
                                  label: const Text(
                                    'Camera',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  onPressed: () => pickAndUpload(ImageSource.camera),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  if (hasPhoto && !isSaving) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                      label: const Text(
                        'Remove Photo',
                        style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w700),
                      ),
                      onPressed: removePhoto,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      );
    },
  );
}
