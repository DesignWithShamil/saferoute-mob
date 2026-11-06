import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/leave.dart';
import '../../models/student.dart';
import '../../models/transport.dart';
import '../../providers/operator_trip_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';
import 'operator_student_detail_screen.dart';
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
    if (_loading) return const LoadingView(label: 'Loading students…', skeleton: true);
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final q = _query.text.trim().toLowerCase();
    final filtered = _students.where((s) {
      if (q.isNotEmpty) {
        final matchesName = s.fullName.toLowerCase().contains(q);
        final matchesAdm = s.admissionNumber.toLowerCase().contains(q);
        final matchesId = s.publicId.toLowerCase().contains(q);
        if (!matchesName && !matchesAdm && !matchesId) return false;
      }
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          SrFadeIn(
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Search student name, ID or scan QR',
                prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.slate),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_query.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _query.clear();
                          setState(() {
                            _lookup = null;
                            _lookupError = null;
                          });
                        },
                      ),
                    IconButton(icon: const Icon(Icons.search), onPressed: _lookupStudent),
                  ],
                ),
              ),
              onSubmitted: _lookupStudent,
            ),
          ),
          const SizedBox(height: 12),
          SrFadeIn(
            delay: const Duration(milliseconds: 60),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () async {
                      final token = await Navigator.of(context).push<String>(MaterialPageRoute(
                        builder: (_) => const QrCaptureScreen(title: 'Scan to look up student'),
                      ));
                      if (token != null && token.isNotEmpty && mounted) {
                        _query.text = token;
                        await _lookupStudent(token);
                      }
                    },
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Scan QR', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), padding: const EdgeInsets.symmetric(horizontal: 8)),
                    onPressed: () {
                      final c = context.read<OperatorTripController>();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(value: c, child: const QrScanScreen()),
                      ));
                    },
                    icon: const Icon(Icons.fact_check_outlined, size: 20),
                    label: const Text('Mark attendance', maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_lookupBusy)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5))),
                  ),
                if (_lookupError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: AppColors.red),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_lookupError!, style: const TextStyle(color: AppColors.red, fontSize: 14, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                if (_lookup != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _RosterRowCard(
                      accent: AppColors.green,
                      leading: const Icon(Icons.person_search_outlined, color: Colors.white, size: 22),
                      title: _lookup!.fullName,
                      lines: [
                        if (_lookup!.admissionNumber.isNotEmpty) _lookup!.admissionNumber,
                        if (_lookup!.morningBus != null) 'Morning ${_lookup!.morningBus} · ${_lookup!.morningStop ?? ''}',
                        if (_lookup!.afternoonBus != null) 'Evening ${_lookup!.afternoonBus} · ${_lookup!.afternoonStop ?? ''}',
                      ],
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => OperatorStudentDetailScreen(studentId: _lookup!.publicId),
                      )),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_routes.length > 1) ...[
            DropdownButtonFormField<String>(
              initialValue: _routeFilter,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Filter by route', prefixIcon: Icon(Icons.alt_route, color: AppColors.slate)),
              items: [
                const DropdownMenuItem(value: 'ALL', child: Text('All students', overflow: TextOverflow.ellipsis)),
                for (final r in _routes) DropdownMenuItem(value: r.publicId, child: Text(r.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _routeFilter = v ?? 'ALL'),
            ),
            const SizedBox(height: 16),
          ],
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '${filtered.length} student${filtered.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2),
            ),
          ),
          for (var i = 0; i < filtered.length; i++)
            SrFadeIn(
              delay: Duration(milliseconds: (i < 8 ? i : 8) * 40),
              offset: 14,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _RosterRowCard(
                  leading: Text(
                    (filtered[i].fullName.characters.firstOrNull ?? '?').toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  title: filtered[i].fullName,
                  lines: [
                    [
                      if (filtered[i].classLabel.isNotEmpty) 'Class ${filtered[i].classLabel}',
                      if (filtered[i].pickupBus != null) 'Bus ${filtered[i].pickupBus!.busNumber}',
                    ].join(' · '),
                    if (filtered[i].pickupStop != null) filtered[i].pickupStop!.name,
                  ].where((e) => e.isNotEmpty).toList(),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => OperatorStudentDetailScreen(studentId: filtered[i].publicId, initial: filtered[i]),
                  )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Clean tappable card row used for students and lookup results.
class _RosterRowCard extends StatelessWidget {
  const _RosterRowCard({
    required this.leading,
    required this.title,
    required this.lines,
    required this.onTap,
    this.accent = AppColors.brand,
  });
  final Widget leading;
  final String title;
  final List<String> lines;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(14)),
                    child: leading,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2),
                        ),
                        for (final l in lines)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.slate)),
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
      );
}
