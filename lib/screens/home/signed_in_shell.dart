import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../providers/notifications_controller.dart';
import '../notifications/notifications_screen.dart';

class ShellTab {
  const ShellTab({required this.label, required this.icon, required this.body, this.title, this.actions = const []});
  final String label;
  final IconData icon;
  final Widget body;
  final String? title;
  final List<Widget> actions;
}

/// Bottom-navigation scaffold shared by the role homes. On first build it
/// runs the post-sign-in notification setup (permission + FCM token).
class SignedInShell extends StatefulWidget {
  const SignedInShell({
    super.key,
    required this.tabs,
    this.alertsTabIndex,
    this.scrollableNavigation = false,
  });

  final List<ShellTab> tabs;
  final int? alertsTabIndex;

  /// When true (or when there are more than five tabs), use a horizontal
  /// scroll bar so labels match the web driver/helper nav without clipping.
  final bool scrollableNavigation;

  @override
  State<SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<SignedInShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final services = context.read<AppServices>();
      final notifications = context.read<NotificationsController>();
      await services.notificationService.onSignedIn(context);
      notifications.refreshUnread();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsController, int>((c) => c.unread);
    final tab = widget.tabs[_index];
    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        title: Text(tab.title ?? tab.label),
        actions: [
          ...tab.actions,
          if (_index == widget.alertsTabIndex) const ClearAllNotificationsButton(),
          if (_index == widget.alertsTabIndex) const MarkAllReadButton(),
        ],
      ),
      body: IndexedStack(
        index: _index,
        sizing: StackFit.expand,
        children: [for (final t in widget.tabs) SizedBox.expand(child: t.body)],
      ),
      bottomNavigationBar: widget.scrollableNavigation || widget.tabs.length > 5
          ? _ScrollableBottomNav(
              tabs: widget.tabs,
              selectedIndex: _index,
              alertsTabIndex: widget.alertsTabIndex,
              unread: unread,
              onSelected: _selectTab,
            )
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _selectTab,
              destinations: [
                for (var i = 0; i < widget.tabs.length; i++)
                  NavigationDestination(
                    icon: i == widget.alertsTabIndex && unread > 0
                        ? Badge(label: Text('$unread'), child: Icon(widget.tabs[i].icon))
                        : Icon(widget.tabs[i].icon),
                    label: widget.tabs[i].label,
                  ),
              ],
            ),
    );
  }

  void _selectTab(int i) {
    setState(() => _index = i);
    if (i == widget.alertsTabIndex) context.read<NotificationsController>().load();
  }
}

class _ScrollableBottomNav extends StatelessWidget {
  const _ScrollableBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    this.alertsTabIndex,
    this.unread = 0,
  });

  final List<ShellTab> tabs;
  final int selectedIndex;
  final int? alertsTabIndex;
  final int unread;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: tabs.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (context, i) {
              final selected = i == selectedIndex;
              final tab = tabs[i];
              final color = selected ? scheme.primary : scheme.onSurfaceVariant;
              Widget icon = Icon(tab.icon, size: 22, color: color);
              if (i == alertsTabIndex && unread > 0) {
                icon = Badge(label: Text('$unread'), child: icon);
              }
              return InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 76,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(height: 2),
                      Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: color),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
