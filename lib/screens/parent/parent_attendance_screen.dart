import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../models/student.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';
import 'parent_widgets.dart';

/// React `/parent/attendance` for the selected child.
class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen> {
  late final ParentController _c = context.read<ParentController>();
  Future<List<AttendanceRecord>>? _history;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    final id = _c.selectedChild?.student.publicId;
    setState(() {
      _studentId = id;
      _history = id == null ? null : _c.attendanceHistory(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentController>();
    if (c.selectedChild?.student.publicId != _studentId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }
    final child = c.selectedChild;
    if (child == null) {
      return const EmptyView(icon: Icons.family_restroom, title: 'Add a child to see attendance');
    }
    return Column(
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: SelectedChildHeader()),
        Expanded(
          child: FutureBuilder<List<AttendanceRecord>>(
            future: _history,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingView(label: 'Loading attendance…');
              if (snap.hasError) return ErrorView(message: describeError(snap.error!), onRetry: _reload);
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(children: const [
                    SizedBox(height: 80),
                    EmptyView(icon: Icons.fact_check_outlined, title: 'No attendance records yet'),
                  ]),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text([
                        if (r.tripDate != null) _date(r.tripDate!),
                        if (r.tripType != null) r.tripType == 'AFTERNOON' ? 'Evening' : 'Morning',
                      ].join(' · ')),
                      subtitle: Text([
                        if (r.stop != null) r.stop!.name,
                        if (r.busNumber != null && r.busNumber!.isNotEmpty) 'Bus ${r.busNumber}',
                      ].join(' · ')),
                      trailing: StatusChip(label: childStatusLabel(r.status), color: AppColors.forStatus(r.status)),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  static String _date(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('EEE, d MMM').format(d);
  }
}
