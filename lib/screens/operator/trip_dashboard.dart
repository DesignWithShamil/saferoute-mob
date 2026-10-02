import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/utils/geo.dart';
import '../../models/student.dart';
import '../../models/transport.dart';
import '../../models/trip.dart';
import '../../providers/auth_controller.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_map.dart';
import 'attendance_roster.dart';
import 'qr_scan_screen.dart';
import 'trip_roster_screen.dart';
import 'trip_stops_screen.dart';
import 'trip_widgets.dart';

/// Today's trip for a Driver or Helper. Which controls appear follows the
/// backend permissions: start / start driving / cancel / end are driver-only
/// (TripViewSet._authorize_operator, IsDriver on /trips/start/); attendance,
/// drop verification, manual stop override and SOS are allowed for both.
class TripDashboard extends StatefulWidget {
  const TripDashboard({super.key});

  @override
  State<TripDashboard> createState() => _TripDashboardState();
}

class _TripDashboardState extends State<TripDashboard> with WidgetsBindingObserver {
  late final OperatorTripController _c = context.read<OperatorTripController>();
  late final AppServices _s = context.read<AppServices>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _s.deepLinks.operatorRefresh.addListener(_c.refresh);
    final user = context.read<AuthController>().user!;
    _c.attach(user);
    WidgetsBinding.instance.addPostFrameCallback((_) => _c.load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _s.deepLinks.operatorRefresh.removeListener(_c.refresh);
    _c.pausePolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Location keeps flowing from the foreground service; only the UI's own
    // polling pauses while the app isn't visible.
    if (state == AppLifecycleState.paused) _c.pausePolling();
    if (state == AppLifecycleState.resumed) _c.resumePolling();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    if (c.loading && c.routes.isEmpty && c.trip == null) return const LoadingView(label: 'Loading your trip…');
    if (c.loadError != null && c.routes.isEmpty && c.trip == null) {
      return ErrorView(message: c.loadError!, onRetry: c.load);
    }
    final trip = c.trip;
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _DateHeader(),
          if (c.loadError != null) _InlineError(message: c.loadError!),
          if (trip != null && trip.isActive)
            _ActiveTrip(trip: trip)
          else if (c.isDriver)
            const _StartTripPanel()
          else
            const _HelperIdlePanel(),
          if (c.todaysTrips.any((t) => t.isFinished)) _FinishedToday(trips: c.todaysTrips.where((t) => t.isFinished).toList()),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          DateFormat('EEEE, d MMMM y').format(DateTime.now()),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.slate),
        ),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(message, style: const TextStyle(color: AppColors.red)),
      );
}

// ---------------------------------------------------------------------------
// No active trip
// ---------------------------------------------------------------------------

class _RouteSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    if (c.routes.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        children: [
          for (final r in c.routes)
            ChoiceChip(
              label: Text(r.name),
              selected: r.publicId == c.selectedRoute?.publicId,
              onSelected: (_) => c.selectRoute(r.publicId),
            ),
        ],
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.route});
  final RouteInfo route;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.alt_route)),
        title: Text(route.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          if (route.bus != null) 'Bus ${route.bus!.busNumber}',
          '${route.stops.length} stops',
        ].join(' · ')),
      );
}

