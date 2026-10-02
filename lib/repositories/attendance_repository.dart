import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/json.dart';
import '../models/leave.dart';
import '../models/student.dart';

class AttendanceRepository {
  AttendanceRepository(this._api);

  final ApiClient _api;

  /// Roster of the caller's own active trip (driver or helper).
  Future<List<AttendanceRecord>> roster() async {
    final data = await _api.get(ApiEndpoints.attendanceRoster);
    return asList(data, AttendanceRecord.fromJson);
  }

  /// [status] is one of BOARDED, ABSENT, DROPPED (ManualAttendanceSerializer).
  Future<AttendanceRecord> markManual(String studentId, String status) async => AttendanceRecord.fromJson(
        asMap(await _api.post(ApiEndpoints.attendanceManual, data: {'student_public_id': studentId, 'status': status})),
      );

  /// Returns the backend's own confirmation text, e.g. "Asha marked boarded".
  Future<String> scanQr(String qrToken) async {
    final body = await _api.postRaw(ApiEndpoints.attendanceScan, data: {'qr_token': qrToken});
    return body['message']?.toString() ?? 'Attendance recorded';
  }

  Future<void> verifyDrop(String studentId, String code) =>
      _api.post(ApiEndpoints.attendanceVerifyDrop, data: {'student_public_id': studentId, 'code': code});

  Future<List<AttendanceRecord>> historyForStudent(String studentId, {int pageSize = 50}) async {
    final rows = await _api.getList(ApiEndpoints.attendance, query: {'student': studentId, 'page_size': pageSize});
    return rows.whereType<Map>().map((e) => AttendanceRecord.fromJson(asMap(e))).toList();
  }

  Future<List<AttendanceRecord>> forTrip(String tripId, {int pageSize = 100}) async {
    final rows = await _api.getList(ApiEndpoints.attendance, query: {'trip': tripId, 'page_size': pageSize});
    return rows.whereType<Map>().map((e) => AttendanceRecord.fromJson(asMap(e))).toList();
  }

  Future<List<LeaveRequest>> leaves({String? studentId}) async {
    final rows = await _api.getList(ApiEndpoints.leaves, query: {
      'page_size': 50,
      'student': ?studentId,
    });
    return rows.whereType<Map>().map((e) => LeaveRequest.fromJson(asMap(e))).toList();
  }

  Future<LeaveRequest> createLeave({
    required String studentId,
    required String leaveType,
    required String startDate,
    required String endDate,
    String reason = '',
  }) async =>
      LeaveRequest.fromJson(asMap(await _api.post(ApiEndpoints.leaves, data: {
        'student_public_id': studentId,
        'leave_type': leaveType,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
      })));

  Future<LeaveRequest> updateLeave(
    String leaveId, {
    required String studentId,
    required String leaveType,
    required String startDate,
    required String endDate,
    String reason = '',
  }) async =>
      LeaveRequest.fromJson(asMap(await _api.patch(ApiEndpoints.leave(leaveId), data: {
        'student_public_id': studentId,
        'leave_type': leaveType,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
      })));

  Future<void> deleteLeave(String leaveId) => _api.delete(ApiEndpoints.leave(leaveId));
}
