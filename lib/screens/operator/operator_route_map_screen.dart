import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/transport.dart';
import '../../models/trip.dart';
import '../../providers/auth_controller.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/state_views.dart';
import '../../widgets/trip_map.dart';

/// React `/driver/route`: assigned route map (morning/evening times).
class OperatorRouteMapScreen extends StatefulWidget {
  const OperatorRouteMapScreen({super.key});

  @override
  State<OperatorRouteMapScreen> createState() => _OperatorRouteMapScreenState();
}

class _OperatorRouteMapScreenState extends State<OperatorRouteMapScreen> {
  bool _morning = true;
  String? _routeId;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<OperatorTripController>();
    if (c.loading && c.routes.isEmpty) return const LoadingView(label: 'Loading routes…');
    if (c.routes.isEmpty) {
      return const EmptyView(icon: Icons.alt_route, title: 'No route assigned yet');
    }
    final route = c.routes.cast<RouteInfo?>().firstWhere(
          (r) => r!.publicId == (_routeId ?? c.selectedRoute?.publicId),
          orElse: () => c.routes.first,
        )!;
    final stops = [
      for (final s in route.stops)
        if (s.hasPosition)
          MapStop(
            position: LatLng(s.latitude!, s.longitude!),
            sequence: s.sequence,
            name: s.name,
            status: TripStopStatus.pending,
            details: [
              ?scheduledTimeLine(morning: _morning, pickupTime: s.pickupTime, dropTime: s.dropTime),
            ],
          ),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        if (c.routes.length > 1)
          DropdownButtonFormField<String>(
            initialValue: route.publicId,
            isExpanded: true,
            borderRadius: BorderRadius.circular(20),
            dropdownColor: Colors.white,
            elevation: 6,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.brand),
            decoration: const InputDecoration(labelText: 'Route', prefixIcon: Icon(Icons.alt_route_rounded)),
            selectedItemBuilder: (context) => [
              for (final r in c.routes)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
            items: [
              for (final r in c.routes)
                DropdownMenuItem(
                  value: r.publicId,
                  child: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
            ],
            onChanged: (v) => setState(() => _routeId = v),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                avatar: const Icon(Icons.wb_sunny_rounded, size: 18),
                label: const SizedBox(width: double.infinity, child: Text('Morning', textAlign: TextAlign.center)),
                selected: _morning,
                onSelected: (_) => setState(() => _morning = true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChoiceChip(
                avatar: const Icon(Icons.nights_stay_rounded, size: 18),
                label: const SizedBox(width: double.infinity, child: Text('Evening', textAlign: TextAlign.center)),
                selected: !_morning,
                onSelected: (_) => setState(() => _morning = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            '${route.name}${route.bus != null ? ' · Bus ${route.bus!.busNumber}' : ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.slate),
          ),
        ),
        TripMap(
          stops: stops,
          places: [?schoolPlace(context.watch<AuthController>().school)],
          followBusByDefault: false,
          heightFraction: 0.4,
        ),
        SectionCard(
          title: 'Stops',
          child: Column(
            children: [
              for (final s in route.stops)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 15,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                    foregroundColor: AppColors.brand,
                    child: Text('${s.sequence}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  title: Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_morning ? (s.pickupTime ?? '—') : (s.dropTime ?? '—')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
