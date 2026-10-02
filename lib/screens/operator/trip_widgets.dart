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
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.routeName.isEmpty ? 'Route' : trip.routeName, style: theme.textTheme.titleLarge),
              Text(
                '${trip.bus?.busNumber ?? 'Bus'} · ${TripType.label(trip.tripType)} trip'
                '${trip.startedAt != null ? ' · started ${DateFormat.jm().format(trip.startedAt!)}' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
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
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                  if (detail != null) Text(detail!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            ?action,
          ],
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
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: ts.stop?.publicId == currentId
                  ? AppColors.amber
                  : ts.status == TripStopStatus.departed
                      ? AppColors.green
                      : AppColors.slate.withValues(alpha: 0.2),
              child: Text('${ts.sequence}', style: const TextStyle(fontSize: 12, color: Colors.white)),
            ),
            title: Text(ts.stop?.name ?? 'Stop'),
            subtitle: Text([
              if (ts.arrivedAt != null) 'Arrived ${DateFormat.jm().format(ts.arrivedAt!)}',
              if (ts.departedAt != null) 'Departed ${DateFormat.jm().format(ts.departedAt!)}',
            ].join(' · ')),
            trailing: StatusChip(label: ts.status, color: AppColors.forStatus(ts.status)),
          ),
      ],
    );
  }
}