class _StartTripPanel extends StatelessWidget {
  const _StartTripPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final route = c.selectedRoute;
    if (route == null) {
      return const EmptyView(
        icon: Icons.alt_route,
        title: 'No route assigned yet',
        message: 'Contact your school admin to get assigned to a bus and route.',
      );
    }
    return SectionCard(
      title: 'Assigned route',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RouteSelector(),
          _RouteSummary(route: route),
          const SizedBox(height: 8),
          if (route.runsMorning) _StartButton(route: route, tripType: TripType.morning),
          if (route.runsMorning && route.runsAfternoon) const SizedBox(height: 12),
          if (route.runsAfternoon) _StartButton(route: route, tripType: TripType.afternoon),
        ],
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.route, required this.tripType});
  final RouteInfo route;
  final String tripType;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final finished = c.finishedTripFor(route.publicId, tripType);
    final isMorning = tripType == TripType.morning;
    final title = isMorning ? 'MORNING TRIP' : 'EVENING TRIP';
    final subtitle = isMorning ? 'Pickup route to school' : 'Drop-off route to home';

    if (finished != null) {
      final cancelled = finished.status == TripStatus.cancelled;
      return _TripButtonShell(
        color: AppColors.slate,
        icon: cancelled ? Icons.cancel_outlined : Icons.check_circle,
        title: cancelled ? '$title CANCELLED' : '$title COMPLETED',
        subtitle: finished.endedAt != null ? 'Ended ${DateFormat.jm().format(finished.endedAt!)}' : subtitle,
      );
    }

    return _TripButtonShell(
      color: AppColors.brand,
      icon: isMorning ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
      title: 'START $title',
      subtitle: subtitle,
      busy: c.acting,
      onTap: c.acting
          ? null
          : () async {
              final ok = await confirmDialog(
                context,
                title: 'Start ${TripType.label(tripType).toLowerCase()} trip?',
                message: '${route.name}${route.bus != null ? ' · Bus ${route.bus!.busNumber}' : ''}\n\n'
                    'Live location sharing starts now and continues in the background until the trip ends.',
                confirm: 'Start trip',
              );
              if (!ok || !context.mounted) return;
              final err = await c.startTrip(context, route, tripType);
              if (err != null && context.mounted) showSnack(context, err, error: true);
            },
    );
  }
}

class _TripButtonShell extends StatelessWidget {
  const _TripButtonShell({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.busy = false,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? color : color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              busy
                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Icon(icon, size: 28, color: enabled || busy ? Colors.white : color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800, color: enabled || busy ? Colors.white : color)),
                    Text(subtitle, style: TextStyle(color: enabled || busy ? Colors.white70 : color)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelperIdlePanel extends StatelessWidget {
  const _HelperIdlePanel();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final route = c.selectedRoute;
    if (route == null) {
      return const EmptyView(
        icon: Icons.alt_route,
        title: 'No route assigned yet',
        message: 'Contact your school admin to get assigned to a bus and route.',
      );
    }
    return SectionCard(
      title: 'Assigned route',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RouteSelector(),
          _RouteSummary(route: route),
          const SizedBox(height: 8),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.hourglass_empty),
            title: Text('No active trip'),
            subtitle: Text('The trip appears here as soon as the driver starts it.'),
          ),
        ],
      ),
    );
  }
}

