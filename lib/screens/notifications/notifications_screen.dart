import 'package:flutter/material.dart';
import '../../theme/sr_tokens.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../models/app_notification.dart';
import '../../providers/notifications_controller.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';

import 'preferences_screen.dart';

/// Stand-alone route (from a notification tap).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: [
            IconButton(
              tooltip: 'Preferences',
              icon: const Icon(Icons.tune),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationPreferencesScreen()),
              ),
            ),
            const ClearAllNotificationsButton(),
            const MarkAllReadButton(),
          ],
        ),
        body: const NotificationsList(),
      );
}

class MarkAllReadButton extends StatelessWidget {
  const MarkAllReadButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NotificationsController>();
    return IconButton(
      tooltip: 'Mark all as read',
      icon: const Icon(Icons.done_all),
      onPressed: c.unread == 0
          ? null
          : () async {
              final err = await c.markAllRead();
              if (err != null && context.mounted) showSnack(context, err, error: true);
            },
    );
  }
}

class ClearAllNotificationsButton extends StatelessWidget {
  const ClearAllNotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NotificationsController>();
    return IconButton(
      tooltip: 'Clear all',
      icon: const Icon(Icons.delete_outline),
      onPressed: c.items.isEmpty
          ? null
          : () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete all notifications?',
                message: 'This removes them from your inbox.',
                confirm: 'Delete all',
                destructive: true,
              );
              if (!ok || !context.mounted) return;
              final err = await c.clearAll();
              if (err != null && context.mounted) showSnack(context, err, error: true);
            },
    );
  }
}

class NotificationsList extends StatefulWidget {
  const NotificationsList({super.key});

  @override
  State<NotificationsList> createState() => _NotificationsListState();
}

