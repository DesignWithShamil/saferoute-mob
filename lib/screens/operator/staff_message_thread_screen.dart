import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/staff_message.dart';
import '../../widgets/state_views.dart';

/// View-only inbox: announcements from school admin (drivers/helpers cannot reply).
class StaffMessageThreadScreen extends StatefulWidget {
  const StaffMessageThreadScreen({super.key, required this.conversationId, this.readOnly = true});

  final String conversationId;
  final bool readOnly;

  @override
  State<StaffMessageThreadScreen> createState() => _StaffMessageThreadScreenState();
}

class _StaffMessageThreadScreenState extends State<StaffMessageThreadScreen> {
  final _scroll = ScrollController();
  List<StaffMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _clearing = false;

  String _targetType = 'ALL';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  static const _targetOptions = <String, String>{
    'ALL': 'All types',
    'ALL_DRIVERS': 'All drivers',
    'ALL_HELPERS': 'All helpers',
    'BUS': 'Bus(es)',
    'ROUTE': 'Route(s)',
    'BUS_STAFF': 'Bus(es)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String? _formatDate(DateTime? d) => d == null ? null : DateFormat('yyyy-MM-dd').format(d);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await context.read<AppServices>().messaging.listAllMessages(
            widget.conversationId,
            targetType: _targetType,
            dateFrom: _formatDate(_dateFrom),
            dateTo: _formatDate(_dateTo),
          );
      if (mounted) setState(() => _messages = rows);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToEnd();
    }
  }

  void _clearFilters() {
    setState(() {
      _targetType = 'ALL';
      _dateFrom = null;
      _dateTo = null;
    });
    _load();
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? (_dateFrom ?? DateTime.now()) : (_dateTo ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
    _load();
  }

  Future<void> _clearInbox() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear inbox?'),
        content: const Text('Remove all announcements from your inbox. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await context.read<AppServices>().messaging.clearInbox(widget.conversationId);
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AnnouncementsHeader(readOnly: widget.readOnly, clearing: _clearing, onClearInbox: _clearInbox),
        _FilterBar(
          targetType: _targetType,
          targetOptions: _targetOptions,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
          onTargetChanged: (v) {
            setState(() => _targetType = v);
            _load();
          },
          onPickFrom: () => _pickDate(from: true),
          onPickTo: () => _pickDate(from: false),
          onClearFilters: _clearFilters,
        ),
        Expanded(
          child: ColoredBox(
            color: AppColors.slate.withValues(alpha: 0.04),
            child: _loading
                ? const LoadingView(label: 'Loading announcements…')
                : _error != null
                    ? ErrorView(message: _error!, onRetry: _load)
                    : _messages.isEmpty
                        ? _EmptyAnnouncements(onRefresh: _load)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              controller: _scroll,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                              itemCount: _messages.length + 1,
                              itemBuilder: (context, i) {
                                if (i == 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Text(
                                      '${_messages.length} message${_messages.length == 1 ? '' : 's'}',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.6,
                                            color: AppColors.slate,
                                          ),
                                    ),
                                  );
                                }
                                return _AnnouncementCard(message: _messages[i - 1]);
                              },
                            ),
                          ),
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.targetType,
    required this.targetOptions,
    required this.dateFrom,
    required this.dateTo,
    required this.onTargetChanged,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearFilters,
  });

  final String targetType;
  final Map<String, String> targetOptions;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<String> onTargetChanged;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final df = dateFrom != null ? DateFormat('d MMM y').format(dateFrom!) : 'From date';
    final dt = dateTo != null ? DateFormat('d MMM y').format(dateTo!) : 'To date';
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 160,
              child: DropdownButtonFormField<String>(
                initialValue: targetType,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                items: targetOptions.entries
                    .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onTargetChanged(v);
                },
              ),
            ),
            OutlinedButton.icon(onPressed: onPickFrom, icon: const Icon(Icons.calendar_today, size: 16), label: Text(df, style: const TextStyle(fontSize: 12))),
            OutlinedButton.icon(onPressed: onPickTo, icon: const Icon(Icons.calendar_today, size: 16), label: Text(dt, style: const TextStyle(fontSize: 12))),
            TextButton(onPressed: onClearFilters, child: const Text('Clear filters')),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementsHeader extends StatelessWidget {
  const _AnnouncementsHeader({required this.readOnly, required this.clearing, required this.onClearInbox});
  final bool readOnly;
  final bool clearing;
  final VoidCallback onClearInbox;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brand, Color(0xFF1D4ED8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('School announcements', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                if (readOnly)
                  Text(
                    'Read only — no replies',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: clearing ? null : onClearInbox,
            style: TextButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: 0.5))),
            child: Text(clearing ? '…' : 'Clear inbox'),
          ),
        ],
      ),
    );
  }
}

class _EmptyAnnouncements extends StatelessWidget {
  const _EmptyAnnouncements({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          Icon(Icons.mark_email_unread_outlined, size: 72, color: AppColors.slate.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          Text(
            'No announcements yet',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Try clearing filters or check back when your school admin sends a message.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.slate, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.message});
  final StaffMessage message;

  @override
  Widget build(BuildContext context) {
    final time = message.createdAt != null ? DateFormat('d MMM y · h:mm a').format(message.createdAt!) : '';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate.withValues(alpha: 0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.brand.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.notifications_active_outlined, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.sender?.fullName ?? 'School admin', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand)),
                if (message.audienceLabel != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.slate.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: Text(message.audienceLabel!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate)),
                  ),
                ],
                const SizedBox(height: 8),
                Text(message.body, style: const TextStyle(color: AppColors.slate, height: 1.45, fontSize: 15)),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(time, style: TextStyle(fontSize: 11, color: AppColors.slate.withValues(alpha: 0.65))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
