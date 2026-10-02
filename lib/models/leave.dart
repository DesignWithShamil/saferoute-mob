import 'json.dart';
import 'student.dart';

class LeaveType {
  LeaveType._();
  static const fullDay = 'FULL_DAY';
  static const morning = 'MORNING';
  static const afternoon = 'AFTERNOON';

  static String label(String type) => switch (type) {
        morning => 'Morning only',
        afternoon => 'Afternoon only',
        _ => 'Full day',
      };
}

class LeaveStatus {
  LeaveStatus._();
  static const pending = 'PENDING';
  static const approved = 'APPROVED';
  static const rejected = 'REJECTED';
}

/// `/api/attendance/leaves/` row.
class LeaveRequest {
  const LeaveRequest({
    required this.publicId,
    required this.student,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    this.reason = '',
    this.status = LeaveStatus.approved,
  });

  final String publicId;
  final Student student;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String reason;
  final String status;

  bool get isUpcoming {
    final end = DateTime.tryParse(endDate);
    if (end == null) return true;
    final today = DateTime.now();
    final endDay = DateTime(end.year, end.month, end.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return !endDay.isBefore(todayDay);
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
        publicId: asString(json['public_id']) ?? '',
        student: Student.fromJson(asMap(json['student'])),
        leaveType: asString(json['leave_type']) ?? LeaveType.fullDay,
        startDate: asString(json['start_date']) ?? '',
        endDate: asString(json['end_date']) ?? '',
        reason: asString(json['reason']) ?? '',
        status: asString(json['status']) ?? LeaveStatus.approved,
      );
}

/// Driver/helper `/students/lookup/` payload.
class StudentLookup {
  const StudentLookup({
    required this.publicId,
    required this.fullName,
    this.admissionNumber = '',
    this.morningBus,
    this.morningStop,
    this.afternoonBus,
    this.afternoonStop,
  });

  final String publicId;
  final String fullName;
  final String admissionNumber;
  final String? morningBus;
  final String? morningStop;
  final String? afternoonBus;
  final String? afternoonStop;

  factory StudentLookup.fromJson(Map<String, dynamic> json) => StudentLookup(
        publicId: asString(json['public_id']) ?? '',
        fullName: asString(json['full_name']) ?? '',
        admissionNumber: asString(json['admission_number']) ?? '',
        morningBus: asString(json['morning_bus']),
        morningStop: asString(json['morning_stop']),
        afternoonBus: asString(json['afternoon_bus']),
        afternoonStop: asString(json['afternoon_stop']),
      );
}

class NotificationPreference {
  const NotificationPreference({required this.type, required this.enabled});
  final String type;
  final bool enabled;

  String get label => type.replaceAll('_', ' ');

  NotificationPreference copyWith({bool? enabled}) =>
      NotificationPreference(type: type, enabled: enabled ?? this.enabled);

  factory NotificationPreference.fromJson(Map<String, dynamic> json) => NotificationPreference(
        type: asString(json['notification_type']) ?? '',
        enabled: json['enabled'] != false,
      );

  Map<String, dynamic> toJson() => {'notification_type': type, 'enabled': enabled};
}
