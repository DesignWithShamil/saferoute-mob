import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../providers/auth_controller.dart';
import '../../providers/notifications_controller.dart';
import '../../widgets/sr_animations.dart';
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
///
/// The bottom bar shows the main tabs around a floating centre button. That
/// button opens a bottom panel with every other option (history, alerts,
/// profile, SOS, log out …) – there is no side drawer any more.
class SignedInShell extends StatefulWidget {
  const SignedInShell({
    super.key,
    required this.tabs,
    this.drawerItems = const [],
    this.alertsTabIndex,
    this.scrollableNavigation = false,
    this.onSos,
  });

  final List<ShellTab> tabs;

  /// Items for the "More" panel. Entries that point at a tab are skipped
  /// because those tabs already live in the bottom bar.
  final List<ShellDrawerItem> drawerItems;
  final int? alertsTabIndex;

  /// When set, a red SOS shortcut is shown in the top bar (driver / helper).
  final VoidCallback? onSos;

  /// Kept for API compatibility.
  final bool scrollableNavigation;

  @override
  State<SignedInShell> createState() => _SignedInShellState();
}

class _SignedInShellState extends State<SignedInShell> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _index = 0;
  bool _moreOpen = false;
  Timer? _unreadTimer;
  late final AnimationController _pageAnim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 320), value: 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final services = context.read<AppServices>();
      final notifications = context.read<NotificationsController>();
      await services.notificationService.onSignedIn(context);
      notifications.refreshUnread();
    });
    _unreadTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted) context.read<NotificationsController>().refreshUnread();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<NotificationsController>().refreshUnread();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    _pageAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsController, int>((c) => c.unread);
    final tab = widget.tabs[_index];
    final fade = CurvedAnimation(parent: _pageAnim, curve: Curves.easeOutCubic);
    return Scaffold(
      extendBody: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.centerLeft,
            children: [...previous, ?current],
          ),
          child: Text(tab.title ?? tab.label, key: ValueKey(_index), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          ...tab.actions,
          if (_index == widget.alertsTabIndex) const ClearAllNotificationsButton(),
          if (_index == widget.alertsTabIndex) const MarkAllReadButton(),
          _BellButton(
            unread: unread,
            onTap: () async {
              HapticFeedback.selectionClick();
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
              if (context.mounted) {
                context.read<NotificationsController>().refreshUnread();
              }
            },
          ),
          if (widget.onSos != null) _SosChip(onTap: widget.onSos!),
          const SizedBox(width: 12),
        ],
      ),
      body: FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.015), end: Offset.zero).animate(fade),
          child: IndexedStack(
            index: _index,
            sizing: StackFit.expand,
            children: [for (final t in widget.tabs) SizedBox.expand(child: t.body)],
          ),
        ),
      ),
      bottomNavigationBar: _DockBar(
        tabs: widget.tabs,
        selectedIndex: _index,
        alertsTabIndex: widget.alertsTabIndex,
        unread: unread,
        moreOpen: _moreOpen,
        hasMore: widget.drawerItems.any((i) => i.tabIndex == null),
        onSelected: _selectTab,
        onMore: _openMore,
      ),
    );
  }

  void _selectTab(int i) {
    if (i != _index) {
      HapticFeedback.selectionClick();
      _pageAnim.forward(from: 0);
    }
    setState(() => _index = i);
    if (i == widget.alertsTabIndex) context.read<NotificationsController>().load();
  }

  Future<void> _openMore() async {
    if (_moreOpen) return;
    HapticFeedback.mediumImpact();
    setState(() => _moreOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.ink.withValues(alpha: 0.45),
      builder: (sheetContext) => _MoreSheet(
        items: widget.drawerItems.where((i) => i.tabIndex == null).toList(),
        onItem: (item) {
          Navigator.of(sheetContext).pop();
          item.onTap?.call();
        },
        onLogout: () async {
          Navigator.of(sheetContext).pop();
          final auth = context.read<AuthController>();
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
          if (confirm == true && mounted) await auth.logout();
        },
      ),
    );
    if (mounted) setState(() => _moreOpen = false);
  }
}

// ---------------------------------------------------------------------------
// Top bar bits
// ---------------------------------------------------------------------------

/// Bell with unread badge shown in the top bar of every tab.
class _BellButton extends StatelessWidget {
  const _BellButton({required this.unread, required this.onTap});
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget icon = const Icon(Icons.notifications_none_rounded, size: 26);
    if (unread > 0) {
      icon = Badge(
        label: Text(unread > 99 ? '99+' : '$unread'),
        backgroundColor: AppColors.red,
        child: const Icon(Icons.notifications_rounded, size: 26),
      );
    }
    return IconButton(tooltip: 'Notifications', icon: icon, onPressed: onTap);
  }
}

/// Always-visible emergency shortcut (driver / helper).
class _SosChip extends StatelessWidget {
  const _SosChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.red,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sos_rounded, color: Colors.white, size: 17),
                SizedBox(width: 4),
                Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12.5, letterSpacing: 0.4)),
              ],
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Bottom bar
// ---------------------------------------------------------------------------

