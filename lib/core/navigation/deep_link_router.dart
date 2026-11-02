import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../repositories/notification_repository.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/operator/staff_message_thread_screen.dart';
import '../../screens/parent/child_detail_screen.dart';
import '../../screens/parent/live_trip_screen.dart';

/// Turns a notification payload (`type`, `trip_id`, `student_id`, ...) into
/// navigation for the signed-in role. Only ids travel in the payload; each
/// destination screen loads its details from the backend, which re-checks
/// that the user may see them.
class DeepLinkRouter {
  DeepLinkRouter({required this.navigatorKey, required this._notifications});

  final GlobalKey<NavigatorState> navigatorKey;
  final NotificationRepository _notifications;

  /// Bumped when a driver/helper opens a trip notification, so the trip
  /// dashboard reloads immediately instead of waiting for its next poll.
  final ValueNotifier<int> operatorRefresh = ValueNotifier(0);

  AppUser? _user;
  Map<String, String>? _pending;

  void attachUser(AppUser? user) {
    _user = user;
    if (user == null) {
      _pending = null;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _flush());
    }
  }

  void open(Map<String, String> data) {
    if (data.isEmpty) return;
    _pending = data;
    _flush();
  }

  void _flush() {
    final user = _user;
    final data = _pending;
    final navigator = navigatorKey.currentState;
    if (user == null || data == null || navigator == null) return;
    _pending = null;

    final notificationId = data['notification_id'];
    if (notificationId != null && notificationId.isNotEmpty) {
      _notifications.markRead(notificationId).catchError((_) {});
    }

    final tripId = _nonEmpty(data['trip_id']);
    final studentId = _nonEmpty(data['student_id']);
    final conversationId = _nonEmpty(data['conversation_id']);

    final isAnnouncement = data['kind'] == 'school_announcement' ||
        data['type'] == 'ANNOUNCEMENT' ||
        data['type'] == 'STAFF_MESSAGE' ||
        data['type'] == 'HOLIDAY_NOTICE';
    final isAlert = data['type'] == 'EMERGENCY_ALERT' ||
        data['type'] == 'BUS_DELAYED' ||
        data['type'] == 'TRIP_CANCELLED';
    final targetCategory = isAnnouncement
        ? 'ANNOUNCEMENTS'
        : (isAlert ? 'ALERTS' : 'ALL');

    Widget? destination;

    switch (user.role) {
      case UserRole.parent:
        if (tripId != null) {
          destination = LiveTripScreen(tripId: tripId, studentId: studentId);
        } else if (studentId != null && !isAnnouncement) {
          destination = ChildDetailScreen(studentId: studentId);
        } else {
          destination = NotificationsScreen(initialCategory: targetCategory);
        }
      case UserRole.driver:
      case UserRole.helper:
        if (conversationId != null) {
          destination = Scaffold(
            appBar: AppBar(title: const Text('School Announcements')),
            body: StaffMessageThreadScreen(conversationId: conversationId),
          );
        } else if (tripId != null || data['type'] == 'DRIVER_ASSIGNED') {
          operatorRefresh.value++;
          navigator.popUntil((route) => route.isFirst);
          return;
        } else {
          destination = NotificationsScreen(initialCategory: targetCategory);
        }
      default:
        break;
    }

    if (destination != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => destination!),
        (route) => route.isFirst,
      );
    }
  }


  static String? _nonEmpty(String? v) => (v == null || v.isEmpty) ? null : v;
}
