import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../providers/operator_trip_controller.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/preferences_screen.dart';
import '../operator/boarding_screen.dart';
import '../operator/operator_route_map_screen.dart';
import '../operator/sos_screen.dart';
import '../operator/students_roster_screen.dart';
import '../operator/trip_dashboard.dart';
import '../operator/trip_history_screen.dart';
import '../profile/profile_screen.dart';
import 'signed_in_shell.dart';

/// Home for DRIVER and HELPER. Bottom destinations match React
/// `DRIVER_BOTTOM_NAV` / `HELPER_BOTTOM_NAV` in navigation.js.
class OperatorHomeScreen extends StatelessWidget {
  const OperatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user!;
    final isDriver = user.isDriver;

    final tripActions = [
      IconButton(
        tooltip: 'Refresh',
        icon: const Icon(Icons.refresh),
        onPressed: () => context.read<OperatorTripController>().load(),
      ),
      IconButton(
        tooltip: 'Profile',
        icon: const Icon(Icons.person_outline),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(appBar: AppBar(title: const Text('Profile')), body: const ProfileView()),
        )),
      ),
    ];

    final alertsTab = ShellTab(
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
    );

    final tabs = <ShellTab>[
      ShellTab(
        label: 'Trip',
        title: isDriver ? 'Driver · Today\'s trip' : 'Helper · Today\'s trip',
        icon: Icons.directions_bus_outlined,
        body: const TripDashboard(),
        actions: tripActions,
      ),
      const ShellTab(label: 'Boarding', icon: Icons.checklist, body: BoardingScreen()),
      const ShellTab(label: 'History', icon: Icons.history, body: TripHistoryScreen()),
      const ShellTab(label: 'Route map', icon: Icons.map_outlined, body: OperatorRouteMapScreen()),
      const ShellTab(label: 'Students', icon: Icons.groups_outlined, body: StudentsRosterScreen()),
      alertsTab,
      const ShellTab(label: 'SOS', icon: Icons.sos, body: SosScreen()),
    ];

    final alertsIndex = tabs.indexWhere((t) => t.label == 'Alerts');

    return SignedInShell(
      scrollableNavigation: true,
      alertsTabIndex: alertsIndex >= 0 ? alertsIndex : null,
      tabs: tabs,
    );
  }
}