class _FinishedToday extends StatelessWidget {
  const _FinishedToday({required this.trips});
  final List<Trip> trips;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Finished today',
        child: Column(
          children: [
            for (final t in trips)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${t.routeName} · ${TripType.label(t.tripType)}'),
                subtitle: Text([
                  if (t.startedAt != null) DateFormat.jm().format(t.startedAt!),
                  if (t.endedAt != null) DateFormat.jm().format(t.endedAt!),
                ].join(' – ')),
                trailing: StatusChip(label: TripStatus.label(t.status), color: AppColors.forStatus(t.status)),
              ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Active trip
// ---------------------------------------------------------------------------

class _ActiveTrip extends StatelessWidget {
  const _ActiveTrip({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final isDriver = c.isDriver;
    final busPosition = isDriver
        ? (c.gpsStatus.latitude != null ? LatLng(c.gpsStatus.latitude!, c.gpsStatus.longitude!) : null)
        : (c.busLocation != null ? LatLng(c.busLocation!.latitude, c.busLocation!.longitude) : null);
    final nextStop = trip.currentStop;
    final started = trip.status == TripStatus.started;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TripHeader(trip: trip),
              const SizedBox(height: 12),
              if (isDriver) const GpsStatusBanner(),
              if (!isDriver && c.busLocation != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Bus location updated ${formatAge(c.busLocation!.age)}',
                    style: TextStyle(color: c.busLocation!.isStale ? AppColors.amber : AppColors.slate),
                  ),
                ),
              if (trip.status != TripStatus.started) _UpcomingStopsBar(trip: trip, roster: c.roster, controller: c),
              TripMap(
                stops: mapStopsForTrip(
                  trip,
                  studentCounts: _studentsPerStop(c.roster),
                  studentsByStop: _studentsByStop(c.roster),
                ),
                places: [?schoolPlace(context.watch<AuthController>().school)],
                geometry: c.geometry,
                bus: busPosition,
                busIsStale: !isDriver && (c.busLocation?.isStale ?? false),
                busLabel: isDriver ? 'You are here' : 'Bus is here',
                busDetails: [
                  if (trip.bus != null) 'Bus ${trip.bus!.busNumber}',
                  if (isDriver && c.gpsStatus.lastSentAt != null)
                    'Last sent to server ${formatAge(DateTime.now().difference(c.gpsStatus.lastSentAt!))}',
                  if (!isDriver && c.busLocation != null) 'Updated ${formatAge(c.busLocation!.age)}',
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(value: c, child: const TripStopsScreen()),
                      )),
                      icon: const Icon(Icons.signpost_outlined, size: 20),
                      label: const Text('All stops'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(value: c, child: const TripRosterScreen()),
                      )),
                      icon: const Icon(Icons.groups_outlined, size: 20),
                      label: const Text('Full roster'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (started && trip.isAfternoon)
          SectionCard(
            title: 'Mark attendance (boarding at school)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AttendanceRosterView(roster: c.roster, showStats: true, groupByStop: false),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(value: c, child: const TripRosterScreen()),
                  )),
                  child: const Text('Open full roster'),
                ),
              ],
            ),
          )
        else if (nextStop != null)
          _NextStopCard(trip: trip, busPosition: busPosition)
        else
          SectionCard(
            title: 'All stops completed · Trip summary',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AttendanceRosterView(
                  roster: c.roster,
                  isAfternoon: trip.isAfternoon,
                  dropActions: true,
                  showStats: true,
                  groupByStop: true,
                  compactStats: true,
                  actionsInDetail: true,
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ChangeNotifierProvider.value(value: c, child: const TripRosterScreen()),
                  )),
                  child: const Text('View all students & actions'),
                ),
              ],
            ),
          ),
        _TripControls(trip: trip),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(value: c, child: const QrScanScreen()),
          )),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan student QR'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.amber,
            side: const BorderSide(color: AppColors.amber),
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: c.acting ? null : () => _showDelayDialog(context, c, trip),
          icon: const Icon(Icons.schedule),
          label: Text(
            trip.isMorning ? 'Send delay alert (not picked up)' : 'Send delay alert (not dropped)',
          ),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size.fromHeight(52)),
          onPressed: c.acting ? null : () => showSosFlow(context),
          icon: const Icon(Icons.sos),
          label: const Text('SOS – EMERGENCY', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  /// All rostered students per stop (for map badge — shows multi-student stops).
  static Map<String, int> _studentsPerStop(List<AttendanceRecord> roster) {
    final counts = <String, int>{};
    for (final r in roster) {
      final id = r.stop?.publicId;
      if (id == null) continue;
      if (r.status == AttendanceStatus.onLeave) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  static Map<String, List<String>> _studentsByStop(List<AttendanceRecord> roster) {
    final names = <String, List<String>>{};
    for (final r in roster) {
      final id = r.stop?.publicId;
      if (id == null) continue;
      names.putIfAbsent(id, () => []).add('${r.student.fullName} (${AttendanceStatus.label(r.status)})');
    }
    return names;
  }
}

class _UpcomingStopsBar extends StatelessWidget {
  const _UpcomingStopsBar({required this.trip, required this.roster, required this.controller});
  final Trip trip;
  final List<AttendanceRecord> roster;
  final OperatorTripController controller;

  @override
  Widget build(BuildContext context) {
    final counts = _ActiveTrip._studentsPerStop(roster);
    final upcoming = trip.tripStops.where((ts) => ts.status != TripStopStatus.departed).take(5).toList();
    if (upcoming.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Upcoming stops', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(value: controller, child: const TripStopsScreen()),
                )),
                child: const Text('See all'),
              ),
            ],
          ),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: upcoming.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final ts = upcoming[i];
                final name = ts.stop?.name ?? 'Stop ${ts.sequence}';
                final n = counts[ts.stop?.publicId ?? ''] ?? 0;
                final isNext = ts.stop?.publicId == trip.currentStop?.publicId;
                return Material(
                  color: isNext ? AppColors.amber.withValues(alpha: 0.15) : AppColors.slate.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(value: controller, child: const TripStopsScreen()),
                    )),
                    child: Container(
                      width: 132,
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isNext ? 'Next' : '#${ts.sequence}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isNext ? AppColors.amber : AppColors.slate),
                          ),
                          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.2)),
                          Text('$n child${n == 1 ? '' : 'ren'}', style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStopCard extends StatelessWidget {
  const _NextStopCard({required this.trip, required this.busPosition});
  final Trip trip;
  final LatLng? busPosition;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final stop = trip.currentStop!;
    final tripStop = trip.currentTripStop;
    String? distance;
    if (busPosition != null && stop.hasPosition) {
      final m = haversineMeters(busPosition!.latitude, busPosition!.longitude, stop.latitude!, stop.longitude!);
      final eta = etaMinutes(m, c.busLocation?.speedKmh);
      distance = '${formatDistance(m)} · ~${eta <= 1 ? '1 min' : '$eta min'}';
    }
    final n = c.rosterAtCurrentStop.length;
    return SectionCard(
      title: tripStop?.status == TripStopStatus.arrived ? 'At stop' : 'Next stop',
      trailing: Text(
        [if (n > 0) '$n student${n == 1 ? '' : 's'}', ?distance].whereType<String>().join(' · '),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(stop.name, style: Theme.of(context).textTheme.titleLarge),
          if (stop.address.isNotEmpty) Text(stop.address, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider.value(value: c, child: const TripRosterScreen()),
            )),
            icon: const Icon(Icons.groups_outlined),
            label: Text(n > 0 ? 'View $n student${n == 1 ? '' : 's'} at this stop' : 'Open student roster'),
          ),
        ],
      ),
    );
  }
}

