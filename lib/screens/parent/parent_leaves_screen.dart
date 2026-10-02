import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../models/leave.dart';
import '../../providers/parent_controller.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: child.canApplyLeave ? () => _openForm() : null,
              icon: const Icon(Icons.add),
              label: const Text('Apply leave'),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<LeaveRequest>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingView(label: 'Loading leaves…');
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final leave = rows[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text('${leave.startDate} to ${leave.endDate}'),
                        subtitle: Text([
                          LeaveType.label(leave.leaveType),
                          if (leave.reason.isNotEmpty) leave.reason,
                        ].join(' · ')),
                        trailing: StatusChip(label: leave.status, color: AppColors.forStatus(leave.status)),
                        onTap: leave.isUpcoming ? () => _openForm(leave) : null,
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
        padding: const EdgeInsets.all(16),
        children: [
          Text('For ${widget.childLabel}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Leave type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: LeaveType.fullDay, child: Text('Full day')),
              DropdownMenuItem(value: LeaveType.morning, child: Text('Morning only')),
              DropdownMenuItem(value: LeaveType.afternoon, child: Text('Afternoon only')),
            ],
            onChanged: (v) => setState(() => _type = v ?? LeaveType.fullDay),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start date'),
            subtitle: Text(_ymd(_start)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pick(true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('End date'),
            subtitle: Text(_ymd(_end)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => _pick(false),
          ),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.red)),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Submit leave')),
        ],
      ),
    );
  }
}
