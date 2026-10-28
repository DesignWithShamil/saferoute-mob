import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/student.dart';
import '../../utils/attendance_display.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';
import '../shared/student_detail_views.dart';

/// Full student profile for driver/helper (roster tap, lookup, attendance).
class OperatorStudentDetailScreen extends StatefulWidget {
  const OperatorStudentDetailScreen({
    super.key,
    required this.studentId,
    this.initial,
    this.attendanceRecord,
  });

  final String studentId;
  final Student? initial;
  final AttendanceRecord? attendanceRecord;

  @override
  State<OperatorStudentDetailScreen> createState() => _OperatorStudentDetailScreenState();
}

class _OperatorStudentDetailScreenState extends State<OperatorStudentDetailScreen> {
  Student? _student;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _student = widget.initial;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await context.read<AppServices>().transport.studentDetail(widget.studentId);
      if (mounted) setState(() => _student = s);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.attendanceRecord;
    final s = _student;
    return Scaffold(
      appBar: AppBar(title: Text(s?.fullName.isNotEmpty == true ? s!.fullName : 'Student')),
      body: _loading && s == null
          ? const LoadingView(label: 'Loading student…')
          : _error != null && s == null
              ? ErrorView(message: _error!, onRetry: _load)
              : s == null
                  ? const EmptyView(icon: Icons.person_off_outlined, title: 'Student not found')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          SrFadeIn(
                            child: StudentHeaderCard(
                              student: s,
                              trailing: record != null
                                  ? StatusChip(label: AttendanceStatus.label(record.status), color: AppColors.forStatus(record.status))
                                  : null,
                            ),
                          ),
                          if (record?.droppedAtStop != null) ...[
                            const SizedBox(height: 12),
                            SectionCard(
                              title: 'Today\'s drop',
                              child: Text(
                                dropLocationHint(record) ?? record!.droppedAtStop!.name,
                                style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.ink),
                              ),
                            ),
                          ],
                          if (s.requiresDropVerification)
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.amber.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.pin_outlined, color: AppColors.amber, size: 24),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Drop requires parent PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
                                          SizedBox(height: 2),
                                          Text('Use Verify & Drop at drop-off only.', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          ParentsSection(student: s),
                          const SizedBox(height: 12),
                          TransportLegSection(
                            title: 'Morning pickup',
                            icon: Icons.wb_sunny_outlined,
                            bus: s.pickupBus,
                            stop: s.pickupStop,
                            crewDriver: s.assignedDriver,
                            crewHelper: s.assignedHelper,
                          ),
                          const SizedBox(height: 12),
                          TransportLegSection(
                            title: 'Evening drop',
                            icon: Icons.nights_stay_outlined,
                            bus: s.dropBus,
                            stop: s.dropStop,
                          ),
                          if (s.medicalInfo.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            SectionCard(
                              title: 'Medical notes',
                              child: Text(s.medicalInfo, style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.ink)),
                            ),
                          ],
                        ],
                      ),
                    ),
    );
  }
}
