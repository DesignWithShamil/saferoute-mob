import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_exception.dart';
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
      return const LoadingView(label: 'Loading your children…', skeleton: true);
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
                if (c.children.isNotEmpty) ...[
                  SrFadeIn(child: _ChildrenPickupPinSection(children: c.children)),
                  const SizedBox(height: 14),
                ],
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
                                link.relation[0].toUpperCase() + link.relation.substring(1).toLowerCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brand),
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
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.onTint(color), fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      );
}

/// Per-child pickup security PIN section.
class _ChildrenPickupPinSection extends StatefulWidget {
  const _ChildrenPickupPinSection({required this.children});

  final List<ParentLink> children;

  @override
  State<_ChildrenPickupPinSection> createState() => _ChildrenPickupPinSectionState();
}

class _ChildrenPickupPinSectionState extends State<_ChildrenPickupPinSection> {
  String? _selectedStudentId;
  final _pinController = TextEditingController();
  String? _error;
  bool _savingPermanent = false;
  bool _generatingTemp = false;
  bool _cancellingTemp = false;

  @override
  void initState() {
    super.initState();
    _initSelection();
  }

  @override
  void didUpdateWidget(covariant _ChildrenPickupPinSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedStudentId == null ||
        !widget.children.any((c) => c.student.publicId == _selectedStudentId)) {
      _initSelection();
    } else {
      final selected = _currentLink;
      if (selected != null && _pinController.text.isEmpty && selected.pickupPin?.permanentPin != null) {
        _pinController.text = selected.pickupPin!.permanentPin!;
      }
    }
  }

  void _initSelection() {
    if (widget.children.isNotEmpty) {
      _selectedStudentId = widget.children.first.student.publicId;
      _pinController.text = widget.children.first.pickupPin?.permanentPin ?? '';
      _error = null;
    }
  }

  ParentLink? get _currentLink {
    for (final c in widget.children) {
      if (c.student.publicId == _selectedStudentId) return c;
    }
    return widget.children.firstOrNull;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _savePermanent(ParentLink link) async {
    final value = _pinController.text.trim();
    if (value.length != 4 || !RegExp(r'^\d{4}$').hasMatch(value)) {
      setState(() => _error = 'Please enter a valid 4-digit numeric PIN.');
      return;
    }
    setState(() {
      _error = null;
      _savingPermanent = true;
    });
    try {
      await context.read<ParentController>().setPermanentPin(link.student.publicId, value);
      if (mounted) showSnack(context, 'Permanent PIN saved for ${link.student.fullName}.');
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _savingPermanent = false);
    }
  }

  Future<void> _removePermanent(ParentLink link) async {
    setState(() {
      _error = null;
      _savingPermanent = true;
    });
    try {
      await context.read<ParentController>().removePermanentPin(link.student.publicId);
      _pinController.clear();
      if (mounted) showSnack(context, 'Permanent PIN removed for ${link.student.fullName}.');
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _savingPermanent = false);
    }
  }

  Future<void> _generateTemp(ParentLink link) async {
    setState(() => _generatingTemp = true);
    try {
      await context.read<ParentController>().generateTemporaryPin(link.student.publicId);
      if (mounted) showSnack(context, 'Temporary PIN generated for ${link.student.fullName}.');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed to generate PIN: ${describeError(e)}');
    } finally {
      if (mounted) setState(() => _generatingTemp = false);
    }
  }

  Future<void> _cancelTemp(ParentLink link) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel temporary PIN for ${link.student.fullName}?'),
        content: const Text('This will immediately deactivate this child’s temporary PIN for today.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel PIN'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _cancellingTemp = true);
    try {
      await context.read<ParentController>().cancelTemporaryPin(link.student.publicId);
      if (mounted) showSnack(context, 'Temporary PIN cancelled for ${link.student.fullName}.');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed to cancel PIN: ${describeError(e)}');
    } finally {
      if (mounted) setState(() => _cancellingTemp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = _currentLink;
    if (link == null) return const SizedBox.shrink();

    return SectionCard(
      title: 'Pickup security PIN',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create a separate Pickup Security PIN for each child. You can cancel temporary PINs individually.',
            style: TextStyle(fontSize: 14, color: AppColors.slate, height: 1.4),
          ),
          if (widget.children.length > 1) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.children.map((c) {
                  final isSelected = c.student.publicId == _selectedStudentId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(c.student.fullName),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedStudentId = c.student.publicId;
                          _pinController.text = c.pickupPin?.permanentPin ?? '';
                          _error = null;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth > 520;
              final permanent = _permanentPinPanel(link);
              final temp = _tempPinPanel(link);
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

  Widget _permanentPinPanel(ParentLink link) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.slate.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Permanent PIN · ${link.student.fullName}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (link.pickupPin?.hasPermanentPin == true)
                  const StatusChip(label: 'Set', color: AppColors.slate),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Set a secure 4-digit code for everyday pickups.', style: TextStyle(fontSize: 12, color: AppColors.slate)),
            const SizedBox(height: 10),
            TextField(
              controller: _pinController,
              maxLength: 4,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN', counterText: '', isDense: true),
              onChanged: (_) => setState(() {}),
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
            Row(
              children: [
                FilledButton(
                  onPressed: _savingPermanent ? null : () => _savePermanent(link),
                  child: Text(_savingPermanent ? 'Saving…' : 'Save'),
                ),
                if (link.pickupPin?.hasPermanentPin == true || _pinController.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _savingPermanent ? null : () => _removePermanent(link),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.red,
                      side: const BorderSide(color: AppColors.red),
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ],
            ),
          ],
        ),
      );

  Widget _tempPinPanel(ParentLink link) {
    final hasTemp = link.pickupPin?.hasTemporaryPin == true && link.pickupPin?.temporaryPin != null;
    final tempPin = link.pickupPin?.temporaryPin;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Temporary PIN · ${link.student.fullName}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.brand),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasTemp) const StatusChip(label: 'Active today', color: AppColors.green),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Valid for today only. Useful for one-time pickups.', style: TextStyle(fontSize: 12, color: AppColors.brand)),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: !hasTemp
                ? OutlinedButton.icon(
                    key: const ValueKey('gen'),
                    onPressed: _generatingTemp ? null : () => _generateTemp(link),
                    icon: _generatingTemp
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
                    label: Text(_generatingTemp ? 'Generating…' : 'Auto-generate'),
                  )
                : Column(
                    key: const ValueKey('pin'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tempPin ?? '',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 6, color: AppColors.ink),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _cancellingTemp ? null : () => _cancelTemp(link),
                        icon: _cancellingTemp
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cancel_outlined, size: 16),
                        label: Text(_cancellingTemp ? 'Cancelling…' : 'Cancel temporary PIN'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.red),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
