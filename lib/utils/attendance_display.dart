import '../models/student.dart';

/// When a student drops at a stop other than assigned, show both names.
String? dropLocationHint(AttendanceRecord? record) {
  if (record == null) return null;
  final dropped = record.droppedAtStop?.name;
  final assigned = record.stop?.name;
  final isDrop = record.status == AttendanceStatus.dropped || record.status == AttendanceStatus.dropVerified;
  if (!isDrop || dropped == null || dropped.isEmpty) return null;
  if (assigned != null && assigned.isNotEmpty && dropped != assigned) {
    return 'Assigned $assigned · Dropped at $dropped';
  }
  return 'Dropped at $dropped';
}