/// Light floating bar: main tabs on both sides of a floating centre button.
/// A soft pill slides behind the active tab.
class _DockBar extends StatelessWidget {
  const _DockBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.onMore,
    required this.moreOpen,
    required this.hasMore,
    this.alertsTabIndex,
    this.unread = 0,
  });

  final List<ShellTab> tabs;
  final int selectedIndex;
  final int? alertsTabIndex;
  final int unread;
  final bool moreOpen;
  final bool hasMore;
  final ValueChanged<int> onSelected;
  final VoidCallback onMore;

  static const double _bar = 62;
  static const double _lift = 14;
  static const double _orb = 52;
  static const double _gap = 74;

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final half = (tabs.length / 2).ceil();
    final gap = hasMore ? _gap : 0.0;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: SizedBox(
          height: _bar + (hasMore ? _lift : 0),
          child: LayoutBuilder(
            builder: (context, box) {
              const pad = 6.0;
              final itemW = (box.maxWidth - pad * 2 - gap) / tabs.length;
              double xOf(int i) => pad + itemW * i + (i >= half ? gap : 0);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _bar,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(31),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 6)),
                        ],
                      ),
                    ),
                  ),
                  // Sliding highlight behind the active tab.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: xOf(selectedIndex) + 3,
                    bottom: 8,
                    width: itemW - 6,
                    height: _bar - 16,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _bar,
                    child: Material(
                      type: MaterialType.transparency,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: pad),
                        child: Row(
                          children: [
                            for (var i = 0; i < tabs.length; i++) ...[
                              if (i == half && hasMore) const SizedBox(width: _gap),
                              Expanded(
                                child: _DockItem(
                                  tab: tabs[i],
                                  selected: i == selectedIndex,
                                  badge: i == alertsTabIndex ? unread : 0,
                                  onTap: () => onSelected(i),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasMore)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _Orb(bg: bg, open: moreOpen, unread: unread, onTap: onMore),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Floating centre button that opens the "More" panel.
class _Orb extends StatelessWidget {
  const _Orb({required this.bg, required this.open, required this.unread, required this.onTap});
  final Color bg;
  final bool open;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, anim) => RotationTransition(
        turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: Icon(
        open ? Icons.close_rounded : Icons.apps_rounded,
        key: ValueKey(open),
        color: Colors.white,
        size: 26,
      ),
    );
    if (unread > 0 && !open) {
      icon = Badge(label: Text(unread > 99 ? '99+' : '$unread'), backgroundColor: AppColors.red, child: icon);
    }
    return Semantics(
      button: true,
      label: 'More options',
      child: Container(
        width: _DockBar._orb + 8,
        height: _DockBar._orb + 8,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5B82FF), AppColors.brandDeep],
            ),
            boxShadow: [BoxShadow(color: AppColors.brand.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(child: icon),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({required this.tab, required this.selected, required this.badge, required this.onTap});
  final ShellTab tab;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : AppColors.slate.withValues(alpha: 0.85);
    Widget icon = AnimatedScale(
      scale: selected ? 1.12 : 1,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      child: Icon(tab.icon, size: 23, color: color),
    );
    if (badge > 0) {
      icon = Badge(label: Text('$badge'), backgroundColor: AppColors.red, child: icon);
    }
    return Semantics(
      button: true,
      selected: selected,
      label: tab.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 10,
                letterSpacing: -0.1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: color,
              ),
              child: Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "More" bottom panel
// ---------------------------------------------------------------------------

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.items, required this.onItem, required this.onLogout});
  final List<ShellDrawerItem> items;
  final ValueChanged<ShellDrawerItem> onItem;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final unread = context.select<NotificationsController, int>((c) => c.unread);
    final user = auth.user;
    final school = auth.school;

    String role = 'User';
    if (user != null) {
      if (user.isDriver) {
        role = 'Driver';
      } else if (user.isHelper) {
        role = 'Helper';
      } else if (user.isParent) {
        role = 'Parent';
      } else {
        role = user.role.replaceAll('_', ' ');
      }
    }
    final initial = (user?.fullName.isNotEmpty == true) ? user!.fullName.characters.first.toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.ink, Color(0xFF1B2A6B), AppColors.brand],
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: Text(initial, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.fullName ?? 'SafeRoute',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.3),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                                    child: Text(
                                      role.toUpperCase(),
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: Colors.white),
                                    ),
                                  ),
                                  if (school != null) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        school.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.82)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'QUICK ACCESS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.slate),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, box) {
                        const spacing = 10.0;
                        final w = (box.maxWidth - spacing) / 2;
                        return Wrap(
                          spacing: spacing,
                          runSpacing: spacing,
                          children: [
                            for (var i = 0; i < items.length; i++)
                              SizedBox(
                                width: w,
                                child: SrFadeIn(
                                  delay: Duration(milliseconds: 40 * i),
                                  duration: const Duration(milliseconds: 360),
                                  offset: 16,
                                  child: _MoreTile(item: items[i], unread: unread, onTap: () => onItem(items[i])),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    SrFadeIn(
                      delay: Duration(milliseconds: 40 * items.length + 40),
                      duration: const Duration(milliseconds: 360),
                      offset: 16,
                      child: Material(
                        color: AppColors.red.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: onLogout,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.logout_rounded, color: AppColors.red, size: 20),
                                SizedBox(width: 10),
                                Text('Log out', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 15)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.item, required this.unread, required this.onTap});
  final ShellDrawerItem item;
  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destructive = item.isDestructive;
    final accent = destructive ? AppColors.red : AppColors.brand;
    final badge = item.badgeCount ?? (item.label.toLowerCase().contains('alert') ? unread : 0);
    return Material(
      color: destructive ? AppColors.red.withValues(alpha: 0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: destructive ? AppColors.red.withValues(alpha: 0.25) : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: Icon(item.icon, color: accent, size: 22),
                  ),
                  if (badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(10)),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: destructive ? AppColors.red : AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