class _NotificationsListState extends State<NotificationsList> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<NotificationsController>();
      final parent = context.read<ParentController>();
      if (c.studentFilter == null && !c.showAllChildren && parent.selectedChild != null) {
        c.setStudentFilter(parent.selectedChild!.student.publicId);
      } else {
        c.load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NotificationsController>();
    final parent = context.watch<ParentController>();

    // 1. Student Names Selecting Option Bar (shows all children + All children)
    final studentSelectorBar = parent.children.isEmpty
        ? null
        : Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    avatar: const Icon(Icons.people_outline, size: 16),
                    label: const Text('All children'),
                    selected: c.showAllChildren,
                    selectedColor: AppColors.brand,
                    labelStyle: TextStyle(
                      color: c.showAllChildren ? Colors.white : AppColors.ink,
                      fontWeight: c.showAllChildren ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 12,
                    ),
                    onSelected: (_) => c.setShowAllChildren(true),
                  ),
                  const SizedBox(width: 8),
                  for (final child in parent.children) ...[
                    ChoiceChip(
                      avatar: const Icon(Icons.person_outline, size: 16),
                      label: Text(child.student.fullName),
                      selected: !c.showAllChildren && c.studentFilter == child.student.publicId,
                      selectedColor: AppColors.brand,
                      labelStyle: TextStyle(
                        color: (!c.showAllChildren && c.studentFilter == child.student.publicId)
                            ? Colors.white
                            : AppColors.ink,
                        fontWeight: (!c.showAllChildren && c.studentFilter == child.student.publicId)
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        c.filterByChild(child.student.publicId);
                        parent.selectChild(child.student.publicId);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          );

    // 2. Category Tabs (All Notifications / Alerts / Announcements)
    final typeFilterBar = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All Notifications'),
            selected: c.categoryFilter == 'ALL',
            onSelected: (_) => c.setCategoryFilter('ALL'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('🔔 Alerts'),
            selected: c.categoryFilter == 'ALERTS',
            onSelected: (_) => c.setCategoryFilter('ALERTS'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('📢 Announcements'),
            selected: c.categoryFilter == 'ANNOUNCEMENTS',
            onSelected: (_) => c.setCategoryFilter('ANNOUNCEMENTS'),
          ),
        ],
      ),
    );

    // 3. Search Bar
    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: SizedBox(
        height: 38,
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search notifications or sender...',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.slate),
            prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.slate),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      c.setSearchQuery('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.brand),
            ),
          ),
          onSubmitted: (val) => c.setSearchQuery(val.trim()),
          onChanged: (val) {
            setState(() {});
            if (val.isEmpty) c.setSearchQuery('');
          },
        ),
      ),
    );

    Widget body;
    if (c.loading && c.items.isEmpty) {
      body = const LoadingView(label: 'Loading notifications', skeleton: true);
    } else if (c.error != null && c.items.isEmpty) {
      body = ErrorView(message: c.error!, onRetry: c.load);
    } else if (c.items.isEmpty) {
      final emptyTitle = c.categoryFilter == 'ANNOUNCEMENTS'
          ? 'No announcements yet'
          : c.categoryFilter == 'ALERTS'
              ? 'No alerts yet'
              : 'No notifications yet';
      body = RefreshIndicator(
        onRefresh: c.load,
        child: ListView(children: [
          const SizedBox(height: 120),
          EmptyView(icon: Icons.notifications_none, title: emptyTitle),
        ]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: c.load,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) c.loadMore();
            return false;
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: c.items.length + (c.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              if (i >= c.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return _NotificationTile(item: c.items[i]);
            },
          ),
        ),
      );
    }

    return Column(
      children: [
        ?studentSelectorBar,
        typeFilterBar,
        searchBar,
        Expanded(child: body),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});
  final AppNotification item;

  static IconData _icon(String type) => switch (type) {
        'EMERGENCY_ALERT' => Icons.warning_amber_rounded,
        'BUS_STARTED' || 'BUS_STARTED_RETURN' => Icons.directions_bus,
        'BUS_NEAR_STOP' || 'BUS_ARRIVED_STOP' || 'BUS_NEAR_HOME' => Icons.near_me,
        'STUDENT_BOARDED' || 'STUDENT_DROPPED' || 'STUDENT_REACHED_SCHOOL' || 'SCHOOL_DISPERSAL' => Icons.child_care,
        'TRIP_CANCELLED' || 'BUS_DELAYED' => Icons.schedule,
        'LEAVE_RECORDED' || 'LEAVE_APPROVED' || 'LEAVE_REJECTED' => Icons.event_busy,
        _ => Icons.notifications_outlined,
      };

  bool get _isAnnouncement {
    final t = item.type.toUpperCase();
    final title = item.title.toLowerCase();
    final msg = item.message.toLowerCase();
    final kind = (item.data['kind'] ?? '').toLowerCase();
    return t == 'STAFF_MESSAGE' ||
        t == 'HOLIDAY_NOTICE' ||
        kind == 'school_announcement' ||
        title.contains('announcement') ||
        msg.contains('announcement') ||
        title.contains('broadcast') ||
        msg.contains('broadcast');
  }

  String get _cleanTitle {
    final title = item.title;
    final colonIdx = title.lastIndexOf(': ');
    if (colonIdx != -1 && colonIdx < title.length - 2) {
      final prefix = title.substring(0, colonIdx);
      if ((item.studentName != null && prefix.contains(item.studentName!)) ||
          (item.schoolName != null && prefix.contains(item.schoolName!))) {
        return title.substring(colonIdx + 2);
      }
    }
    return title;
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  String _formatFullDateTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat('MMM d, yyyy, h:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final emergency = item.type == 'EMERGENCY_ALERT';
    final accent = emergency ? AppColors.red : AppColors.brand;
    final isAnn = _isAnnouncement;

    return Container(
      decoration: BoxDecoration(
        color: unread ? Color.alphaBlend(accent.withValues(alpha: 0.05), Colors.white) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: unread ? accent.withValues(alpha: 0.30) : AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final c = context.read<NotificationsController>();
            c.markRead(item);
            final hasTarget = item.data.containsKey('trip_id') || item.data.containsKey('student_id');
            if (hasTarget) context.read<AppServices>().deepLinks.open({...item.data, 'type': item.type});
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category, School, Student badges, edited tag & close button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isAnn)
                            const _MetaBadge(label: 'Announcement', icon: Icons.campaign_rounded, color: AppColors.amber)
                          else
                            const _MetaBadge(label: 'Alert', icon: Icons.notifications_active_rounded, color: AppColors.brand),
                          if (item.schoolName != null && item.schoolName!.isNotEmpty)
                            _MetaBadge(label: item.schoolName!, icon: Icons.school_rounded, color: AppColors.brandDeep),
                          if (item.studentName != null && item.studentName!.isNotEmpty)
                            _MetaBadge(label: item.studentName!, icon: Icons.person_rounded, color: AppColors.green),
                          if (item.data['context'] != null && item.data['context']!.isNotEmpty)
                            _MetaBadge(label: item.data['context']!, icon: Icons.groups_rounded, color: AppColors.slate),

                          // Edited indicator
                          if (item.isEdited)
                            const Text(
                              '(edited)',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.slate,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (unread)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),

                    // Delete button
                    InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete this notification?',
                          message: item.title,
                          confirm: 'Delete',
                          destructive: true,
                        );
                        if (!ok || !context.mounted) return;
                        final err = await context.read<NotificationsController>().delete(item);
                        if (err != null && context.mounted) showSnack(context, err, error: true);
                      },
                      child: const SizedBox(
                        width: SrSize.touch,
                        height: SrSize.touch,
                        child: Tooltip(
                          message: 'Delete notification',
                          child: Icon(Icons.close, size: 20, color: AppColors.slate),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Title Row with Icon
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(item.type), size: 18, color: unread ? accent : AppColors.slate),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _cleanTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Message Body
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.ink,
                      height: 1.35,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Footer: Time and relative time
                Padding(
                  padding: const EdgeInsets.only(left: 26),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppColors.slate),
                      const SizedBox(width: 4),
                      Text(
                        _formatFullDateTime(item.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.slate,
                        ),
                      ),
                      if (item.createdAt != null) ...[
                        const Text('  ·  ', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                        Text(
                          _formatTimeAgo(item.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small tinted label used for notification context (type, school, student).
/// Icon + text, so meaning never depends on colour alone.
class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onTint(color);
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(SrRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ),
        ],
      ),
    );
  }
}
