import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../models/leave.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';
import 'parent_widgets.dart';

/// React `/parent/leaves` for the selected child.
class ParentLeavesScreen extends StatefulWidget {
  const ParentLeavesScreen({super.key});

  @override
  State<ParentLeavesScreen> createState() => _ParentLeavesScreenState();
}

class _ParentLeavesScreenState extends State<ParentLeavesScreen> {
  late final ParentController _c = context.read<ParentController>();
  Future<List<LeaveRequest>>? _future;
  String? _studentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  void _reload() {
    final id = _c.selectedChild?.student.publicId;
    setState(() {
      _studentId = id;
      _future = id == null ? null : _c.leavesFor(id);
    });
  }

  Future<void> _openForm([LeaveRequest? existing]) async {
    final child = _c.selectedChild;
    if (child == null) return;
    if (!child.canApplyLeave && existing == null) {
      showSnack(context, 'You are not allowed to apply leave for this child.', error: true);
      return;
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _LeaveForm(childId: child.student.publicId, childLabel: child.label, existing: existing),
    ));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentController>();
    if (c.selectedChild?.student.publicId != _studentId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reload();
      });
    }
    final child = c.selectedChild;
    if (child == null) {
      return const EmptyView(icon: Icons.event_busy, title: 'Add a child to manage leaves');
    }
    return Column(
      children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: SelectedChildHeader()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: child.canApplyLeave ? () => _openForm() : null,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Apply leave'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<LeaveRequest>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingView(label: 'Loading leaves…', skeleton: true);
              if (snap.hasError) return ErrorView(message: describeError(snap.error!), onRetry: _reload);
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(children: const [
                    SizedBox(height: 80),
                    EmptyView(icon: Icons.event_available, title: 'No leaves found'),
                  ]),
                );
              }
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final leave = rows[i];
                    return SrFadeIn(
                      delay: Duration(milliseconds: 40 * (i > 8 ? 8 : i)),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: leave.isUpcoming ? () => _openForm(leave) : null,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.event_note_outlined, size: 22, color: AppColors.brand),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${leave.startDate} to ${leave.endDate}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          LeaveType.label(leave.leaveType),
                                          if (leave.reason.isNotEmpty) leave.reason,
                                        ].join(' · '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: AppColors.slate),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusChip(label: leave.status, color: AppColors.forStatus(leave.status)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LeaveForm extends StatefulWidget {
  const _LeaveForm({required this.childId, required this.childLabel, this.existing});
  final String childId;
  final String childLabel;
  final LeaveRequest? existing;

  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  late String _type = widget.existing?.leaveType ?? LeaveType.fullDay;
  late DateTime _start = DateTime.tryParse(widget.existing?.startDate ?? '') ?? DateTime.now();
  late DateTime _end = DateTime.tryParse(widget.existing?.endDate ?? '') ?? DateTime.now();
  late final _reason = TextEditingController(text: widget.existing?.reason ?? '');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = picked.isBefore(_start) ? _start : picked;
      }
    });
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final c = context.read<ParentController>();
      if (widget.existing == null) {
        await c.applyLeave(
          studentId: widget.childId,
          leaveType: _type,
          startDate: _ymd(_start),
          endDate: _ymd(_end),
          reason: _reason.text.trim(),
        );
      } else {
        await c.saveLeave(
          widget.existing!.publicId,
          studentId: widget.childId,
          leaveType: _type,
          startDate: _ymd(_start),
          endDate: _ymd(_end),
          reason: _reason.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this leave?',
      message: 'The leave will be removed.',
      confirm: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await context.read<ParentController>().cancelLeave(widget.existing!.publicId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  Widget _dateTile(String label, DateTime value, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
                      const SizedBox(height: 2),
                      Text(
                        _ymd(value),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, size: 20, color: AppColors.brand),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Apply leave' : 'Edit leave'),
        actions: [
          if (widget.existing != null)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete, tooltip: 'Remove'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Text(
            'For ${widget.childLabel}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Leave type'),
            items: const [
              DropdownMenuItem(value: LeaveType.fullDay, child: Text('Full day')),
              DropdownMenuItem(value: LeaveType.morning, child: Text('Morning only')),
              DropdownMenuItem(value: LeaveType.afternoon, child: Text('Afternoon only')),
            ],
            onChanged: (v) => setState(() => _type = v ?? LeaveType.fullDay),
          ),
          const SizedBox(height: 14),
          _dateTile('Start date', _start, () => _pick(true)),
          const SizedBox(height: 12),
          _dateTile('End date', _end, () => _pick(false)),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason (optional)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 14, color: AppColors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Submit leave')),
        ],
      ),
    );
  }
}
