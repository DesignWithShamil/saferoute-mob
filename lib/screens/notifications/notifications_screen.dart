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

    // 1. Sleek Top Filter Bar (Children + Segmented Categories + Search)
    final headerBar = Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A. Student Selector Horizontal Strip
          if (parent.children.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final seenIds = <String>{};
                final uniqueChildren = parent.children.where((ch) => seenIds.add(ch.student.publicId)).toList();
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ChildFilterPill(
                        label: 'All children',
                        icon: Icons.people_alt_rounded,
                        selected: c.showAllChildren,
                        onTap: () => c.setShowAllChildren(true),
                      ),
                      for (final child in uniqueChildren) ...[
                        const SizedBox(width: 8),
                        _ChildFilterPill(
                          label: child.student.fullName,
                          photo: child.student.photo,
                          selected: !c.showAllChildren && c.studentFilter == child.student.publicId,
                          onTap: () {
                            c.filterByChild(child.student.publicId);
                            parent.selectChild(child.student.publicId);
                          },
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],

          // B. Apple-style Segmented Category Control
          Container(
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _SegmentPill(
                  label: 'All Notifications',
                  selected: c.categoryFilter == 'ALL',
                  onTap: () => c.setCategoryFilter('ALL'),
                ),
                _SegmentPill(
                  label: '🔔 Alerts',
                  selected: c.categoryFilter == 'ALERTS',
                  onTap: () => c.setCategoryFilter('ALERTS'),
                ),
                _SegmentPill(
                  label: '📢 Announcements',
                  selected: c.categoryFilter == 'ANNOUNCEMENTS',
                  onTap: () => c.setCategoryFilter('ANNOUNCEMENTS'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // C. Apple-style Search Bar
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.search_rounded, size: 18, color: AppColors.slate),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.ink, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      hintText: 'Search notifications or sender...',
                      hintStyle: TextStyle(fontSize: 13, color: AppColors.slate),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (val) => c.setSearchQuery(val.trim()),
                    onChanged: (val) {
                      setState(() {});
                      if (val.isEmpty) c.setSearchQuery('');
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, size: 16, color: AppColors.slate),
                    onPressed: () {
                      _searchController.clear();
                      c.setSearchQuery('');
                    },
                  ),
              ],
            ),
          ),
        ],
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
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: EmptyView(icon: Icons.notifications_none_rounded, title: emptyTitle),
                ),
              ),
            ),
          ),
        ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
        headerBar,
        Expanded(child: body),
      ],
    );
  }
}

class _ChildFilterPill extends StatelessWidget {
  const _ChildFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.photo,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? photo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
          decoration: BoxDecoration(
            color: selected ? AppColors.brand : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.brand : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.brand.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (photo != null && photo!.isNotEmpty) ...[
                CircleAvatar(
                  radius: 10,
                  backgroundImage: NetworkImage(photo!),
                ),
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(icon, size: 14, color: selected ? Colors.white : AppColors.slate),
                const SizedBox(width: 6),
              ] else ...[
                CircleAvatar(
                  radius: 10,
                  backgroundColor: selected ? Colors.white.withValues(alpha: 0.25) : AppColors.brand.withValues(alpha: 0.15),
                  child: Text(
                    label.isNotEmpty ? label[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : AppColors.brand,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  const _SegmentPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
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

  bool get _isAnnouncement => item.isAnnouncement;

  String _getCleanTitle(String? stuName, String? schName) {
    final title = item.title;
    final colonIdx = title.lastIndexOf(': ');
    if (colonIdx != -1 && colonIdx < title.length - 2) {
      final prefix = title.substring(0, colonIdx);
      if ((stuName != null && prefix.contains(stuName)) ||
          (schName != null && prefix.contains(schName)) ||
          prefix.contains(' - ')) {
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

    // Resolve student and school names with robust fallbacks
    String? displayStudent = item.studentName;
    String? displaySchool = item.schoolName;

    if (displayStudent == null || displayStudent.isEmpty) {
      final colonIdx = item.title.indexOf(': ');
      if (colonIdx > 0) {
        final prefix = item.title.substring(0, colonIdx);
        if (prefix.contains(' - ')) {
          final parts = prefix.split(' - ');
          displayStudent = parts[0].trim();
          displaySchool ??= parts[1].trim();
        }
      }
    }

    if (displayStudent == null || displayStudent.isEmpty) {
      final parent = context.read<ParentController>();
      if (parent.children.length == 1) {
        displayStudent = parent.children.first.student.fullName;
        displaySchool ??= parent.children.first.student.schoolName;
      }
    }

    final cleanTitle = _getCleanTitle(displayStudent, displaySchool);

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
                          if (displaySchool != null && displaySchool.isNotEmpty)
                            _MetaBadge(label: displaySchool, icon: Icons.school_rounded, color: AppColors.brandDeep),
                          if (displayStudent != null && displayStudent.isNotEmpty)
                            _MetaBadge(label: displayStudent, icon: Icons.person_rounded, color: AppColors.green),
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
                        cleanTitle,
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
