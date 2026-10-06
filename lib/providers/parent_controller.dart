import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_services.dart';
import '../core/api/api_exception.dart';
import '../models/leave.dart';
import '../models/parent_live.dart';
import '../models/student.dart';

/// Parent data: the parent's children across schools (`/parent/children/`),
/// which child is selected, and that child's live trips
/// (`/gps/parent-live/?student=`, polled like the web parent dashboard).
/// Selecting a child is only a view choice; the backend checks every request
/// against the parent's own links.
class ParentController extends ChangeNotifier {
  ParentController(this._s);

  final AppServices _s;
  Timer? _poll;

  static const pollInterval = Duration(seconds: 10);

  bool loading = true;
  String? error;
  List<ParentLink> children = const [];
  String? _selectedId;
  List<ParentLiveTrip> live = const [];
  DateTime? liveUpdatedAt;
  String? liveError;
  int _liveRequest = 0;

  ParentLink? get selectedChild {
    if (children.isEmpty) return null;
    return childById(_selectedId ?? '') ?? children.first;
  }

  Future<void>? _loadFuture;

  Future<void> load() {
    if (_loadFuture != null) return _loadFuture!;
    _loadFuture = _doLoad();
    return _loadFuture!.whenComplete(() => _loadFuture = null);
  }

  Future<void> _doLoad() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _selectedId ??= await _s.storage.selectedChildId;
      children = await _s.transport.myChildren();
      if (selectedChild != null && selectedChild!.student.publicId != _selectedId) {
        _selectedId = selectedChild!.student.publicId;
      }
      try {
        await _fetchLive();
      } catch (e) {
        liveError = describeError(e);
      }
    } on ApiException catch (e) {
      error = switch (e.kind) {
        ApiErrorKind.unauthorized => 'Your session expired. Please sign in again.',
        ApiErrorKind.forbidden => e.message == 'Request failed.' ? 'Your account cannot access parent features.' : e.message,
        _ => e.message,
      };
    } catch (e) {
      error = describeError(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Switches every parent screen to [studentId] and reloads only that child's live data.
  Future<void> selectChild(String studentId) async {
    if (childById(studentId) == null || studentId == selectedChild?.student.publicId) return;
    _selectedId = studentId;
    live = const [];
    liveUpdatedAt = null;
    liveError = null;
    notifyListeners();
    unawaited(_s.storage.setSelectedChildId(studentId));
    await refreshLive();
  }

  Future<void> _fetchLive() async {
    final child = selectedChild;
    final request = ++_liveRequest;
    if (child == null) {
      live = const [];
      liveUpdatedAt = DateTime.now();
      return;
    }
    final result = await _s.transport.parentLive(studentId: child.student.publicId);
    // A slower response for a previously selected child must not overwrite this one.
    if (request != _liveRequest) return;
    live = result;
    liveUpdatedAt = DateTime.now();
    liveError = null;
  }

  Future<void> refreshLive() async {
    try {
      await _fetchLive();
    } catch (e) {
      liveError = describeError(e);
    }
    notifyListeners();
  }

  Future<ChildLinkPreview> previewLink(String schoolCode, String studentNumber, String linkCode, String relation) =>
      _s.transport.previewChildLink(schoolCode, studentNumber, linkCode, relation);

  /// Links the child, reloads the list and selects the new child.
  Future<ParentLink> confirmLink(String schoolCode, String studentNumber, String linkCode, String relation) async {
    final link = await _s.transport.confirmChildLink(schoolCode, studentNumber, linkCode, relation);
    _selectedId = link.student.publicId;
    unawaited(_s.storage.setSelectedChildId(_selectedId));
    await load();
    return link;
  }

  Future<void> unlink(String studentId) async {
    await _s.transport.unlinkChild(studentId);
    if (_selectedId == studentId) {
      _selectedId = null;
      unawaited(_s.storage.setSelectedChildId(null));
    }
    await load();
  }

  int _pollUsers = 0;

  /// Reference-counted so the home tab and an open live screen share one timer.
  void startPolling() {
    _pollUsers++;
    _poll ??= Timer.periodic(pollInterval, (_) => refreshLive());
  }

  void stopPolling() {
    if (_pollUsers > 0) _pollUsers--;
    if (_pollUsers == 0) {
      _poll?.cancel();
      _poll = null;
    }
  }

  ParentLink? childById(String studentId) {
    for (final c in children) {
      if (c.student.publicId == studentId) return c;
    }
    return null;
  }

  /// Live entry for [tripId], preferring the entry for [studentId] when a
  /// parent has several children on the same bus.
  ParentLiveTrip? liveFor(String tripId, {String? studentId}) {
    ParentLiveTrip? match;
    for (final entry in live) {
      if (entry.tripId != tripId) continue;
      if (studentId == null || entry.childId == studentId) return entry;
      match ??= entry;
    }
    return match;
  }

  List<ParentLiveTrip> liveForChild(String studentId) => live.where((e) => e.childId == studentId).toList();

  Future<List<AttendanceRecord>> attendanceHistory(String studentId) =>
      _s.attendance.historyForStudent(studentId);

  Future<List<LeaveRequest>> leavesFor(String studentId) => _s.attendance.leaves(studentId: studentId);

  Future<LeaveRequest> applyLeave({
    required String studentId,
    required String leaveType,
    required String startDate,
    required String endDate,
    String reason = '',
  }) =>
      _s.attendance.createLeave(
        studentId: studentId,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );

  Future<LeaveRequest> saveLeave(
    String leaveId, {
    required String studentId,
    required String leaveType,
    required String startDate,
    required String endDate,
    String reason = '',
  }) =>
      _s.attendance.updateLeave(
        leaveId,
        studentId: studentId,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
      );

  Future<void> cancelLeave(String leaveId) => _s.attendance.deleteLeave(leaveId);

  Future<ParentLink> childWithStops(String studentId) => _s.transport.childDetail(studentId);

  void reset() {
    _poll?.cancel();
    _poll = null;
    _pollUsers = 0;
    _liveRequest++;
    loading = true;
    error = null;
    children = const [];
    _selectedId = null;
    live = const [];
    liveUpdatedAt = null;
    liveError = null;
    unawaited(_s.storage.setSelectedChildId(null));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }
}
