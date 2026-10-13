import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/sr_animations.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'My children',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16)),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddChildScreen())),
                      icon: const Icon(Icons.add),
                      label: const Text('Add child'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const SrFadeIn(child: _PickupPinCard()),
                const SizedBox(height: 4),
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
                  ...c.children.asMap().entries.map((e) => SrFadeIn(
                        delay: Duration(milliseconds: 80 + 70 * (e.key > 6 ? 6 : e.key)),
                        child: _ChildSummaryCard(
                        link: e.value,
                        selected: e.value.student.publicId == c.selectedChild?.student.publicId,
                        onTap: () async {
                          await c.selectChild(e.value.student.publicId);
                          if (!context.mounted) return;
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ChildDetailScreen(studentId: e.value.student.publicId),
                          ));
                        },
                      ))),
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
    final meta = [
      if (s.classLabel.isNotEmpty) s.classLabel,
      if (s.admissionNumber.isNotEmpty) s.admissionNumber,
    ].join(' · ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: selected ? AppColors.brand.withValues(alpha: 0.5) : AppColors.border, width: selected ? 1.5 : 1),
      ),
      child: Material(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                      child: Text(
                        s.fullName.isEmpty ? '?' : s.fullName.characters.first.toUpperCase(),
                        style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w800, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.2),
                          ),
                          if (meta.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: AppColors.slate)),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              link.school.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.ink),
                            ),
                          ),
                          if (link.relation.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                link.relation.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.brand, letterSpacing: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Icon(
                        selected ? Icons.check_circle : Icons.chevron_right,
                        key: ValueKey(selected),
                        color: selected ? AppColors.green : AppColors.slate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (link.pickupRoute != null) _Tag(label: 'Morning · ${link.pickupRoute!.name}', color: AppColors.brand),
                    if (link.dropRoute != null) _Tag(label: 'Evening · ${link.dropRoute!.name}', color: AppColors.amber),
                    if (s.pickupBus != null) _Tag(label: 'Bus ${s.pickupBus!.busNumber}', color: AppColors.slate),
                    if (s.pickupStop != null) _Tag(label: s.pickupStop!.name, color: AppColors.slate),
                    StatusChip(label: s.status.isEmpty ? 'ACTIVE' : s.status, color: AppColors.green),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chip that ellipsizes long names instead of overflowing.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 92),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
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
          const Text(
            'Set a permanent PIN or generate a temporary one for today. This applies to all your children.',
            style: TextStyle(fontSize: 14, color: AppColors.slate, height: 1.4),
          ),
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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Permanent PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 4),
            const Text('Set a secure 4-digit code for everyday pickups.', style: TextStyle(fontSize: 12, color: AppColors.slate)),
            const SizedBox(height: 10),
            TextField(
              controller: _pin,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN', counterText: '', isDense: true),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topLeft,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                    ),
            ),
            const SizedBox(height: 10),
            FilledButton(onPressed: _savePermanent, child: const Text('Save')),
          ],
        ),
      );

  Widget _tempPinPanel() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Temporary PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.brand)),
            const SizedBox(height: 4),
            const Text('Valid for today only. Useful for one-time pickups.', style: TextStyle(fontSize: 12, color: AppColors.brand)),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _tempPin == null
                  ? OutlinedButton.icon(
                      key: const ValueKey('gen'),
                      onPressed: _generateTemp,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Auto-generate'),
                    )
                  : Wrap(
                      key: const ValueKey('pin'),
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Text(
                          _tempPin!,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.ink),
                        ),
                        const StatusChip(label: 'Active today', color: AppColors.green),
                      ],
                    ),
            ),
          ],
        ),
      );
}
