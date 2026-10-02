import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/trip.dart';
import '../../providers/operator_trip_controller.dart';
import 'attendance_roster.dart';

/// Full student roster for the active trip (by stop) — keeps the main trip page short.
class TripRosterScreen extends StatelessWidget {
  const TripRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final trip = c.trip;
    if (trip == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Students')),
        body: const Center(child: Text('No active trip')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(trip.isAfternoon ? 'Drop roster' : 'Pickup roster'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AttendanceRosterView(
            roster: c.roster,
            isAfternoon: trip.isAfternoon,
            dropActions: trip.isAfternoon,
            groupByStop: true,
            showStats: true,
            actionsInDetail: true,
          ),
        ],
      ),
    );
  }
}
