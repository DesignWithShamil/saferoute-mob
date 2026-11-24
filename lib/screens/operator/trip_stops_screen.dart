import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../models/trip.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';

const _schoolColor = AppColors.teal;

/// All route stops with student counts and arrived/departed times.
class TripStopsScreen extends StatelessWidget {
  const TripStopsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final trip = c.trip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route stops')),
        body: const Center(child: Text('No active trip')),
      );
    }
    final counts = studentsPerStopFromRoster(c.roster);
    return Scaffold(
      appBar: AppBar(title: Text('Stops (${trip.tripStops.length})')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          SrFadeIn(
            child: _LegendRow(
              icon: Icons.school,
              color: _schoolColor,
              label: trip.isMorning ? 'Last stop → school (morning drop-off)' : 'First stop → school (evening pickup)',
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < trip.tripStops.length; i++)
            Builder(builder: (context) {
              final ts = trip.tripStops[i];
              final n = counts[ts.stop?.publicId ?? ''] ?? 0;
              final timing = _formatTiming(ts, trip);

              return SrFadeIn(
                delay: Duration(milliseconds: 60 + (i < 8 ? i : 8) * 35),
                offset: 14,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: ts.status == TripStopStatus.departed
                          ? AppColors.green.withValues(alpha: 0.3)
                          : ts.status == TripStopStatus.arrived
                              ? AppColors.amber.withValues(alpha: 0.4)
                              : AppColors.border,
                      width: 1.2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _stopColor(trip, ts.sequence, ts.status),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${ts.sequence}',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ts.stop?.name ?? 'Stop ${ts.sequence}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (ts.stop?.address != null && ts.stop!.address.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        ts.stop!.address,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusPill(ts.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 14, color: AppColors.slate),
                                  const SizedBox(width: 5),
                                  Text(
                                    timing ?? 'Pending schedule',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: ts.departedAt != null ? FontWeight.w700 : FontWeight.w500,
                                      color: ts.departedAt != null ? AppColors.green : AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$n student${n == 1 ? '' : 's'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.brand),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final color = switch (status) {
      TripStopStatus.departed => const Color(0xFF059669),
      TripStopStatus.arrived => const Color(0xFFD97706),
      _ => const Color(0xFF64748B),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            TripStopStatus.label(status),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  String? _formatTiming(TripStop ts, Trip trip) {
    final parts = <String>[];
    if (ts.arrivedAt != null) {
      parts.add('Arrived ${DateFormat.jm().format(ts.arrivedAt!)}');
    }
    if (ts.departedAt != null) {
      parts.add('Departed ${DateFormat.jm().format(ts.departedAt!)}');
    }
    if (parts.isNotEmpty) return parts.join(' · ');
    final sched = trip.isMorning ? ts.stop?.pickupTime : ts.stop?.dropTime;
    if (sched != null && sched.isNotEmpty) {
      return 'Scheduled: $sched';
    }
    return null;
  }

  Color _stopColor(Trip trip, int sequence, String status) {
    if (status == TripStopStatus.departed) return AppColors.green;
    if (status == TripStopStatus.arrived) return AppColors.amber;
    final last = trip.tripStops.isEmpty ? 0 : trip.tripStops.map((e) => e.sequence).reduce((a, b) => a > b ? a : b);
    if (trip.isMorning && sequence == last) return _schoolColor;
    if (trip.isAfternoon && sequence == 1) return _schoolColor;
    return AppColors.brand;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w600, height: 1.3))),
          ],
        ),
      );
}

Map<String, int> studentsPerStopFromRoster(List<AttendanceRecord> roster) {
  final counts = <String, int>{};
  for (final r in roster) {
    final id = r.stop?.publicId;
    if (id == null) continue;
    if (r.status == AttendanceStatus.onLeave) continue;
    counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}
