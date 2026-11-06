import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android notification channels. [alertsId] must match ANDROID_CHANNEL_ID in
/// the backend's apps/notifications/push.py and the default channel in
/// AndroidManifest.xml.
class NotificationChannels {
  NotificationChannels._();

  static const alertsId = 'saferoute_alerts';
  static const trackingId = 'saferoute_tracking';
  static const trackingNotificationId = 7101;

  static Future<void> ensureCreated(FlutterLocalNotificationsPlugin plugin) async {
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(const AndroidNotificationChannel(
      alertsId,
      'Trip & student alerts',
      description: 'Trip started, bus approaching, pickup/drop and emergency alerts.',
      importance: Importance.high,
    ));
    await android.createNotificationChannel(const AndroidNotificationChannel(
      trackingId,
      'Live trip tracking',
      description: 'Shown while the bus location is being shared during an active trip.',
      importance: Importance.low,
      showBadge: false,
    ));
  }
}
