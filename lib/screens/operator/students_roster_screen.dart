import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/leave.dart';
import '../../models/student.dart';
import '../../models/transport.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/state_views.dart';
import 'qr_capture_screen.dart';
import 'qr_scan_screen.dart';

/// React `/driver/students` and `/helper/students` plus lookup.
class StudentsRosterScreen extends StatefulWidget {
  const StudentsRosterScreen({super.key});

  @override
  State<StudentsRosterScreen> createState() => _StudentsRosterScreenState();
}

class _StudentsRosterScreenState extends State<StudentsRosterScreen> {
  List<Student> _students = const [];
  List<RouteInfo> _routes = const [];
  String _routeFilter = 'ALL';
  bool _loading = true;
  String? _error;
  final _query = TextEditingController();
  StudentLookup? _lookup;
  String? _lookupError;
  bool _lookupBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = context.read<AppServices>();
      final results = await Future.wait([s.transport.assignedStudents(), s.trips.myRoutes()]);
      if (!mounted) return;
      setState(() {
        _students = results[0] as List<Student>;
        _routes = results[1] as List<RouteInfo>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lookupStudent([String? raw]) async {
    final q = (raw ?? _query.text).trim();
    if (q.isEmpty) return;
    setState(() {
      _lookupBusy = true;
      _lookupError = null;
      _lookup = null;
    });
    try {
      final found = await context.read<AppServices>().transport.lookupStudent(q);
      if (!mounted) return;
      setState(() {
        _lookup = found;
        if (found == null) _lookupError = 'Student not found.';
      });
    } catch (e) {
      if (mounted) setState(() => _lookupError = describeError(e));
    } finally {
      if (mounted) setState(() => _lookupBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(label: 'Loading students…');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final filtered = _students.where((s) {
      if (_routeFilter == 'ALL') return true;
      return s.pickupStop?.publicId == _routeFilter ||
          s.dropStop?.publicId == _routeFilter ||
          _routes.any((r) =>
              r.publicId == _routeFilter &&
              (r.stops.any((st) => st.publicId == s.pickupStop?.publicId) ||
                  r.stops.any((st) => st.publicId == s.dropStop?.publicId)));
    }).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _query,
            decoration: InputDecoration(
              labelText: 'Lookup by admission no. or QR',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _lookupStudent),
            ),
            onSubmitted: _lookupStudent,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final token = await Navigator.of(context).push<String>(MaterialPageRoute(
                      builder: (_) => const QrCaptureScreen(title: 'Scan to look up student'),
                    ));
                    if (token != null && token.isNotEmpty && mounted) {
                      _query.text = token;
                      await _lookupStudent(token);
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR to look up'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final c = context.read<OperatorTripController>();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(value: c, child: const QrScanScreen()),
                    ));
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Mark attendance'),
                ),
              ),
            ],
          ),
          if (_lookupBusy) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
          if (_lookupError != null) Text(_lookupError!, style: const TextStyle(color: AppColors.red)),
          if (_lookup != null)
            Card(
              child: ListTile(
                title: Text(_lookup!.fullName),
                subtitle: Text([
                  if (_lookup!.admissionNumber.isNotEmpty) _lookup!.admissionNumber,
                  if (_lookup!.morningBus != null) 'Morning ${_lookup!.morningBus} · ${_lookup!.morningStop ?? ''}',
                  if (_lookup!.afternoonBus != null) 'Evening ${_lookup!.afternoonBus} · ${_lookup!.afternoonStop ?? ''}',
                ].join('\n')),
                isThreeLine: true,
              ),
            ),
          const SizedBox(height: 12),
          if (_routes.length > 1)
            DropdownButtonFormField<String>(
              initialValue: _routeFilter,
              decoration: const InputDecoration(labelText: 'Filter by route', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('All students')),
                for (final r in _routes) DropdownMenuItem(value: r.publicId, child: Text(r.name)),
              ],
              onChanged: (v) => setState(() => _routeFilter = v ?? 'ALL'),
            ),
          const SizedBox(height: 8),
          Text('${filtered.length} students', style: Theme.of(context).textTheme.titleSmall),
          for (final s in filtered)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text(s.fullName.characters.firstOrNull ?? '?')),
              title: Text(s.fullName),
              subtitle: Text([
                if (s.classLabel.isNotEmpty) 'Class ${s.classLabel}',
                if (s.pickupBus != null) 'Bus ${s.pickupBus!.busNumber}',
                if (s.pickupStop != null) s.pickupStop!.name,
              ].join(' · ')),
            ),
        ],
      ),
    );
  }
}
