import 'dart:async';
import 'dart:convert';
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
  final Set<String> _recentNotificationIds = {};
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
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              final map = Map<String, dynamic>.from(jsonDecode(payload) as Map);
              _taps.add(_stringify(map));
            } catch (_) {}
          }
        },
      );
      await NotificationChannels.ensureCreated(_local);

      final launchDetails = await _local.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true && launchDetails?.notificationResponse?.payload != null) {
        try {
          final map = Map<String, dynamic>.from(jsonDecode(launchDetails!.notificationResponse!.payload!) as Map);
          _launchTap = _stringify(map);
        } catch (_) {}
      }
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
      FirebaseMessaging.onMessage.listen((m) async {
        final title = m.notification?.title ?? (m.data['title']?.toString() ?? 'SafeRoute');
        final body = m.notification?.body ?? (m.data['body']?.toString() ?? m.data['message']?.toString() ?? '');
        final data = _stringify(m.data);

        final notifId = data['notification_id'];
        if (notifId != null && notifId.isNotEmpty) {
          if (_recentNotificationIds.contains(notifId)) return;
          _recentNotificationIds.add(notifId);
          if (_recentNotificationIds.length > 200) {
            _recentNotificationIds.remove(_recentNotificationIds.first);
          }
        }

        try {
          await _local.show(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: title,
            body: body,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                NotificationChannels.alertsId,
                'Trip & student alerts',
                channelDescription: 'Trip started, bus approaching, pickup/drop and emergency alerts.',
                importance: Importance.max,
                priority: Priority.high,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            payload: jsonEncode(data),
          );
        } catch (e) {
          debugPrint('Local foreground notification show error: $e');
        }

        _foreground.add(ForegroundMessage(
          title: title,
          body: body,
          data: data,
        ));
      });
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(_stringify(m.data)));
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _launchTap = _stringify(initial.data);
      _firebaseReady = true;

      // Print FCM token right on app startup so it's visible without waiting for sign-in
      try {
        final bootToken = await FirebaseMessaging.instance.getToken();
        debugPrint('=============================================');
        debugPrint('🔥 FCM TOKEN (App Startup): $bootToken');
        debugPrint('=============================================');
      } catch (tokenErr) {
        debugPrint('⚠️ FCM getToken on startup error: $tokenErr');
      }
    } catch (e) {
      debugPrint('Firebase initialisation failed; push disabled: $e');
    }
  }

  /// After sign-in: explain + request notification permission once, then
  /// register this device's FCM token for the signed-in user.
  Future<void> onSignedIn(BuildContext context) async {
    await _maybeAskPermission(context);
    if (!_firebaseReady) {
      await init();
    }
    if (!_firebaseReady) {
      debugPrint('⚠️ Firebase is not ready; cannot register FCM token.');
      return;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      debugPrint('=============================================');
      debugPrint('🔥 FCM TOKEN (Signed In): $token');
      debugPrint('=============================================');
      if (token != null && token.isNotEmpty) {
        await _register(token);
      }
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = messaging.onTokenRefresh.listen((t) {
        debugPrint('🔄 FCM TOKEN REFRESHED: $t');
        if (t.isNotEmpty) _register(t);
      });
    } catch (e) {
      debugPrint('❌ FCM token registration failed: $e');
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
    try {
      await _repository.registerDevice(token, Platform.isIOS ? 'IOS' : 'ANDROID');
      await _storage.setRegisteredFcmToken(token);
      debugPrint('Device successfully registered with backend FCM.');
    } catch (e) {
      debugPrint('Backend device registration failed: $e');
    }
  }

  Future<void> _maybeAskPermission(BuildContext context) async {
    try {
      if (_firebaseReady) {
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
      }
      try {
        await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}
    } catch (e) {
      debugPrint('Notification system permission check failed: $e');
    }

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
        await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        );
      }
      try {
        await _local
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (_) {}
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  static Map<String, String> _stringify(Map<String, dynamic> data) =>
      data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
}
