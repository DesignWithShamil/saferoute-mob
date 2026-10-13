import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/leave.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';

/// React Notifications "Preferences" tab.
class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  List<NotificationPreference> _items = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await context.read<AppServices>().notifications.preferences();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.read<AppServices>().notifications.updatePreferences(_items);
      if (mounted) showSnack(context, 'Preferences saved');
    } catch (e) {
      if (mounted) showSnack(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alert preferences')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    for (var idx = 0; idx < _items.length; idx++)
                      SrFadeIn(
                        delay: Duration(milliseconds: 40 * (idx > 8 ? 8 : idx)),
                        offset: 12,
                        child: _PreferenceCard(
                          pref: _items[idx],
                          onChanged: _items[idx].type == 'EMERGENCY_ALERT'
                              ? null
                              : (v) => setState(() {
                                    final p = _items[idx];
                                    _items = [for (final i in _items) i.type == p.type ? i.copyWith(enabled: v) : i];
                                  }),
                        ),
                      ),
                    const SizedBox(height: 6),
                    FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save preferences')),
                  ],
                ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.pref, required this.onChanged});

  final NotificationPreference pref;
  final ValueChanged<bool>? onChanged;

  static IconData _iconFor(String type) {
    final t = type.toUpperCase();
    if (t.contains('EMERGENCY')) return Icons.emergency_outlined;
    if (t.contains('DELAY')) return Icons.schedule_outlined;
    if (t.contains('LEAVE')) return Icons.event_busy_outlined;
    if (t.contains('BOARD') || t.contains('PICKUP') || t.contains('DROP')) return Icons.directions_bus_outlined;
    if (t.contains('TRIP')) return Icons.route_outlined;
    return Icons.notifications_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final locked = pref.type == 'EMERGENCY_ALERT';
    final color = locked ? AppColors.red : AppColors.brand;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      constraints: const BoxConstraints(minHeight: 68),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pref.enabled ? color.withValues(alpha: 0.30) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(_iconFor(pref.type), size: 22, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pref.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                if (locked) ...[
                  const SizedBox(height: 2),
                  const Text('Always on', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                ],
              ],
            ),
          ),
          Switch(value: pref.enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}
