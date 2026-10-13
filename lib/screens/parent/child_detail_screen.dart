import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/student.dart';
import '../../models/trip.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_map.dart';
import 'live_trip_screen.dart';
import 'parent_leaves_screen.dart';
import 'parent_route_map_screen.dart';
import '../shared/student_detail_views.dart';
import 'parent_widgets.dart';

/// One linked child: transport assignment, any live trip, and recent
/// attendance. The child is looked up in the parent's own links; the
/// attendance history endpoint is scoped to the parent's children server-side.
class ChildDetailScreen extends StatefulWidget {
  const ChildDetailScreen({super.key, required this.studentId});
  final String studentId;

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> {
  late final ParentController _c = context.read<ParentController>();
  late Future<List<AttendanceRecord>> _history = _c.attendanceHistory(widget.studentId);
  ParentLink? _detailLink;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_c.children.isEmpty) await _c.load();
      await _c.selectChild(widget.studentId);
      await _refreshDetail();
    });
  }

  Future<void> _refreshDetail() async {
    try {
      final link = await context.read<AppServices>().transport.childDetail(widget.studentId);
      if (mounted) setState(() => _detailLink = link);
    } catch (_) {
      // Fall back to list payload from ParentController.
    }
  }

  Future<void> _unlink(ParentLink link) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove ${link.student.fullName}?',
      message: 'You will stop seeing ${link.student.fullName}\'s bus, trips and notifications. '
          'The school can give you a new link code to add them again.',
      confirm: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _c.unlink(link.student.publicId);
      if (!mounted) return;
      showSnack(context, '${link.student.fullName} removed from your account');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    }
  }

  Future<void> _refresh() async {
    setState(() => _history = _c.attendanceHistory(widget.studentId));
    await Future.wait([
      _c.load(),
      _refreshDetail(),
      _history.catchError((_) => <AttendanceRecord>[]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentController>();
    final link = _detailLink ?? c.childById(widget.studentId);

    if (link == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Child')),
        body: c.loading
            ? const LoadingView()
            : c.error != null
                ? ErrorView(message: c.error!, onRetry: c.load)
                : const EmptyView(icon: Icons.person_off_outlined, title: 'This child isn\'t linked to your account'),
      );
    }

    final s = link.student;
    final live = c.liveForChild(s.publicId);
    final places = [?schoolPlace(link.school), ...childStopPlaces(s)];
    return Scaffold(
      appBar: AppBar(
        title: Text(s.fullName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => _unlink(link),
            itemBuilder: (_) => const [PopupMenuItem(value: 'unlink', child: Text('Remove from my account'))],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            SrFadeIn(
              child: SectionCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                      child: Text(
                        s.fullName.isEmpty ? '?' : s.fullName.characters.first.toUpperCase(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.brand),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.fullName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            link.school.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (s.classLabel.isNotEmpty) 'Class ${s.classLabel}',
                              if (s.admissionNumber.isNotEmpty) 'Adm. ${s.admissionNumber}',
                              if (link.relation.isNotEmpty) link.relation,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppColors.slate),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            for (final l in live)
              SrFadeIn(
                delay: const Duration(milliseconds: 70),
                child: LiveTripSummaryCard(
                  live: l,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LiveTripScreen(tripId: l.tripId, studentId: s.publicId),
                  )),
                ),
              ),
            if (places.isNotEmpty)
              SrFadeIn(
                delay: const Duration(milliseconds: 110),
                child: SectionCard(
                  title: 'Map',
                  child: TripMap(places: places, followBusByDefault: false, heightFraction: 0.28),
                ),
              ),
            const SizedBox(height: 2),
            TransportLegSection(
              title: 'Morning pickup',
              icon: Icons.wb_sunny_outlined,
              bus: s.pickupBus,
              stop: s.pickupStop,
              routeName: link.pickupRoute?.name,
              routeStops: link.pickupRoute?.stops,
            ),
            const SizedBox(height: 14),
            TransportLegSection(
              title: 'Evening drop',
              icon: Icons.nights_stay_outlined,
              bus: s.dropBus,
              stop: s.dropStop,
              routeName: link.dropRoute?.name,
              routeStops: link.dropRoute?.stops,
            ),
            const SizedBox(height: 14),
            SrFadeIn(
              delay: const Duration(milliseconds: 150),
              child: SectionCard(
              title: 'Bus crew contacts',
              child: Column(
                children: [
                  if (link.contacts.isEmpty)
                    const Text('Contact details are not shared by this school.', style: TextStyle(fontSize: 14, color: AppColors.slate))
                  else
                    for (final contact in link.contacts)
                      ListTile(
                        minVerticalPadding: 8,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined, color: AppColors.brand),
                        title: Text(contact.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        subtitle: Text(
                          [contact.fullName, if (contact.phone.isNotEmpty) contact.phone].join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                      ),
                  if (s.requiresDropVerification) ...[
                    const Divider(color: AppColors.border),
                    const ListTile(
                      minVerticalPadding: 8,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.pin_outlined, color: AppColors.amber),
                      title: Text('Drop needs PIN verification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      subtitle: Text('Give the drop PIN to the driver or helper at drop-off.', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                    ),
                  ],
                ],
              ),
            ),
            ),
            ParentsSection(student: s),
            const SizedBox(height: 2),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                  avatar: const Icon(Icons.map_outlined, size: 18, color: AppColors.brand),
                  label: const Text('Route map', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(appBar: AppBar(title: const Text('Route map')), body: const ParentRouteMapScreen()),
                  )),
                ),
                ActionChip(
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                  avatar: const Icon(Icons.event_busy_outlined, size: 18, color: AppColors.brand),
                  label: const Text('Leaves', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(appBar: AppBar(title: const Text('Leaves')), body: const ParentLeavesScreen()),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SrFadeIn(
              delay: const Duration(milliseconds: 190),
              child: SectionCard(
              title: 'Recent attendance',
              child: FutureBuilder<List<AttendanceRecord>>(
                future: _history,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    return Text(describeError(snap.error!), style: const TextStyle(color: AppColors.red, fontSize: 14));
                  }
                  final rows = snap.data!;
                  if (rows.isEmpty) return const Text('No attendance records yet.', style: TextStyle(fontSize: 14, color: AppColors.slate));
                  return Column(
                    children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: AppColors.border),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      [
                                        if (rows[i].tripDate != null) _formatDate(rows[i].tripDate!),
                                        if (rows[i].tripType != null) TripType.label(rows[i].tripType!),
                                      ].join(' · '),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        [
                                          if (rows[i].stop != null) rows[i].stop!.name,
                                          if (rows[i].boardedAt != null) 'Boarded ${DateFormat.jm().format(rows[i].boardedAt!)}',
                                          if (rows[i].droppedAt != null) 'Dropped ${DateFormat.jm().format(rows[i].droppedAt!)}',
                                        ].join(' · '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusChip(label: childStatusLabel(rows[i].status), color: AppColors.forStatus(rows[i].status)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    return d == null ? isoDate : DateFormat('EEE, d MMM').format(d);
  }
}

