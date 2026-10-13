import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../models/trip.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';
import 'trip_widgets.dart';

const _schoolColor = Color(0xFF7C3AED);

/// All route stops with student counts — opened from the trip map header.
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
          SrFadeIn(
            delay: const Duration(milliseconds: 60),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: StopTimeline(trip: trip),
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < trip.tripStops.length; i++)
            Builder(builder: (context) {
              final ts = trip.tripStops[i];
              final n = counts[ts.stop?.publicId ?? ''] ?? 0;
              return SrFadeIn(
                delay: Duration(milliseconds: 100 + (i < 8 ? i : 8) * 40),
                offset: 14,
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 64),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: _stopColor(trip, ts.sequence, ts.status), borderRadius: BorderRadius.circular(13)),
                            child: Text('${ts.sequence}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
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
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2),
                                ),
                                const SizedBox(height: 2),
                                Text(TripStopStatus.label(ts.status), style: const TextStyle(fontSize: 13, color: AppColors.slate)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              '$n student${n == 1 ? '' : 's'}',
                              maxLines: 1,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.brand),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _stopColor(Trip trip, int sequence, String status) {
    if (status == TripStopStatus.departed) return AppColors.green;
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
