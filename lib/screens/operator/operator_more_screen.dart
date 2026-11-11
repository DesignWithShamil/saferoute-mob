import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../widgets/state_views.dart';
import '../notifications/preferences_screen.dart';
import '../profile/profile_screen.dart';
import '../auth/user_tutorial_screen.dart';
import 'operator_route_map_screen.dart';
import 'sos_screen.dart';
import 'trip_history_screen.dart';

/// Extra Driver/Helper options from the React sidebar that don't fit in the
/// bottom bar: history, route map (driver), SOS, profile, alert preferences.
class OperatorMoreScreen extends StatelessWidget {
  const OperatorMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final isDriver = user?.isDriver ?? false;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _tile(context, Icons.history, 'Attendance history', 'Past trips and who boarded', const TripHistoryScreen()),
        if (isDriver)
          _tile(context, Icons.map_outlined, 'Route map', 'Assigned pickup and drop stops', const OperatorRouteMapScreen()),
        _tile(context, Icons.sos, 'Emergency SOS', 'Alert school admins and parents', const SosScreen()),
        _tile(context, Icons.notifications_outlined, 'Alert preferences', 'Choose which alerts you receive', const NotificationPreferencesScreen()),
        _tile(
          context,
          Icons.school_outlined,
          'Help & Tutorials',
          isDriver ? 'Driver step-by-step tutorial' : 'Helper step-by-step tutorial',
          UserTutorialScreen(
            userId: user?.publicId,
            initialRole: isDriver ? TutorialRole.driver : TutorialRole.helper,
            isStandalone: true,
            lockRole: true,
            onFinished: () => Navigator.of(context).pop(),
          ),
        ),
        _tile(context, Icons.person_outline, 'Profile', 'Account, school and sign out', const ProfileView()),
      ],
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String subtitle, Widget page) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: Icon(icon, color: AppColors.brand),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (page is NotificationPreferencesScreen || page is ProfileView || page is UserTutorialScreen) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => (page is NotificationPreferencesScreen || page is UserTutorialScreen)
                    ? page
                    : Scaffold(appBar: AppBar(title: Text(title)), body: page),
              ));
              return;
            }
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: page)));
          },
        ),
      );
}
