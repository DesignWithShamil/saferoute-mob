import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../repositories/notification_repository.dart';
import '../config/env.dart';
import '../notifications/notification_channels.dart';
import '../storage/token_storage.dart';

/// Runs in its own isolate when a message arrives while the app is in the
/// background or terminated. Notification messages are displayed by the OS
/// itself, so there is nothing to render here; taps are delivered through
/// [FirebaseMessaging.onMessageOpenedApp] / [FirebaseMessaging.getInitialMessage].
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  if (Env.firebaseConfigured && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: Env.firebaseOptions);
  }
}

class ForegroundMessage {
  const ForegroundMessage({required this.title, required this.body, required this.data});
  final String title;
  final String body;
  final Map<String, String> data;
}

/// FCM lifecycle: initialisation, permission, device-token registration with
/// the Django backend, and delivery of foreground messages / notification taps
/// to the app. Who receives what is decided entirely by the backend.
class NotificationService {
  NotificationService({required this._repository, required this._storage});

  final NotificationRepository _repository;
  final TokenStorage _storage;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  final _foreground = StreamController<ForegroundMessage>.broadcast();
  final _taps = StreamController<Map<String, String>>.broadcast();
  StreamSubscription<String>? _tokenRefreshSub;
  Map<String, String>? _launchTap;
  bool _firebaseReady = false;

  bool get isPushAvailable => _firebaseReady;
  Stream<ForegroundMessage> get foregroundMessages => _foreground.stream;
  Stream<Map<String, String>> get taps => _taps.stream;

  /// The notification that launched the app from a terminated state, if any.
  Map<String, String>? takeLaunchTap() {
    final tap = _launchTap;
    _launchTap = null;
    return tap;
  }

  Future<void> init() async {
    try {
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      await NotificationChannels.ensureCreated(_local);
    } catch (e) {
      debugPrint('Local notifications unavailable: $e');
    }

    if (!Env.firebaseConfigured) {
      debugPrint('Firebase is not configured; push notifications are disabled.');
      return;
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: Env.firebaseOptions);
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
      FirebaseMessaging.onMessage.listen((m) => _foreground.add(ForegroundMessage(
            title: m.notification?.title ?? 'SafeRoute',
            body: m.notification?.body ?? '',
            data: _stringify(m.data),
          )));
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(_stringify(m.data)));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _launchTap = _stringify(initial.data);
      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase initialisation failed; push disabled: $e');
    }
  }

  /// After sign-in: explain + request notification permission once, then
  /// register this device's FCM token for the signed-in user.
  Future<void> onSignedIn(BuildContext context) async {
    await _maybeAskPermission(context);
    if (!_firebaseReady) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) await _register(token);
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen(_register);
    } catch (e) {
      debugPrint('FCM token registration failed: $e');
    }
  }

  /// Before tokens are cleared: detach this device from the account so the
  /// next person to sign in on it doesn't receive the previous user's alerts.
  Future<void> onSigningOut() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    final token = await _storage.registeredFcmToken;
    if (token != null) {
      try {
        await _repository.unregisterDevice(token);
      } catch (_) {
        // Offline logout still proceeds; deleteToken below invalidates it at FCM.
      }
      await _storage.setRegisteredFcmToken(null);
    }
    if (_firebaseReady) {
      try {
        await FirebaseMessaging.instance.deleteToken();
      } catch (_) {}
    }
  }

  Future<void> _register(String token) async {
    await _repository.registerDevice(token, Platform.isIOS ? 'IOS' : 'ANDROID');
    await _storage.setRegisteredFcmToken(token);
  }

  Future<void> _maybeAskPermission(BuildContext context) async {
    if (await _storage.notificationPromptShown) return;
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('Stay informed'),
        content: const Text(
          'SafeRoute sends alerts when a trip starts, the bus is approaching, your child is picked up or dropped, '
          'and in emergencies. Drivers also see a notification while live location is being shared.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Allow notifications')),
        ],
      ),
    );
    await _storage.markNotificationPromptShown();
    if (proceed != true) return;
    try {
      if (_firebaseReady) {
        await FirebaseMessaging.instance.requestPermission();
      } else {
        await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  static Map<String, String> _stringify(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
}
