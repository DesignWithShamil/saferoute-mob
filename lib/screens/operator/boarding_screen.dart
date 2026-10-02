import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/operator_trip_controller.dart';
import '../../widgets/state_views.dart';
import 'attendance_roster.dart';
import 'qr_scan_screen.dart';

/// React `/driver/boarding` and `/helper/boarding`.
class BoardingScreen extends StatelessWidget {
  const BoardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final trip = c.trip;
    if (c.loading && trip == null) return const LoadingView(label: 'Loading roster…');
    if (trip == null || !trip.isActive) {
      return const EmptyView(
        icon: Icons.checklist,
        title: 'No active trip',
        message: 'Start a trip from the Trip tab to take attendance here.',
      );
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${trip.routeName} · ${trip.bus?.busNumber ?? ''}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(value: c, child: const QrScanScreen()),
            )),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan student QR'),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Mark attendance · full roster',
            child: AttendanceRosterView(
              roster: c.roster,
              isAfternoon: trip.isAfternoon,
              dropActions: true,
              compactStats: true,
            ),
          ),
        ],
      ),
    );
  }
}
