import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/preferences_screen.dart';
import '../parent/add_child_screen.dart';
import '../parent/child_detail_screen.dart';
import '../parent/children_list_screen.dart';
import '../parent/live_trip_screen.dart';
import '../parent/parent_attendance_screen.dart';
import '../parent/parent_fees_screen.dart';
import '../parent/parent_leaves_screen.dart';
import '../parent/parent_route_map_screen.dart';
import '../parent/parent_widgets.dart';
import '../profile/profile_screen.dart';
import 'signed_in_shell.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ParentController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <ShellTab>[
      ShellTab(
        label: 'Home',
        title: 'Home',
        icon: Icons.home_outlined,
        body: const _HomeTab(),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => Scaffold(appBar: AppBar(title: const Text('Profile')), body: const ProfileView()),
            )),
          ),
        ],
      ),
      const ShellTab(label: 'Children', title: 'My children', icon: Icons.family_restroom, body: ChildrenListScreen()),
      const ShellTab(label: 'Attendance', icon: Icons.fact_check_outlined, body: ParentAttendanceScreen()),
      const ShellTab(label: 'Leaves', icon: Icons.event_busy_outlined, body: ParentLeavesScreen()),
      const ShellTab(label: 'Route', icon: Icons.map_outlined, body: ParentRouteMapScreen()),
      const ShellTab(label: 'Fees', icon: Icons.credit_card_outlined, body: ParentFeesScreen()),
      ShellTab(
        label: 'Alerts',
        title: 'Notifications',
        icon: Icons.notifications_outlined,
        body: const NotificationsList(),
        actions: [
          IconButton(
            tooltip: 'Preferences',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen())),
          ),
        ],
      ),
    ];
    final alertsIndex = tabs.indexWhere((t) => t.label == 'Alerts');
    return SignedInShell(
      scrollableNavigation: true,
      alertsTabIndex: alertsIndex >= 0 ? alertsIndex : null,
      tabs: tabs,
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with WidgetsBindingObserver {
  late final ParentController _c = context.read<ParentController>();
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setPolling(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setPolling(false);
    super.dispose();
  }

  void _setPolling(bool on) {
    if (on == _polling) return;
    _polling = on;
    on ? _c.startPolling() : _c.stopPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _setPolling(false);
    if (state == AppLifecycleState.resumed) {
      _setPolling(true);
      _c.refreshLive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentController>();
    if (c.loading && c.children.isEmpty) return const LoadingView(label: 'Loading your children…');
    if (c.error != null && c.children.isEmpty) return ErrorView(message: c.error!, onRetry: c.load);
    final link = c.selectedChild;
    if (link == null) {
      return RefreshIndicator(
        onRefresh: c.load,
        child: ListView(children: [
          const SizedBox(height: 120),
          const EmptyView(
            icon: Icons.family_restroom,
            title: 'No children linked yet',
            message: 'Add your child with the link code from their school.',
          ),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add child'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddChildScreen())),
            ),
          ),
        ]),
      );
    }

    final s = link.student;
    final trips = c.liveForChild(s.publicId);
    void openDetails() =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChildDetailScreen(studentId: s.publicId)));

    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const SelectedChildHeader(),
          if (c.liveError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Live status couldn\'t refresh: ${c.liveError}', style: const TextStyle(color: AppColors.red)),
            ),
          if (c.liveUpdatedAt == null && c.liveError == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (trips.isEmpty)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.directions_bus_outlined),
                title: Text('No active trip for ${s.fullName} right now'),
                subtitle: Text([
                  if (link.pickupRoute != null) 'Morning: ${link.pickupRoute!.name}',
                  if (link.dropRoute != null) 'Evening: ${link.dropRoute!.name}',
                ].join(' · ')),
              ),
            )
          else
            for (final live in trips)
              LiveTripSummaryCard(
                live: live,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LiveTripScreen(tripId: live.tripId, studentId: s.publicId),
                )),
              ),
          OutlinedButton.icon(
            icon: const Icon(Icons.info_outline),
            label: Text('${s.fullName} – details & attendance'),
            onPressed: openDetails,
          ),
        ],
      ),
    );
  }
}
