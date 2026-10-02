import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../models/student.dart';
import '../../models/transport.dart';
import '../../models/trip.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_map.dart';
import 'live_trip_screen.dart';
import 'parent_leaves_screen.dart';
import 'parent_route_map_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_c.children.isEmpty) await _c.load();
      // Opening a child (also from a notification) makes it the selected child.
      await _c.selectChild(widget.studentId);
    });
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
    await Future.wait([_c.load(), _history.catchError((_) => <AttendanceRecord>[])]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentController>();
    final link = c.childById(widget.studentId);

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
          padding: const EdgeInsets.all(16),
          children: [
            SectionCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    child: Text(s.fullName.isEmpty ? '?' : s.fullName.characters.first, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, style: Theme.of(context).textTheme.titleLarge),
                        Text(link.school.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text([
                          if (s.classLabel.isNotEmpty) 'Class ${s.classLabel}',
                          if (s.admissionNumber.isNotEmpty) 'Adm. ${s.admissionNumber}',
                          if (link.relation.isNotEmpty) link.relation,
                        ].join(' · ')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (final l in live)
              LiveTripSummaryCard(
                live: l,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LiveTripScreen(tripId: l.tripId, studentId: s.publicId),
                )),
              ),
            SectionCard(
              title: 'Transport',
              child: Column(
                children: [
                  if (places.isNotEmpty) ...[
                    TripMap(places: places, followBusByDefault: false, heightFraction: 0.28),
                    const SizedBox(height: 8),
                  ],
                  _AssignmentTile(title: 'Morning pickup', icon: Icons.wb_sunny_outlined, bus: s.pickupBus, stop: s.pickupStop, time: s.pickupStop?.pickupTime, route: link.pickupRoute),
                  const Divider(),
                  _AssignmentTile(title: 'Evening drop', icon: Icons.nights_stay_outlined, bus: s.dropBus, stop: s.dropStop, time: s.dropStop?.dropTime, route: link.dropRoute),
                  for (final contact in link.contacts) ...[
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(contact.label),
                      subtitle: Text([contact.fullName, if (contact.phone.isNotEmpty) contact.phone].join(' · ')),
                    ),
                  ],
                  if (s.requiresDropVerification) ...[
                    const Divider(),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.pin_outlined),
                      title: Text('Drop needs PIN verification'),
                      subtitle: Text('Give the drop PIN to the driver or helper at drop-off.'),
                    ),
                  ],
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('Route map'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(appBar: AppBar(title: const Text('Route map')), body: const ParentRouteMapScreen()),
                  )),
                ),
                ActionChip(
                  avatar: const Icon(Icons.event_busy_outlined, size: 18),
                  label: const Text('Leaves'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => Scaffold(appBar: AppBar(title: const Text('Leaves')), body: const ParentLeavesScreen()),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SectionCard(
              title: 'Recent attendance',
              child: FutureBuilder<List<AttendanceRecord>>(
                future: _history,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snap.hasError) {
                    return Text(describeError(snap.error!), style: const TextStyle(color: AppColors.red));
                  }
                  final rows = snap.data!;
                  if (rows.isEmpty) return const Text('No attendance records yet.');
                  return Column(
                    children: [
                      for (final r in rows)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text([
                            if (r.tripDate != null) _formatDate(r.tripDate!),
                            if (r.tripType != null) TripType.label(r.tripType!),
                          ].join(' · ')),
                          subtitle: Text([
                            if (r.stop != null) r.stop!.name,
                            if (r.boardedAt != null) 'Boarded ${DateFormat.jm().format(r.boardedAt!)}',
                            if (r.droppedAt != null) 'Dropped ${DateFormat.jm().format(r.droppedAt!)}',
                          ].join(' · ')),
                          trailing: StatusChip(label: childStatusLabel(r.status), color: AppColors.forStatus(r.status)),
                        ),
                    ],
                  );
                },
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

class _AssignmentTile extends StatelessWidget {
  const _AssignmentTile({required this.title, required this.icon, this.bus, this.stop, this.time, this.route});
  final String title;
  final IconData icon;
  final BusRef? bus;
  final StopRef? stop;
  final String? time;
  final ChildRoute? route;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(stop == null && bus == null
            ? 'Not assigned'
            : [
                if (bus != null) 'Bus ${bus!.busNumber}',
                if (route != null) route!.name,
                if (stop != null) stop!.name,
                if (time != null && time!.isNotEmpty) _time(time!),
              ].join(' · ')),
      );

  static String _time(String hhmmss) {
    final parts = hhmmss.split(':');
    if (parts.length < 2) return hhmmss;
    final dt = DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    return DateFormat.jm().format(dt);
  }
}
