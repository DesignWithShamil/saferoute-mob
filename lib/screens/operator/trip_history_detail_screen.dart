import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/student.dart';
import '../../models/trip.dart';
import '../../widgets/sr_animations.dart';
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      SrFadeIn(
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${t.routeName} · ${TripType.label(t.tripType)}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        [
                                          if (t.date != null) t.date!,
                                          if (t.bus != null) 'Bus ${t.bus!.busNumber}',
                                        ].join(' · '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: AppColors.slate),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                StatusChip(label: TripStatus.label(t.status), color: AppColors.forStatus(t.status)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_attendance == null || _attendance!.isEmpty)
                        const EmptyView(icon: Icons.fact_check_outlined, title: 'No attendance records')
                      else
                        for (var i = 0; i < _attendance!.length; i++)
                          SrFadeIn(
                            delay: Duration(milliseconds: (i < 8 ? i : 8) * 40),
                            offset: 14,
                            child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _attendance![i].student.fullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            [
                                              _attendance![i].stop?.name ?? 'No stop',
                                              if (_attendance![i].student.admissionNumber.isNotEmpty) _attendance![i].student.admissionNumber,
                                            ].join(' · '),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, color: AppColors.slate),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    StatusChip(
                                      label: AttendanceStatus.label(_attendance![i].status),
                                      color: AppColors.forStatus(_attendance![i].status),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