class _TripControls extends StatelessWidget {
  const _TripControls({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    final isDriver = c.isDriver;

    Future<void> run(Future<String?> Function() action, {String? done}) async {
      final err = await action();
      if (!context.mounted) return;
      if (err != null) {
        showSnack(context, err, error: true);
      } else if (done != null) {
        showSnack(context, done);
      }
    }

    if (trip.status == TripStatus.started) {
      if (!isDriver) {
        return const SectionCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.hourglass_top),
            title: Text('Waiting for the driver to start driving'),
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: c.acting
                    ? null
                    : () async {
                        final ok = await confirmDialog(context,
                            title: 'Cancel this trip?',
                            message: 'The trip will be cancelled and cannot be restarted today.',
                            confirm: 'Cancel trip',
                            destructive: true);
                        if (ok) await run(() => c.cancelTrip('Driver cancelled before starting.'));
                      },
                child: const Text('BACK / CANCEL'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: c.acting ? null : () => run(c.beginDriving),
                child: c.acting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                    : const Text('START DRIVING', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
    }

    final nextStop = trip.currentStop;
    if (nextStop != null) {
      final arrived = trip.currentTripStop?.status == TripStopStatus.arrived;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.settings.enableAutoDetect)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.slate.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text(arrived ? 'Auto-detecting departure…' : 'Auto-detecting arrival…'),
                ],
              ),
            ),
          if (c.settings.allowManualStopOverride) ...[
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: c.acting ? null : () => run(c.advanceStop),
              child: Text(arrived ? 'Manual DEPART' : 'Manual ARRIVE', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      );
    }

    if (!isDriver) {
      return const SectionCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.flag_outlined),
          title: Text('All stops done'),
          subtitle: Text('The driver will end the trip.'),
        ),
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size.fromHeight(56)),
      onPressed: c.acting
          ? null
          : () async {
              final ok = await confirmDialog(context,
                  title: 'End this trip?', message: 'This cannot be undone.', confirm: 'End trip', destructive: true);
              if (ok) await run(c.endTrip, done: 'Trip completed.');
            },
      icon: const Icon(Icons.flag),
      label: const Text('END TRIP', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
    );
  }
}

Future<void> _showDelayDialog(BuildContext context, OperatorTripController c, Trip trip) async {
  final controller = TextEditingController();
  final sent = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Bus delay alert'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            trip.isMorning
                ? 'Parents of students not yet picked up will be notified.'
                : 'Parents of students not yet dropped will be notified.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Optional message',
              hintText: 'e.g. Traffic delay — about 15 minutes late.',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send alert')),
      ],
    ),
  );
  try {
    if (sent != true || !context.mounted) return;
    final err = await c.notifyDelay(controller.text.trim());
    if (!context.mounted) return;
    showSnack(context, err ?? 'Delay alert sent to waiting parents.', error: err != null);
  } finally {
    controller.dispose();
  }
}
