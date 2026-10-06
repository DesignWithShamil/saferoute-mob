import 'package:flutter/material.dart';

import '../../models/student.dart';
import 'operator_student_detail_screen.dart';

/// Opens full student detail (driver/helper roster, attendance, map).
void showStudentDetailSheet(BuildContext context, {required Student student, required AttendanceRecord? record}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => OperatorStudentDetailScreen(
        studentId: student.publicId,
        initial: student,
        attendanceRecord: record,
      ),
    ),
  );
}
