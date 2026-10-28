import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/leave.dart';
import '../../models/student.dart';
import '../../models/transport.dart';
import '../../providers/operator_trip_controller.dart';
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
    this.lookupInfo,
    this.attendanceRecord,
  });

  final String studentId;
  final Student? initial;
  final StudentLookup? lookupInfo;
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
    _student = widget.initial ?? _fromLookup(widget.lookupInfo);
    _load();
  }

  static Student? _fromLookup(StudentLookup? l) {
    if (l == null) return null;
    return Student(
      publicId: l.publicId,
      fullName: l.fullName,
      admissionNumber: l.admissionNumber,
      pickupBus: l.morningBus != null ? BusRef(publicId: '', busNumber: l.morningBus!) : null,
      pickupStop: l.morningStop != null ? StopRef(publicId: '', name: l.morningStop!, sequence: 0) : null,
      dropBus: l.afternoonBus != null ? BusRef(publicId: '', busNumber: l.afternoonBus!) : null,
      dropStop: l.afternoonStop != null ? StopRef(publicId: '', name: l.afternoonStop!, sequence: 0) : null,
    );
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
      if (mounted) {
        // If we already have partial data from lookup, keep showing it without blocking the UI
        if (_student == null) {
          setState(() => _error = describeError(e));
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.attendanceRecord;
    final s = _student;

    final c = context.watch<OperatorTripController>();
    final myBusNumber = c.trip?.bus?.busNumber ??
        (c.routes.isNotEmpty ? c.routes.first.bus?.busNumber : null);
    final isPickupMyBus = myBusNumber == null ||
        s?.pickupBus == null ||
        s!.pickupBus!.busNumber.trim().toLowerCase() == myBusNumber.trim().toLowerCase();
    final isDropMyBus = myBusNumber == null ||
        s?.dropBus == null ||
        s!.dropBus!.busNumber.trim().toLowerCase() == myBusNumber.trim().toLowerCase();
    final isDifferentBus = myBusNumber != null &&
        (s?.pickupBus != null || s?.dropBus != null) &&
        !isPickupMyBus &&
        !isDropMyBus;

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
                          if (isDifferentBus) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
                                      ),
                                      const SizedBox(width: 10),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'ASSIGNED TO DIFFERENT BUS',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.5,
                                                color: Color(0xFF92400E),
                                              ),
                                            ),
                                            Text(
                                              'Not registered on your current bus roster',
                                              style: TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.wb_sunny_rounded, size: 16, color: Color(0xFFD97706)),
                                            const SizedBox(width: 8),
                                            const Text('Morning: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                                            Expanded(
                                              child: Text(
                                                s.pickupBus != null
                                                    ? 'Bus ${s.pickupBus!.busNumber}${s.pickupStop != null ? ' · ${s.pickupStop!.name}' : ''}'
                                                    : 'Not assigned',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 12, color: Color(0xFFFEF3C7)),
                                        Row(
                                          children: [
                                            const Icon(Icons.nights_stay_rounded, size: 16, color: Color(0xFF4338CA)),
                                            const SizedBox(width: 8),
                                            const Text('Evening: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                                            Expanded(
                                              child: Text(
                                                s.dropBus != null
                                                    ? 'Bus ${s.dropBus!.busNumber}${s.dropStop != null ? ' · ${s.dropStop!.name}' : ''}'
                                                    : 'Not assigned',
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4338CA)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                            crewDriver: s.dropDriver ?? s.assignedDriver,
                            crewHelper: s.dropHelper ?? s.assignedHelper,
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
