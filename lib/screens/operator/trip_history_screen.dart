import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/trip.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';
import 'trip_history_detail_screen.dart';

/// React `/driver/history` and `/helper/history`.
class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Trip> _trips = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final trips = await context.read<AppServices>().trips.recent();
      trips.sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));
      if (mounted) setState(() => _trips = trips);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openTrip(Trip trip) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TripHistoryDetailScreen(trip: trip)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(label: 'Loading trip history…', skeleton: true);
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_trips.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 80),
          EmptyView(icon: Icons.history, title: 'No trips yet'),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _trips.length,
        itemBuilder: (context, i) {
          final t = _trips[i];
          final meta = [
            if (t.date != null) t.date!,
            if (t.bus != null) 'Bus ${t.bus!.busNumber}',
          ].join(' · ');
          final color = AppColors.forStatus(t.status);
          return SrFadeIn(
            delay: Duration(milliseconds: (i < 8 ? i : 8) * 40),
            offset: 14,
            child: Card(
              margin: const EdgeInsets.only(bottom: 12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _openTrip(t),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 68),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                          child: Icon(t.tripType == TripType.morning ? Icons.wb_sunny_outlined : Icons.directions_bus_rounded, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${t.routeName} · ${TripType.label(t.tripType)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2),
                              ),
                              if (meta.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.slate),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
