import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../models/student.dart';
import '../../models/trip.dart';
import '../../widgets/state_views.dart';

/// Full attendance list for one past trip (opened from History tab).
class TripHistoryDetailScreen extends StatefulWidget {
  const TripHistoryDetailScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<TripHistoryDetailScreen> createState() => _TripHistoryDetailScreenState();
}

class _TripHistoryDetailScreenState extends State<TripHistoryDetailScreen> {
  List<AttendanceRecord>? _attendance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await context.read<AppServices>().attendance.forTrip(widget.trip.publicId);
      if (mounted) setState(() => _attendance = rows);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip attendance'),
      ),
      body: _loading
          ? const LoadingView(label: 'Loading attendance…')
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          title: Text('${t.routeName} · ${TripType.label(t.tripType)}'),
                          subtitle: Text([
                            if (t.date != null) t.date!,
                            if (t.bus != null) 'Bus ${t.bus!.busNumber}',
                          ].join(' · ')),
                          trailing: StatusChip(label: TripStatus.label(t.status), color: AppColors.forStatus(t.status)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_attendance == null || _attendance!.isEmpty)
                        const EmptyView(icon: Icons.fact_check_outlined, title: 'No attendance records')
                      else
                        for (final r in _attendance!)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(r.student.fullName),
                              subtitle: Text([
                                r.stop?.name ?? 'No stop',
                                if (r.student.admissionNumber.isNotEmpty) r.student.admissionNumber,
                              ].join(' · ')),
                              trailing: StatusChip(
                                label: AttendanceStatus.label(r.status),
                                color: AppColors.forStatus(r.status),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
