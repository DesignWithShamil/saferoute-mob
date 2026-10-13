import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/location/gps_tracking_service.dart';
import '../../core/utils/geo.dart';
import '../../models/trip.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/state_views.dart';

/// Header card: route, bus, trip type and backend status.
class TripHeader extends StatelessWidget {
  const TripHeader({super.key, required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.routeName.isEmpty ? 'Route' : trip.routeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
              ),
              const SizedBox(height: 3),
              Text(
                '${trip.bus?.busNumber ?? 'Bus'} · ${TripType.label(trip.tripType)} trip'
                '${trip.startedAt != null ? ' · started ${DateFormat.jm().format(trip.startedAt!)}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.slate, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        StatusChip(label: TripStatus.label(trip.status), color: AppColors.forStatus(trip.status)),
      ],
    );
  }
}

/// Live-location status for the driver, fed by the GPS foreground service.
class GpsStatusBanner extends StatelessWidget {
  const GpsStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    if (!c.settings.gpsTrackingEnabled) {
      return const _Banner(
        icon: Icons.location_disabled,
        color: AppColors.slate,
        text: 'Live GPS tracking is turned off for your school.',
      );
    }
    if (c.locationAccessMissing) {
      return _Banner(
        icon: Icons.location_off,
        color: AppColors.red,
        text: 'Location is off or not permitted, so the bus position is not being shared.',
        action: TextButton(onPressed: () => c.requestLocationAndTrack(context), child: const Text('ENABLE')),
      );
    }
    final s = c.gpsStatus;
    final (IconData icon, String text) = switch (s.state) {
      GpsState.active => (Icons.gps_fixed, 'Sharing live location'),
      GpsState.starting => (Icons.gps_not_fixed, 'Getting GPS fix…'),
      GpsState.weakSignal => (Icons.gps_not_fixed, 'Weak GPS signal – waiting for a better fix'),
      GpsState.offline => (Icons.cloud_off, 'No connection – locations are queued and will be sent'),
      GpsState.gpsOff => (Icons.location_off, 'Phone GPS is switched off'),
      GpsState.permissionDenied => (Icons.location_off, 'Location permission was revoked'),
      GpsState.error => (Icons.error_outline, 'Location update failed – retrying'),
      _ => (Icons.gps_off, 'Location sharing is not running'),
    };
    final details = [
      if (s.lastSentAt != null) 'last sent ${formatAge(DateTime.now().difference(s.lastSentAt!))}',
      if (s.accuracy != null) '±${s.accuracy!.round()} m',
      if (s.queued > 0) '${s.queued} queued',
    ].join(' · ');
    return _Banner(
      icon: icon,
      color: AppColors.forStatus(s.state),
      text: text,
      detail: s.message ?? (details.isEmpty ? null : details),
      action: s.state == GpsState.stopped || s.state == GpsState.permissionDenied || s.state == GpsState.gpsOff
          ? TextButton(onPressed: () => c.requestLocationAndTrack(context), child: const Text('RESTART'))
          : null,
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text, this.detail, this.action});
  final IconData icon;
  final Color color;
  final String text;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: EdgeInsets.fromLTRB(12, 10, action == null ? 14 : 6, 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14, height: 1.3)),
                    if (detail != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(detail!, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                      ),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 4), action!],
            ],
          ),
        ),
      );
}

/// Vertical list of the trip's stops in backend order.
class StopTimeline extends StatelessWidget {
  const StopTimeline({super.key, required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final currentId = trip.currentStop?.publicId;
    return Column(
      children: [
        for (final ts in trip.tripStops)
          Builder(builder: (context) {
            final isCurrent = ts.stop?.publicId == currentId;
            final dotColor = isCurrent
                ? AppColors.amber
                : ts.status == TripStopStatus.departed
                    ? AppColors.green
                    : AppColors.slate.withValues(alpha: 0.25);
            final sub = [
              if (ts.arrivedAt != null) 'Arrived ${DateFormat.jm().format(ts.arrivedAt!)}',
              if (ts.departedAt != null) 'Departed ${DateFormat.jm().format(ts.departedAt!)}',
            ].join(' · ');
            return Container(
              constraints: const BoxConstraints(minHeight: 48),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.amber.withValues(alpha: 0.10) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                    child: Text('${ts.sequence}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ts.stop?.name ?? 'Stop',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                        ),
                        if (sub.isNotEmpty)
                          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(label: ts.status, color: AppColors.forStatus(ts.status)),
                ],
              ),
            );
          }),
      ],
    );
  }
}
