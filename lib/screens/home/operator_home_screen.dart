import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../providers/operator_trip_controller.dart';
import '../notifications/notifications_screen.dart';
import '../operator/boarding_screen.dart';
import '../operator/operator_route_map_screen.dart';
import '../operator/sos_screen.dart';
import '../operator/students_roster_screen.dart';
import '../operator/trip_dashboard.dart';
import '../operator/trip_history_screen.dart';
import '../profile/profile_screen.dart';
import 'signed_in_shell.dart';

/// Home for DRIVER and HELPER.
/// Bottom navigation: exactly 4 items (Trip, Boarding, Students, Route map).
/// Secondary items (History, Alerts, SOS, Profile) are in the sidebar / drawer.
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

    final tabs = <ShellTab>[
      ShellTab(
        label: 'Trip',
        title: isDriver ? 'Driver · Today\'s trip' : 'Helper · Today\'s trip',
        icon: Icons.directions_bus_outlined,
        body: const TripDashboard(),
        actions: tripActions,
      ),
      const ShellTab(label: 'Boarding', icon: Icons.checklist, body: BoardingScreen()),
      const ShellTab(label: 'Students', icon: Icons.groups_outlined, body: StudentsRosterScreen()),
      const ShellTab(label: 'Route map', icon: Icons.map_outlined, body: OperatorRouteMapScreen()),
    ];

    final drawerItems = <ShellDrawerItem>[
      const ShellDrawerItem(label: 'Trip', icon: Icons.directions_bus_outlined, tabIndex: 0),
      const ShellDrawerItem(label: 'Boarding', icon: Icons.checklist, tabIndex: 1),
      const ShellDrawerItem(label: 'Students', icon: Icons.groups_outlined, tabIndex: 2),
      const ShellDrawerItem(label: 'Route map', icon: Icons.map_outlined, tabIndex: 3),
      ShellDrawerItem(
        label: 'Trip history',
        icon: Icons.history,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(appBar: AppBar(title: const Text('Trip History')), body: const TripHistoryScreen()),
        )),
      ),
      ShellDrawerItem(
        label: 'Alerts',
        icon: Icons.notifications_outlined,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const NotificationsScreen(),
        )),
      ),
      ShellDrawerItem(
        label: 'Emergency SOS',
        icon: Icons.sos,
        isDestructive: true,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(appBar: AppBar(title: const Text('Emergency SOS')), body: const SosScreen()),
        )),
      ),
      ShellDrawerItem(
        label: 'Profile',
        icon: Icons.person_outline,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => Scaffold(appBar: AppBar(title: const Text('Profile')), body: const ProfileView()),
        )),
      ),
    ];

    return SignedInShell(
      scrollableNavigation: false,
      tabs: tabs,
      drawerItems: drawerItems,
    );
  }
}
