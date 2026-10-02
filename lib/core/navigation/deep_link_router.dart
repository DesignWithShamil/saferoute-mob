import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../repositories/notification_repository.dart';
import '../../screens/notifications/notifications_screen.dart';
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

    navigator.popUntil((route) => route.isFirst);
    final tripId = _nonEmpty(data['trip_id']);
    final studentId = _nonEmpty(data['student_id']);

    switch (user.role) {
      case UserRole.parent:
        if (tripId != null) {
          navigator.push(MaterialPageRoute(builder: (_) => LiveTripScreen(tripId: tripId, studentId: studentId)));
        } else if (studentId != null) {
          navigator.push(MaterialPageRoute(builder: (_) => ChildDetailScreen(studentId: studentId)));
        } else {
          navigator.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        }
      case UserRole.driver:
      case UserRole.helper:
        if (tripId != null || data['type'] == 'DRIVER_ASSIGNED') {
          operatorRefresh.value++;
        } else {
          navigator.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        }
      default:
        break;
    }
  }

  static String? _nonEmpty(String? v) => (v == null || v.isEmpty) ? null : v;
}
