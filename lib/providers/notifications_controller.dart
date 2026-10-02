import 'package:flutter/foundation.dart';

import '../app_services.dart';
import '../core/api/api_exception.dart';
import '../models/app_notification.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._s);

  final AppServices _s;

  bool loading = false;
  bool loadingMore = false;
  String? error;
  List<AppNotification> items = const [];
  int unread = 0;
  int _page = 1;
  bool hasMore = false;

  /// Parent inbox filter: one child's notifications, or null for all.
  String? studentFilter;

  /// Parent choice between "selected child" and "all children".
  bool showAllChildren = false;
  int _loadRequest = 0;

  Future<void> setStudentFilter(String? studentId) async {
    if (studentId == studentFilter) return;
    studentFilter = studentId;
    await load();
  }

  Future<void> setShowAllChildren(bool value, {String? selectedChildId}) async {
    if (value == showAllChildren && (value || studentFilter == selectedChildId)) return;
    showAllChildren = value;
    await setStudentFilter(value ? null : selectedChildId);
  }

  Future<void> filterByChild(String studentId) async {
    showAllChildren = false;
    await setStudentFilter(studentId);
  }

  Future<void> load() async {
    loading = true;
    error = null;
    final request = ++_loadRequest;
    notifyListeners();
    try {
      final page = await _s.notifications.list(page: 1, studentId: studentFilter);
      if (request != _loadRequest) return;
      items = page.items;
      hasMore = page.hasMore;
      _page = 1;
      unread = await _s.notifications.unreadCount();
    } catch (e) {
      if (request == _loadRequest) error = describeError(e);
    } finally {
      if (request == _loadRequest) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await _s.notifications.list(page: _page + 1, studentId: studentFilter);
      items = [...items, ...page.items];
      hasMore = page.hasMore;
      _page += 1;
    } catch (_) {
      // Leave the list as-is; the user can scroll again to retry.
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> refreshUnread() async {
    try {
      unread = await _s.notifications.unreadCount();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    items = [for (final i in items) i.publicId == n.publicId ? i.copyWith(isRead: true) : i];
    if (unread > 0) unread--;
    notifyListeners();
    try {
      await _s.notifications.markRead(n.publicId);
    } catch (_) {}
  }

  Future<String?> markAllRead() async {
    try {
      await _s.notifications.markAllRead(studentId: studentFilter);
      items = [for (final i in items) i.copyWith(isRead: true)];
      unread = studentFilter == null ? 0 : await _s.notifications.unreadCount();
      notifyListeners();
      return null;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<String?> delete(AppNotification n) async {
    try {
      await _s.notifications.delete(n.publicId);
      items = [for (final i in items) if (i.publicId != n.publicId) i];
      if (!n.isRead && unread > 0) unread--;
      notifyListeners();
      return null;
    } catch (e) {
      return describeError(e);
    }
  }

  Future<String?> clearAll() async {
    try {
      await _s.notifications.clearAll(studentId: studentFilter);
      items = const [];
      unread = studentFilter == null ? 0 : await _s.notifications.unreadCount();
      hasMore = false;
      notifyListeners();
      return null;
    } catch (e) {
      return describeError(e);
    }
  }

  void reset() {
    items = const [];
    unread = 0;
    hasMore = false;
    _page = 1;
    error = null;
    studentFilter = null;
    showAllChildren = false;
    _loadRequest++;
  }
}
