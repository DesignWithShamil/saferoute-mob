import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';
import 'add_child_screen.dart';
import 'child_detail_screen.dart';

/// React `/parent/profile` "My Children": web-style cards, PIN, full detail on tap.
class ChildrenListScreen extends StatefulWidget {
  const ChildrenListScreen({super.key});

  @override
  State<ChildrenListScreen> createState() => _ChildrenListScreenState();
}

class _ChildrenListScreenState extends State<ChildrenListScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ParentController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final c = context.watch<ParentController>();
    if (c.loading && c.children.isEmpty) {
      return const LoadingView(label: 'Loading your children…');
    }
    if (c.error != null && c.children.isEmpty) {
      return ErrorView(message: c.error!, onRetry: c.load);
    }

    return RefreshIndicator(
      onRefresh: c.load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Expanded(child: Text('My children', style: Theme.of(context).textTheme.titleLarge)),
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
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyView(
                      icon: Icons.family_restroom,
                      title: 'No children linked yet',
                      message: 'Add a child with the link code from their school.',
                    ),
                  )
                else
                  ...c.children.map((child) => _ChildSummaryCard(
                        link: child,
                        selected: child.student.publicId == c.selectedChild?.student.publicId,
                        onTap: () async {
                          await c.selectChild(child.student.publicId);
                          if (!context.mounted) return;
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChildDetailScreen(studentId: child.student.publicId),
                          ));
                        },
                      )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildSummaryCard extends StatelessWidget {
  const _ChildSummaryCard({required this.link, required this.selected, required this.onTap});

  final ParentLink link;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = link.student;
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.slate.withValues(alpha: 0.12))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                    child: Text(
                      s.fullName.isEmpty ? '?' : s.fullName.characters.first.toUpperCase(),
                      style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.fullName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text(
                          [
                            if (s.classLabel.isNotEmpty) s.classLabel,
                            if (s.admissionNumber.isNotEmpty) s.admissionNumber,
                          ].join(' · '),
                          style: const TextStyle(color: AppColors.slate),
                        ),
                        Text(link.school.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        if (link.relation.isNotEmpty)
                          Text(link.relation.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.brand)),
                      ],
                    ),
                  ),
                  Icon(selected ? Icons.check_circle : Icons.chevron_right, color: selected ? AppColors.green : AppColors.slate),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (link.pickupRoute != null)
                    StatusChip(label: 'Morning · ${link.pickupRoute!.name}', color: AppColors.brand),
                  if (link.dropRoute != null)
                    StatusChip(label: 'Evening · ${link.dropRoute!.name}', color: AppColors.amber),
                  if (s.pickupBus != null) StatusChip(label: 'Bus ${s.pickupBus!.busNumber}', color: AppColors.slate),
                  if (s.pickupStop != null) StatusChip(label: s.pickupStop!.name, color: AppColors.slate),
                  StatusChip(label: s.status.isEmpty ? 'ACTIVE' : s.status, color: AppColors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Web-style pickup PIN block (mock until PIN API exists).
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
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Pickup security PIN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Set a permanent PIN or generate a temporary one for today. This applies to all your children.'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 520;
              final permanent = _permanentPinPanel();
              final temp = _tempPinPanel();
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: permanent),
                    const SizedBox(width: 12),
                    Expanded(child: temp),
                  ],
                );
              }
              return Column(children: [permanent, const SizedBox(height: 12), temp]);
            },
          ),
        ],
      ),
    );
  }

  Widget _permanentPinPanel() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.slate.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Permanent PIN', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Set a secure 4-digit code for everyday pickups.', style: TextStyle(fontSize: 12, color: AppColors.slate)),
            const SizedBox(height: 10),
            TextField(
              controller: _pin,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN', counterText: '', isDense: true),
            ),
            if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _savePermanent, child: const Text('Save')),
          ],
        ),
      );

  Widget _tempPinPanel() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Temporary PIN', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand)),
            const SizedBox(height: 4),
            const Text('Valid for today only. Useful for one-time pickups.', style: TextStyle(fontSize: 12, color: AppColors.brand)),
            const SizedBox(height: 10),
            if (_tempPin == null)
              OutlinedButton.icon(onPressed: _generateTemp, icon: const Icon(Icons.refresh), label: const Text('Auto-generate'))
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
