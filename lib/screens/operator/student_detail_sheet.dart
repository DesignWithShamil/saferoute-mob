import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../models/transport.dart';
import '../../utils/attendance_display.dart';
import '../../widgets/state_views.dart';

/// Full student context for driver/helper (roster tap or map stop).
void showStudentDetailSheet(BuildContext context, {required Student student, required AttendanceRecord? record}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 8, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: _StudentDetailBody(student: student, record: record),
    ),
  );
}

class _StudentDetailBody extends StatelessWidget {
  const _StudentDetailBody({required this.student, required this.record});
  final Student student;
  final AttendanceRecord? record;

  String _stopLine(StopRef? stop, String label) {
    if (stop == null || stop.name.isEmpty) return '$label: —';
    if (stop.address.isEmpty) return '$label: ${stop.name}';
    return '$label: ${stop.name} (${stop.address})';
  }

  @override
  Widget build(BuildContext context) {
    final parent = student.primaryParent;
    final age = student.ageYears;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                child: Text(student.fullName.isNotEmpty ? student.fullName.characters.first.toUpperCase() : '?'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.fullName, style: Theme.of(context).textTheme.titleLarge),
                    Text([if (age != null) 'Age $age', student.classLabel, student.admissionNumber].where((s) => s.isNotEmpty).join(' · ')),
                  ],
                ),
              ),
              if (record != null) StatusChip(label: AttendanceStatus.label(record!.status), color: AppColors.forStatus(record!.status)),
            ],
          ),
          const SizedBox(height: 16),
          _row(Icons.phone_outlined, 'Parent', parent?.phone.isNotEmpty == true ? '${parent!.fullName} · ${parent.phone}' : (student.emergencyContactPhone.isNotEmpty ? student.emergencyContactPhone : '—')),
          if (parent?.email.isNotEmpty == true) _row(Icons.email_outlined, 'Email', parent!.email),
          _row(Icons.wb_sunny_outlined, 'Morning pickup', _stopLine(student.pickupStop, 'Stop')),
          _row(Icons.nights_stay_outlined, 'Evening drop (assigned)', _stopLine(student.dropStop, 'Stop')),
          if (record?.droppedAtStop != null)
            _row(Icons.place_outlined, 'Actual drop stop', _stopLine(record!.droppedAtStop, 'Stop')),
          if (dropLocationHint(record) != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(dropLocationHint(record)!, style: const TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w600)),
            ),
          if (student.bloodGroup != null && student.bloodGroup!.isNotEmpty) _row(Icons.bloodtype_outlined, 'Blood group', student.bloodGroup!),
          if (student.requiresDropVerification)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Drop-off: parent must give the PIN from the boarding notification. Use Verify & Drop only.',
                style: TextStyle(fontSize: 12, color: AppColors.amber),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.slate),
            const SizedBox(width: 10),
            Expanded(child: Text('$label\n$value', style: const TextStyle(height: 1.35))),
          ],
        ),
      );
}
