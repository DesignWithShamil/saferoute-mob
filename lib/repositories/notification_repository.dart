import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/app_notification.dart';
import '../models/json.dart';
import '../models/leave.dart';

class NotificationPage {
  const NotificationPage(this.items, {required this.hasMore});
  final List<AppNotification> items;
  final bool hasMore;
}

class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  /// [studentId] narrows a parent's inbox to one child's notifications.
  Future<NotificationPage> list({int page = 1, String? studentId}) async {
    final data = asMap(await _api.get(ApiEndpoints.notifications, query: {
      'page': page,
      'channel': 'IN_APP',
      'student': ?studentId,
    }));
    return NotificationPage(
      asList(data['results'], AppNotification.fromJson),
      hasMore: data['next'] != null,
    );
  }

  Future<int> unreadCount() async =>
      asInt(asMap(await _api.get(ApiEndpoints.notificationsUnreadCount))['unread_count']) ?? 0;

  Future<void> markRead(String id) => _api.post(ApiEndpoints.notificationRead(id));

  Future<void> markAllRead({String? studentId}) => _api.post(
        studentId == null ? ApiEndpoints.notificationsReadAll : '${ApiEndpoints.notificationsReadAll}?student=$studentId',
      );

  Future<void> registerDevice(String token, String platform) =>
      _api.post(ApiEndpoints.devices, data: {'token': token, 'platform': platform});

  Future<void> unregisterDevice(String token) => _api.delete(ApiEndpoints.devices, data: {'token': token});

  Future<void> delete(String id) => _api.delete(ApiEndpoints.notification(id));

  Future<void> clearAll({String? studentId}) => _api.delete(
        studentId == null ? ApiEndpoints.notificationsClearAll : '${ApiEndpoints.notificationsClearAll}?student=$studentId',
      );

  Future<List<NotificationPreference>> preferences() async {
    final data = await _api.get(ApiEndpoints.notificationPreferences);
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => NotificationPreference.fromJson(asMap(e))).toList();
  }

  Future<void> updatePreferences(List<NotificationPreference> items) =>
      _api.put(ApiEndpoints.notificationPreferences, data: {'preferences': [for (final p in items) p.toJson()]});
}
