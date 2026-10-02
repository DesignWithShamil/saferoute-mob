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
      padding: const EdgeInsets.all(16),
      children: [
        if (c.routes.length > 1)
          DropdownButtonFormField<String>(
            initialValue: route.publicId,
            decoration: const InputDecoration(labelText: 'Route', border: OutlineInputBorder()),
            items: [for (final r in c.routes) DropdownMenuItem(value: r.publicId, child: Text(r.name))],
            onChanged: (v) => setState(() => _routeId = v),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(label: const Text('Morning'), selected: _morning, onSelected: (_) => setState(() => _morning = true)),
            ChoiceChip(label: const Text('Evening'), selected: !_morning, onSelected: (_) => setState(() => _morning = false)),
          ],
        ),
        const SizedBox(height: 12),
        Text('${route.name}${route.bus != null ? ' · Bus ${route.bus!.busNumber}' : ''}'),
        const SizedBox(height: 8),
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
                  title: Text('${s.sequence}. ${s.name}'),
                  subtitle: Text(_morning ? (s.pickupTime ?? '—') : (s.dropTime ?? '—')),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
