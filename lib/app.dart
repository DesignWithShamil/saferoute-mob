import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_services.dart';
import 'core/firebase/notification_service.dart';
import 'models/user.dart';
import 'providers/auth_controller.dart';
import 'providers/notifications_controller.dart';
import 'providers/operator_trip_controller.dart';
import 'providers/parent_controller.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/operator_home_screen.dart';
import 'screens/home/parent_home_screen.dart';
import 'theme/saferoute_theme.dart';
import 'widgets/state_views.dart';

class SafeRouteApp extends StatelessWidget {
  const SafeRouteApp({super.key, required this.services});
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider(create: (_) => OperatorTripController(services)),
        ChangeNotifierProvider(create: (_) => ParentController(services)),
        ChangeNotifierProvider(create: (_) => NotificationsController(services)),
        ChangeNotifierProvider(
          create: (ctx) {
            final auth = AuthController(services);
            auth.addSignOutHook(() {
              ctx.read<OperatorTripController>().reset();
              ctx.read<ParentController>().reset();
              ctx.read<NotificationsController>().reset();
            });
            return auth..bootstrap();
          },
        ),
      ],
      child: MaterialApp(
        title: 'SafeRoute',
        debugShowCheckedModeBanner: false,
        navigatorKey: services.navigatorKey,
        scaffoldMessengerKey: services.messengerKey,
        theme: SafeRouteTheme.light(),
        home: const _PushBridge(child: _RoleGate()),
      ),
    );
  }
}

/// Picks the home screen for the signed-in role.
class _RoleGate extends StatelessWidget {
  const _RoleGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    switch (auth.status) {
      case AuthStatus.loading:
        return const Scaffold(body: LoadingView(label: 'Starting SafeRoute…', branded: true));
      case AuthStatus.unreachable:
        return Scaffold(
          body: ErrorView(
            message: 'Can\'t reach the SafeRoute server.\n${auth.message ?? ''}',
            onRetry: auth.bootstrap,
          ),
        );
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.signedIn:
        final user = auth.user!;
        return switch (user.role) {
          UserRole.driver || UserRole.helper => OperatorHomeScreen(key: ValueKey(user.publicId)),
          UserRole.parent => ParentHomeScreen(key: ValueKey(user.publicId)),
          _ => const _UnsupportedRole(),
        };
    }
  }
}

class _UnsupportedRole extends StatelessWidget {
  const _UnsupportedRole();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EmptyView(
              icon: Icons.desktop_windows_outlined,
              title: '${UserRole.label(auth.user?.role ?? '')} accounts use the web dashboard',
              message: 'The SafeRoute mobile app is for drivers, helpers and parents.',
            ),
            FilledButton(onPressed: auth.logout, child: const Text('Sign out')),
          ],
        ),
      ),
    );
  }
}

/// Connects FCM events to the UI: foreground messages become a SnackBar with
/// an Open action, and notification taps (including the one that launched
/// the app) go through the role-aware deep-link router.
class _PushBridge extends StatefulWidget {
  const _PushBridge({required this.child});
  final Widget child;

  @override
  State<_PushBridge> createState() => _PushBridgeState();
}

class _PushBridgeState extends State<_PushBridge> {
  late final AppServices _s = context.read<AppServices>();
  final _subs = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    final push = _s.notificationService;
    _subs.add(push.foregroundMessages.listen(_onForeground));
    _subs.add(push.taps.listen(_s.deepLinks.open));
    final launch = push.takeLaunchTap();
    if (launch != null) _s.deepLinks.open(launch);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _onForeground(ForegroundMessage m) {
    if (!mounted) return;
    context.read<NotificationsController>().refreshUnread();
    final data = m.data;
    final canOpen = data.containsKey('trip_id') || data.containsKey('student_id');
    _s.messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (m.body.isNotEmpty) Text(m.body),
          ],
        ),
        action: canOpen ? SnackBarAction(label: 'OPEN', onPressed: () => _s.deepLinks.open(data)) : null,
      ));
    if (data.containsKey('trip_id')) _s.deepLinks.operatorRefresh.value++;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
