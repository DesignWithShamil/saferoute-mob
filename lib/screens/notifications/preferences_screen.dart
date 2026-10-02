import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../models/leave.dart';
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
                  children: [
                    for (final p in _items)
                      SwitchListTile(
                        title: Text(p.label),
                        value: p.enabled,
                        onChanged: p.type == 'EMERGENCY_ALERT'
                            ? null
                            : (v) => setState(() {
                                  _items = [for (final i in _items) i.type == p.type ? i.copyWith(enabled: v) : i];
                                }),
                        subtitle: p.type == 'EMERGENCY_ALERT' ? const Text('Always on') : null,
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save preferences')),
                    ),
                  ],
                ),
    );
  }
}
