import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../models/trip.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/state_views.dart';
import 'trip_widgets.dart';

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
        padding: const EdgeInsets.all(16),
        children: [
          if (trip.isMorning)
            const _LegendRow(icon: Icons.school, color: Color(0xFF7C3AED), label: 'Last stop → school (morning drop-off)')
          else
            const _LegendRow(icon: Icons.school, color: Color(0xFF7C3AED), label: 'First stop → school (evening pickup)'),
          const SizedBox(height: 12),
          StopTimeline(trip: trip),
          const SizedBox(height: 16),
          for (final ts in trip.tripStops) ...[
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _stopColor(trip, ts.sequence, ts.status),
                  child: Text('${ts.sequence}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                title: Text(ts.stop?.name ?? 'Stop ${ts.sequence}'),
                subtitle: Text(TripStopStatus.label(ts.status)),
                trailing: Text(
                  '${counts[ts.stop?.publicId ?? ''] ?? 0} students',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _stopColor(Trip trip, int sequence, String status) {
    if (status == TripStopStatus.departed) return AppColors.green;
    final last = trip.tripStops.isEmpty ? 0 : trip.tripStops.map((e) => e.sequence).reduce((a, b) => a > b ? a : b);
    if (trip.isMorning && sequence == last) return const Color(0xFF7C3AED);
    if (trip.isAfternoon && sequence == 1) return const Color(0xFF7C3AED);
    return AppColors.brand;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
        ],
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
