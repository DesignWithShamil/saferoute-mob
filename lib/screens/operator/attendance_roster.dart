import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/operator_trip_controller.dart';
import '../../utils/attendance_display.dart';
import '../../widgets/state_views.dart';
import 'student_detail_sheet.dart';

/// Mobile version of the web AttendanceRoster component, with the same
/// action rules: Board/Absent while not marked; on evening trips (when drop
/// actions are enabled) Drop, or Verify & Drop for PIN-protected students.
class AttendanceRosterView extends StatelessWidget {
  const AttendanceRosterView({
    super.key,
    required this.roster,
    this.isAfternoon = false,
    this.dropActions = false,
    this.groupByStop = true,
    this.showStats = true,
    this.compactStats = false,
    this.actionsInDetail = false,
  });

  final List<AttendanceRecord> roster;
  final bool isAfternoon;
  final bool dropActions;
  final bool groupByStop;
  final bool showStats;
  final bool compactStats;
  /// When true, Board/Absent/Drop appear in the student detail sheet instead of each row.
  final bool actionsInDetail;

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No students expected here.', textAlign: TextAlign.center),
      );
    }
    final groups = <String, List<AttendanceRecord>>{};
    for (final r in roster) {
      final key = groupByStop ? (r.stop?.publicId ?? r.stop?.name ?? 'No stop assigned') : '';
      groups.putIfAbsent(key, () => []).add(r);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showStats) _Counts(roster: roster, compact: compactStats),
        if (showStats) const SizedBox(height: 8),
        for (final entry in groups.entries) ...[
          if (groupByStop && entry.value.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.value.first.stop?.name ?? 'No stop assigned',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                    child: Text('${entry.value.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          for (final r in entry.value)
            _RosterRow(
              record: r,
              isAfternoon: isAfternoon,
              dropActions: dropActions,
              actionsInDetail: actionsInDetail,
            ),
        ],
      ],
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.roster, this.compact = false});
  final List<AttendanceRecord> roster;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    int count(bool Function(String) test) => roster.where((r) => test(r.status)).length;
    final boarded = count((s) => s == AttendanceStatus.boarded);
    final pending = count((s) => s == AttendanceStatus.notMarked);
    if (compact) {
      return Text(
        '${roster.length} students · $boarded boarded · $pending pending',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.slate),
      );
    }
    final items = [
      ('Total', roster.length, AppColors.slate),
      ('Boarded', boarded, AppColors.green),
      ('Dropped', count((s) => s == AttendanceStatus.dropped), AppColors.brand),
      ('Verified', count((s) => s == AttendanceStatus.dropVerified), AppColors.brand),
      ('Absent', count((s) => s == AttendanceStatus.absent), AppColors.red),
      ('Pending', pending, AppColors.amber),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (label, value, color) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text('$value $label', style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
          ),
      ],
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.record,
    required this.isAfternoon,
    required this.dropActions,
    this.actionsInDetail = false,
  });
  final AttendanceRecord record;
  final bool isAfternoon;
  final bool dropActions;
  final bool actionsInDetail;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<OperatorTripController>();
    final busy = context.select<OperatorTripController, bool>((c) => c.acting);
    final student = record.student;
    final needsPin = student.requiresDropVerification;

    Future<void> run(Future<String?> Function() action, String done) async {
      final err = await action();
      if (!context.mounted) return;
      showSnack(context, err ?? done, error: err != null);
    }

    final actions = <Widget>[];
    if (record.status == AttendanceStatus.notMarked) {
      actions.addAll([
        _SmallButton(
          label: 'Board',
          color: AppColors.green,
          onPressed: busy ? null : () => run(() => controller.markStudent(student.publicId, AttendanceStatus.boarded), '${student.fullName} boarded'),
        ),
        _SmallButton(
          label: 'Absent',
          color: AppColors.red,
          onPressed: busy ? null : () => run(() => controller.markStudent(student.publicId, AttendanceStatus.absent), '${student.fullName} marked absent'),
        ),
      ]);
    } else if (record.status == AttendanceStatus.boarded && isAfternoon && dropActions) {
      actions.add(needsPin
          ? _SmallButton(
              label: 'Verify & Drop',
              color: AppColors.brand,
              filled: true,
              onPressed: busy ? null : () => showDropPinDialog(context, record.student),
            )
          : _SmallButton(
              label: 'Drop',
              color: AppColors.green,
              onPressed: busy ? null : () => run(() => controller.markStudent(student.publicId, AttendanceStatus.dropped), '${student.fullName} dropped'),
            ));
    } else if (record.status == AttendanceStatus.dropped && isAfternoon && dropActions && needsPin) {
      actions.add(_SmallButton(
        label: 'Verify PIN',
        color: AppColors.brand,
        onPressed: busy ? null : () => showDropPinDialog(context, record.student),
      ));
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showStudentDetailSheet(context, student: student, record: record),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      [if (student.ageYears != null) '${student.ageYears} yrs', student.admissionNumber, student.classLabel]
                          .where((s) => s.isNotEmpty)
                          .join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (dropLocationHint(record) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          dropLocationHint(record)!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.brand),
                        ),
                      ),
                  ],
                ),
              ),
              StatusChip(label: AttendanceStatus.label(record.status), color: AppColors.forStatus(record.status)),
              if (!actionsInDetail && actions.isNotEmpty) ...[
                const SizedBox(width: 6),
                Wrap(spacing: 4, children: actions),
              ],
              const Icon(Icons.chevron_right, color: AppColors.slate, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.color, required this.onPressed, this.filled = false});
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
    );
    return filled
        ? FilledButton(
            style: style.copyWith(backgroundColor: WidgetStatePropertyAll(color)),
            onPressed: onPressed,
            child: Text(label),
          )
        : OutlinedButton(
            style: style.copyWith(foregroundColor: WidgetStatePropertyAll(color)),
            onPressed: onPressed,
            child: Text(label),
          );
  }
}

