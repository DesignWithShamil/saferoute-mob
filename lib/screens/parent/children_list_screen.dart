import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';
import 'add_child_screen.dart';
import 'child_detail_screen.dart';

/// React `/parent/profile` "My Children": every linked child, add, and details.
class ChildrenListScreen extends StatelessWidget {
  const ChildrenListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ParentController>();
    if (c.loading && c.children.isEmpty) return const LoadingView(label: 'Loading your children…');
    if (c.error != null && c.children.isEmpty) return ErrorView(message: c.error!, onRetry: c.load);

    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text('My children', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddChildScreen())),
                icon: const Icon(Icons.add),
                label: const Text('Add child'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _PickupPinCard(),
          const SizedBox(height: 16),
          if (c.children.isEmpty)
            const EmptyView(
              icon: Icons.family_restroom,
              title: 'No children linked yet',
              message: 'Add a child with the link code from their school.',
            )
          else
            for (final child in c.children)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(child: Text(child.student.fullName.characters.firstOrNull ?? '?')),
                  title: Text(child.label),
                  subtitle: Text([
                    if (child.student.classLabel.isNotEmpty) 'Class ${child.student.classLabel}',
                    child.student.pickupBus?.busNumber != null
                        ? 'Bus ${child.student.pickupBus!.busNumber}'
                        : 'No bus assigned',
                    if (child.relation.isNotEmpty) child.relation,
                  ].join(' · ')),
                  trailing: child.student.publicId == c.selectedChild?.student.publicId
                      ? const Icon(Icons.check_circle, color: AppColors.green)
                      : const Icon(Icons.chevron_right),
                  onTap: () async {
                    await c.selectChild(child.student.publicId);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ChildDetailScreen(studentId: child.student.publicId),
                    ));
                  },
                ),
              ),
        ],
      ),
    );
  }
}

/// Same mock pickup PIN as the React parent profile — there is no PIN API yet.
class _PickupPinCard extends StatefulWidget {
  const _PickupPinCard();

  @override
  State<_PickupPinCard> createState() => _PickupPinCardState();
}

class _PickupPinCardState extends State<_PickupPinCard> {
  static const _taken = {'1234', '1111', '0000', '9999', '4321'};
  final _pin = TextEditingController();
  String? _error;
  String? _tempPin;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _savePermanent() {
    final value = _pin.text.trim();
    if (value.length != 4) {
      setState(() => _error = 'Please enter a valid 4-digit PIN.');
      return;
    }
    if (_taken.contains(value)) {
      setState(() => _error = 'This PIN is already in use by another parent. Please choose a different one.');
      return;
    }
    setState(() => _error = null);
    showSnack(context, 'Permanent PIN updated successfully.');
  }

  void _generateTemp() {
    String next;
    do {
      next = (1000 + DateTime.now().microsecondsSinceEpoch % 9000).toString();
    } while (_taken.contains(next));
    setState(() => _tempPin = next);
  }

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Pickup security PIN',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Set a permanent PIN or generate a temporary one for today. This applies to all your children.'),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Permanent PIN', counterText: ''),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.red)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _savePermanent, child: const Text('Save PIN')),
            const SizedBox(height: 16),
            const Text('Temporary PIN', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_tempPin == null)
              OutlinedButton.icon(
                onPressed: _generateTemp,
                icon: const Icon(Icons.refresh),
                label: const Text('Auto-generate for today'),
              )
            else
              Row(
                children: [
                  Text(_tempPin!, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(width: 12),
                  const StatusChip(label: 'Active today', color: AppColors.green),
                ],
              ),
          ],
        ),
      );
}
