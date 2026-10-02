import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/student.dart';
import '../../models/trip.dart';
import '../../widgets/state_views.dart';

/// React `/driver/history` and `/helper/history`.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Trip> _trips = const [];
  bool _loading = true;
  String? _error;
  String? _openId;
  List<AttendanceRecord>? _attendance;
  bool _attendanceLoading = false;

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
      final trips = await context.read<AppServices>().trips.recent();
      trips.sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
      if (mounted) setState(() => _trips = trips);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Trip trip) async {
    if (_openId == trip.publicId) {
      setState(() {
        _openId = null;
        _attendance = null;
      });
      return;
    }
    setState(() {
      _openId = trip.publicId;
      _attendanceLoading = true;
      _attendance = null;
    });
    try {
      final rows = await context.read<AppServices>().attendance.forTrip(trip.publicId);
      if (mounted) setState(() => _attendance = rows);
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _attendanceLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(label: 'Loading trip history…');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_trips.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 80),
          EmptyView(icon: Icons.history, title: 'No trips yet'),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (context, i) {
          final t = _trips[i];
          final open = t.publicId == _openId;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                ListTile(
                  title: Text('${t.routeName} · ${TripType.label(t.tripType)}'),
                  subtitle: Text([
                    if (t.date != null) t.date!,
                    if (t.bus != null) 'Bus ${t.bus!.busNumber}',
                  ].join(' · ')),
                  trailing: StatusChip(label: TripStatus.label(t.status), color: AppColors.forStatus(t.status)),
                  onTap: () => _toggle(t),
                ),
                if (open)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _attendanceLoading
                        ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                        : Column(
                            children: [
                              if (_attendance == null || _attendance!.isEmpty)
                                const Text('No attendance records for this trip.')
                              else
                                for (final r in _attendance!)
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(r.student.fullName),
                                    subtitle: Text(r.stop?.name ?? ''),
                                    trailing: StatusChip(label: AttendanceStatus.label(r.status), color: AppColors.forStatus(r.status)),
                                  ),
                            ],
                          ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
