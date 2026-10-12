import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../providers/auth_controller.dart';
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

class ShellDrawerItem {
  const ShellDrawerItem({
    required this.label,
    required this.icon,
    this.tabIndex,
    this.badgeCount,
    this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final IconData icon;
  final int? tabIndex;
  final int? badgeCount;
  final VoidCallback? onTap;
  final bool isDestructive;
}

/// Bottom-navigation scaffold shared by the role homes. On first build it
/// runs the post-sign-in notification setup (permission + FCM token).
class SignedInShell extends StatefulWidget {
  const SignedInShell({
    super.key,
    required this.tabs,
    this.drawerItems = const [],
    this.alertsTabIndex,
    this.scrollableNavigation = false,
  });

  final List<ShellTab> tabs;
  final List<ShellDrawerItem> drawerItems;
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
      drawer: widget.drawerItems.isNotEmpty ? _buildDrawer(context, unread) : null,
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

  Widget _buildDrawer(BuildContext context, int unreadCount) {
    final auth = context.watch<AuthController>();
    final user = auth.user;
    final school = auth.school;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    String roleDisplay = 'User';
    if (user != null) {
      if (user.isDriver) {
        roleDisplay = 'Driver';
      } else if (user.isHelper) {
        roleDisplay = 'Helper';
      } else if (user.isParent) {
        roleDisplay = 'Parent';
      } else {
        roleDisplay = user.role.replaceAll('_', ' ');
      }
    }

    final initial = (user?.fullName.isNotEmpty == true)
        ? user!.fullName.characters.first.toUpperCase()
        : '?';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: scheme.primaryContainer,
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName ?? 'SafeRoute',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleDisplay,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        if (school != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            school.name,
                            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final item in widget.drawerItems)
                    _buildDrawerTile(context, item, unreadCount),
                ],
              ),
            ),

            // Logout & footer
            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(context).pop();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await auth.logout();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 4),
              child: Text(
                'SafeRoute © ${DateTime.now().year}',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile(BuildContext context, ShellDrawerItem item, int unreadCount) {
    final isSelected = item.tabIndex != null && item.tabIndex == _index;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget? badge;
    final effectiveBadge = item.badgeCount ?? (item.label.toLowerCase().contains('alert') ? unreadCount : null);
    if (effectiveBadge != null && effectiveBadge > 0) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          '$effectiveBadge',
          style: TextStyle(color: scheme.onError, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
    }

    return ListTile(
      selected: isSelected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: Icon(
        item.icon,
        color: isSelected ? scheme.primary : (item.isDestructive ? scheme.error : scheme.onSurfaceVariant),
      ),
      title: Text(
        item.label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? scheme.primary : (item.isDestructive ? scheme.error : null),
        ),
      ),
      trailing: badge,
      onTap: () {
        Navigator.of(context).pop();
        if (item.tabIndex != null) {
          _selectTab(item.tabIndex!);
        } else if (item.onTap != null) {
          item.onTap!();
        }
      },
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
