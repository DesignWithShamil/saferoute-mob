import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/trip.dart';
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
    if (_loading) return const LoadingView(label: 'Loading trip history…');
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
        padding: const EdgeInsets.all(16),
        itemCount: _trips.length,
        itemBuilder: (context, i) {
          final t = _trips[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text('${t.routeName} · ${TripType.label(t.tripType)}'),
              subtitle: Text([
                if (t.date != null) t.date!,
                if (t.bus != null) 'Bus ${t.bus!.busNumber}',
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openTrip(t),
            ),
          );
        },
      ),
    );
  }
}
