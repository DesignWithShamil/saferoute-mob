import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
import '../../models/student.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';

/// Add a child from any school to this parent account. The parent enters the
/// school code, the student number and the one-time link code from the
/// school; the backend verifies them, the parent confirms the child it found,
/// and only then is the link created.
class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  static const _relations = {'FATHER': 'Father', 'MOTHER': 'Mother', 'GUARDIAN': 'Guardian', 'OTHER': 'Other'};

  final _form = GlobalKey<FormState>();
  final _schoolCode = TextEditingController();
  final _studentNumber = TextEditingController();
  final _linkCode = TextEditingController();
  String _relation = 'GUARDIAN';
  ChildLinkPreview? _preview;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_schoolCode, _studentNumber, _linkCode]) {
      c.addListener(_clearPreview);
    }
  }

  @override
  void dispose() {
    _schoolCode.dispose();
    _studentNumber.dispose();
    _linkCode.dispose();
    super.dispose();
  }

  void _clearPreview() {
    if (_preview != null) setState(() => _preview = null);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final c = context.read<ParentController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_preview == null) {
        final preview = await c.previewLink(_schoolCode.text, _studentNumber.text, _linkCode.text, _relation);
        if (mounted) setState(() => _preview = preview);
      } else {
        final link = await c.confirmLink(_schoolCode.text, _studentNumber.text, _linkCode.text, _relation);
        if (!mounted) return;
        showSnack(context, '${link.label} added to your account');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _preview = null;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Add child')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Enter the school secret from your school, this child\'s admission number, and the one-time link code. '
              'Children from different schools can all be added to this account.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('add-child-school-code'),
              controller: _schoolCode,
              decoration: const InputDecoration(labelText: 'School secret', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('add-child-student-number'),
              controller: _studentNumber,
              decoration: const InputDecoration(labelText: 'Student number (admission no.)', border: OutlineInputBorder()),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('add-child-link-code'),
              controller: _linkCode,
              decoration: const InputDecoration(labelText: 'Link code', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              validator: _required,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _relation,
              decoration: const InputDecoration(labelText: 'You are the child\'s', border: OutlineInputBorder()),
              items: [
                for (final e in _relations.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _relation = v ?? 'GUARDIAN'),
            ),
            if (preview != null) ...[
              const SizedBox(height: 16),
              Card(
                color: AppColors.green.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Is this your child?', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(preview.fullName, style: Theme.of(context).textTheme.titleMedium),
                      Text([
                        if (preview.classLabel.isNotEmpty) 'Class ${preview.classLabel}',
                        if (preview.admissionNumber.isNotEmpty) preview.admissionNumber,
                      ].join(' · ')),
                      Text(preview.schoolName),
                      if (preview.alreadyLinked)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('This child is already on your account.', style: TextStyle(color: AppColors.amber)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.red)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('add-child-submit'),
              onPressed: _busy || (preview?.alreadyLinked ?? false) ? null : _submit,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(preview == null ? 'Verify' : 'Yes, add this child'),
            ),
          ],
        ),
      ),
    );
  }
}
