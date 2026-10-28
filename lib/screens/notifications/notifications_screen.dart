import 'package:flutter/material.dart';
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
  const NotificationsScreen({super.key, this.initialCategory});
  final String? initialCategory;

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
        body: NotificationsList(initialCategory: initialCategory),
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
  const NotificationsList({super.key, this.initialCategory});
  final String? initialCategory;

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
      if (widget.initialCategory != null) {
        c.setCategoryFilter(widget.initialCategory!);
      }
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

  bool get _isEmergency => item.type == 'EMERGENCY_ALERT';

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

  Color get _badgeBg {
    if (_isEmergency) return const Color(0xFFFEE2E2);
    if (_isAnnouncement) return const Color(0xFFFEF3C7);
    if (item.type.contains('BUS') || item.type.contains('TRIP')) return const Color(0xFFEFF6FF);
    return const Color(0xFFF3F4F6);
  }

  Color get _badgeFg {
    if (_isEmergency) return const Color(0xFFDC2626);
    if (_isAnnouncement) return const Color(0xFFD97706);
    if (item.type.contains('BUS') || item.type.contains('TRIP')) return const Color(0xFF2563EB);
    return const Color(0xFF4B5563);
  }

  IconData get _typeIcon {
    if (_isEmergency) return Icons.warning_amber_rounded;
    if (_isAnnouncement) return Icons.campaign_rounded;
    if (item.type == 'BUS_STARTED' || item.type == 'BUS_STARTED_RETURN') return Icons.directions_bus_rounded;
    if (item.type == 'BUS_NEAR_STOP' || item.type == 'BUS_ARRIVED_STOP' || item.type == 'BUS_NEAR_HOME') {
      return Icons.near_me_rounded;
    }
    if (item.type == 'STUDENT_BOARDED' || item.type == 'STUDENT_DROPPED' || item.type == 'STUDENT_REACHED_SCHOOL') {
      return Icons.child_care_rounded;
    }
    if (item.type == 'TRIP_CANCELLED' || item.type == 'BUS_DELAYED') return Icons.schedule_rounded;
    if (item.type.contains('LEAVE')) return Icons.event_busy_rounded;
    return Icons.notifications_rounded;
  }

  String get _categoryLabel {
    if (_isEmergency) return 'EMERGENCY';
    if (_isAnnouncement) return 'ANNOUNCEMENT';
    if (item.type == 'BUS_DELAYED') return 'DELAY';
    if (item.type.contains('BUS') || item.type.contains('TRIP')) return 'TRIP ALERT';
    if (item.type.contains('STUDENT')) return 'STUDENT';
    return 'NOTIFICATION';
  }

  void _onTap(BuildContext context) {
    final c = context.read<NotificationsController>();
    c.markRead(item);

    final hasTrip = item.data.containsKey('trip_id') && item.data['trip_id']!.isNotEmpty;
    final hasStudent = item.data.containsKey('student_id') && item.data['student_id']!.isNotEmpty;
    final hasConv = item.data.containsKey('conversation_id') && item.data['conversation_id']!.isNotEmpty;

    if (hasTrip || hasConv || (hasStudent && !_isAnnouncement)) {
      context.read<AppServices>().deepLinks.open({...item.data, 'type': item.type});
    } else {
      _showDetailSheet(context);
    }
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotificationDetailSheet(
        item: item,
        cleanTitle: _cleanTitle,
        categoryLabel: _categoryLabel,
        isAnnouncement: _isAnnouncement,
        badgeBg: _badgeBg,
        badgeFg: _badgeFg,
        icon: _typeIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;
    final timeStr = _formatTimeAgo(item.createdAt);
    final schoolOrAudience = [
      if (item.schoolName != null && item.schoolName!.isNotEmpty) item.schoolName!,
      if (item.data['context'] != null && item.data['context']!.isNotEmpty) item.data['context']!,
    ].join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: unread ? const Color(0xFFFAFCFF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: unread ? AppColors.brand.withValues(alpha: 0.35) : const Color(0xFFE5E7EB),
          width: unread ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: unread ? AppColors.brand.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _onTap(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Leading icon, category pill, school/audience, relative time, close button
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_typeIcon, size: 20, color: _badgeFg),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _categoryLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                    color: _badgeFg,
                                  ),
                                ),
                              ),
                              if (timeStr.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('•', style: TextStyle(fontSize: 10, color: AppColors.slate.withValues(alpha: 0.6))),
                                const SizedBox(width: 6),
                                Text(
                                  timeStr,
                                  style: const TextStyle(fontSize: 11, color: AppColors.slate, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                          if (schoolOrAudience.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                schoolOrAudience,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.slate, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Unread blue dot indicator (Apple iOS style)
                    if (unread)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.brand,
                          shape: BoxShape.circle,
                        ),
                      ),
                    // Delete button
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () async {
                        final ok = await confirmDialog(
                          context,
                          title: 'Delete notification?',
                          message: item.title,
                          confirm: 'Delete',
                          destructive: true,
                        );
                        if (!ok || !context.mounted) return;
                        final err = await context.read<NotificationsController>().delete(item);
                        if (err != null && context.mounted) showSnack(context, err, error: true);
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 18, color: AppColors.slate),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 2. Title line with optional (edited)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _cleanTitle,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (item.isEdited)
                      const Text(
                        ' (edited)',
                        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.slate),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                // 3. Message Body
                Text(
                  item.message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF374151),
                    height: 1.4,
                  ),
                ),

                // 4. Footer pills (Student context, action hint)
                if (item.studentName != null && item.studentName!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded, size: 13, color: AppColors.slate),
                            const SizedBox(width: 4),
                            Text(
                              item.studentName!,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'View details ›',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.brand),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Apple iOS-inspired modal bottom sheet displaying full notification / announcement content comfortably.
class _NotificationDetailSheet extends StatelessWidget {
  const _NotificationDetailSheet({
    required this.item,
    required this.cleanTitle,
    required this.categoryLabel,
    required this.isAnnouncement,
    required this.badgeBg,
    required this.badgeFg,
    required this.icon,
  });

  final AppNotification item;
  final String cleanTitle;
  final String categoryLabel;
  final bool isAnnouncement;
  final Color badgeBg;
  final Color badgeFg;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dateStr = item.createdAt != null
        ? DateFormat('MMMM d, yyyy · h:mm a').format(item.createdAt!)
        : '';
    final hasTrip = item.data.containsKey('trip_id') && item.data['trip_id']!.isNotEmpty;
    final hasStudent = item.data.containsKey('student_id') && item.data['student_id']!.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: badgeFg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: badgeFg, letterSpacing: 0.4),
                      ),
                    ),
                    if (dateStr.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          dateStr,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            cleanTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
          ),
          if (item.schoolName != null || item.data['context'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.schoolName != null) ...[
                  const Icon(Icons.school_rounded, size: 15, color: AppColors.slate),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.schoolName!,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.slate, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (item.data['context'] != null && item.data['context']!.isNotEmpty) ...[
                  const Icon(Icons.groups_rounded, size: 15, color: AppColors.slate),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.data['context']!,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.slate, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF3F4F6)),
            ),
            child: Text(
              item.message,
              style: const TextStyle(fontSize: 14.5, height: 1.5, color: Color(0xFF1F2937)),
            ),
          ),
          if (hasTrip || hasStudent) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.brand,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                Navigator.pop(context);
                context.read<AppServices>().deepLinks.open({...item.data, 'type': item.type});
              },
              icon: Icon(hasTrip ? Icons.directions_bus_rounded : Icons.person_rounded),
              label: Text(hasTrip ? 'View Live Bus & Route' : 'View Student Details'),
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

