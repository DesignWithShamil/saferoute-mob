import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../providers/auth_controller.dart';
import '../../providers/notifications_controller.dart';
import '../../widgets/state_views.dart';
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

  /// Kept for API compatibility. The bottom bar now always shows only the
  /// main tabs; everything else lives in the drawer behind the "More" button.
  final bool scrollableNavigation;

  @override
  State<SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<SignedInShell> {
  int _index = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
      key: _scaffoldKey,
      extendBody: false,
      appBar: AppBar(
        title: Text(tab.title ?? tab.label),
        actions: [
          ...tab.actions,
          if (_index == widget.alertsTabIndex) const ClearAllNotificationsButton(),
          if (_index == widget.alertsTabIndex) const MarkAllReadButton(),
          const SizedBox(width: 4),
        ],
      ),
      drawer: widget.drawerItems.isNotEmpty ? _buildDrawer(context, unread) : null,
      body: IndexedStack(
        index: _index,
        sizing: StackFit.expand,
        children: [for (final t in widget.tabs) SizedBox.expand(child: t.body)],
      ),
      // Only the 4 main destinations live in the bottom bar. Everything else
      // (history, alerts, SOS, profile …) sits behind the centre "More" button.
      bottomNavigationBar: _FloatingNavBar(
        tabs: widget.tabs,
        selectedIndex: _index,
        alertsTabIndex: widget.alertsTabIndex,
        unread: unread,
        onSelected: _selectTab,
        onMore: widget.drawerItems.isEmpty ? null : () => _scaffoldKey.currentState?.openDrawer(),
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

    final mainItems = widget.drawerItems.where((i) => i.tabIndex != null).toList();
    final moreItems = widget.drawerItems.where((i) => i.tabIndex == null).toList();

    return Drawer(
      width: 308,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 24, 20, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.ink, Color(0xFF1B2A6B), AppColors.brand],
                ),
                borderRadius: BorderRadius.only(bottomRight: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    user?.fullName ?? 'SafeRoute',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          roleDisplay.toUpperCase(),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white),
                        ),
                      ),
                      if (school != null)
                        Text(
                          school.name,
                          style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.82)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Navigation items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                children: [
                  if (mainItems.isNotEmpty) _drawerSectionLabel(context, 'MAIN'),
                  for (final item in mainItems) _buildDrawerTile(context, item, unreadCount),
                  if (moreItems.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _drawerSectionLabel(context, 'MORE'),
                    for (final item in moreItems) _buildDrawerTile(context, item, unreadCount),
                  ],
                ],
              ),
            ),

            // Logout & footer
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              child: Material(
                color: AppColors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
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
                            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
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
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, color: AppColors.red, size: 22),
                        SizedBox(width: 14),
                        Text('Log out', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10, top: 2),
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

  Widget _drawerSectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.slate),
        ),
      );

  Widget _buildDrawerTile(BuildContext context, ShellDrawerItem item, int unreadCount) {
    final isSelected = item.tabIndex != null && item.tabIndex == _index;
    final scheme = Theme.of(context).colorScheme;

    Widget? badge;
    final effectiveBadge = item.badgeCount ?? (item.label.toLowerCase().contains('alert') ? unreadCount : null);
    if (effectiveBadge != null && effectiveBadge > 0) {
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
        child: Text(
          '$effectiveBadge',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      );
    }

    final Color fg = isSelected ? Colors.white : (item.isDestructive ? AppColors.red : AppColors.ink);
    final Color iconBg = isSelected
        ? Colors.white.withValues(alpha: 0.18)
        : (item.isDestructive ? AppColors.red.withValues(alpha: 0.10) : scheme.primary.withValues(alpha: 0.08));
    final Color iconFg = isSelected ? Colors.white : (item.isDestructive ? AppColors.red : scheme.primary);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isSelected ? scheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).pop();
            if (item.tabIndex != null) {
              _selectTab(item.tabIndex!);
            } else if (item.onTap != null) {
              item.onTap!();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(item.icon, size: 21, color: iconFg),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: fg),
                  ),
                ),
                if (badge != null) badge,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(int i) {
    setState(() => _index = i);
    if (i == widget.alertsTabIndex) context.read<NotificationsController>().load();
  }
}

/// Floating dark pill with the 4 main destinations split around a raised
/// centre "More" button that opens the side drawer.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.onMore,
    this.alertsTabIndex,
    this.unread = 0,
  });

  final List<ShellTab> tabs;
  final int selectedIndex;
  final int? alertsTabIndex;
  final int unread;
  final ValueChanged<int> onSelected;
  final VoidCallback? onMore;

  static const double _pillHeight = 68;
  static const double _orb = 60;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final hasOrb = onMore != null;
    final half = (tabs.length / 2).ceil();
    final left = [for (var i = 0; i < half; i++) i];
    final right = [for (var i = half; i < tabs.length; i++) i];

    Widget item(int i) => Expanded(
          child: _NavItem(
            tab: tabs[i],
            selected: i == selectedIndex,
            badge: i == alertsTabIndex ? unread : 0,
            onTap: () => onSelected(i),
          ),
        );

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: SizedBox(
          height: _pillHeight + (hasOrb ? 16 : 0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _pillHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(color: AppColors.ink.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        for (final i in left) item(i),
                        if (hasOrb) const SizedBox(width: _orb + 14),
                        for (final i in right) item(i),
                      ],
                    ),
                  ),
                ),
              ),
              if (hasOrb)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'More',
                      child: GestureDetector(
                        onTap: onMore,
                        child: Container(
                          width: _orb + 8,
                          height: _orb + 8,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                center: Alignment(-0.35, -0.45),
                                radius: 1.0,
                                colors: [Color(0xFF8FB0FF), AppColors.brand, Color(0xFF1536B8)],
                                stops: [0.0, 0.55, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(color: AppColors.brand.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Center(
                              child: unread > 0
                                  ? Badge(
                                      label: Text('$unread'),
                                      backgroundColor: AppColors.red,
                                      child: const Icon(Icons.apps_rounded, color: Colors.white, size: 28),
                                    )
                                  : const Icon(Icons.apps_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.tab, required this.selected, required this.badge, required this.onTap});
  final ShellTab tab;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : Colors.white.withValues(alpha: 0.55);
    Widget icon = Icon(tab.icon, size: 23, color: color);
    if (badge > 0) {
      icon = Badge(label: Text('$badge'), backgroundColor: AppColors.red, child: icon);
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.white.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 3),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: color, letterSpacing: -0.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
