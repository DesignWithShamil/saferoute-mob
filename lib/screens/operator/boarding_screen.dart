import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/sr_animations.dart';
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
    final total = c.roster.length;
    final marked = c.roster.where((r) => r.status != AttendanceStatus.notMarked).length;
    final progress = total == 0 ? 0.0 : marked / total;
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          SrFadeIn(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandDeep, AppColors.brand],
                ),
                boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.routeName.isEmpty ? 'Route' : trip.routeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              trip.bus?.busNumber != null ? 'Bus ${trip.bus!.busNumber}' : 'Attendance',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$marked/$total',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('students marked', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                ],
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(value: c, child: const QrScanScreen()),
            )),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan student QR'),
          ),
          const SizedBox(height: 14),
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