/// PIN entry for students whose drop requires verification (POST /attendance/verify-drop/).
Future<void> showDropPinDialog(BuildContext context, Student student) async {
  final controller = context.read<OperatorTripController>();
  await showDialog<void>(
    context: context,
    builder: (ctx) => _DropPinDialog(student: student, controller: controller),
  );
}

class _DropPinDialog extends StatefulWidget {
  const _DropPinDialog({required this.student, required this.controller});
  final Student student;
  final OperatorTripController controller;

  @override
  State<_DropPinDialog> createState() => _DropPinDialogState();
}

class _DropPinDialogState extends State<_DropPinDialog> {
  final _code = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.controller.verifyDrop(widget.student.publicId, _code.text.trim());
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
      showSnack(context, '${widget.student.fullName} drop verified');
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Verify drop: ${widget.student.fullName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ask the parent/guardian for the drop verification PIN.'),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontFamily: 'monospace'),
              decoration: InputDecoration(border: const OutlineInputBorder(), hintText: '----', errorText: _error),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Verifying…' : 'Verify & Drop')),
        ],
      );
}

/// Same flow as the web: confirm, optional description, POST /emergency/sos/.
Future<void> showSosFlow(BuildContext context) async {
  final controller = context.read<OperatorTripController>();
  final message = TextEditingController();
  final send = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 36),
      title: const Text('Send emergency alert?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('The school will be alerted immediately with your bus\'s last known location.'),
          const SizedBox(height: 12),
          TextField(
            controller: message,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Briefly describe the emergency (optional)',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.red),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('SEND SOS'),
        ),
      ],
    ),
  );
  final text = message.text.trim();
  message.dispose();
  if (send != true) return;
  final err = await controller.raiseSos(text);
  if (!context.mounted) return;
  showSnack(context, err ?? 'Emergency alert sent to the school.', error: err != null);
}
