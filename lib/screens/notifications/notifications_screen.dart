import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../models/app_notification.dart';
import '../../providers/notifications_controller.dart';
import '../../providers/parent_controller.dart';
import '../../widgets/state_views.dart';

/// Stand-alone route (from a notification tap).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications'), actions: const [ClearAllNotificationsButton(), MarkAllReadButton()]),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = context.read<NotificationsController>();
      final wanted = _wantedFilter(c);
      wanted == c.studentFilter ? c.load() : c.setStudentFilter(wanted);
    });
  }

  /// A parent with several children sees the selected child's notifications
  /// unless they chose "All children".
  String? _wantedFilter(NotificationsController c) {
    final parent = context.read<ParentController>();
    if (parent.children.length < 2 || c.showAllChildren) return null;
    return parent.selectedChild?.student.publicId;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NotificationsController>();
    final parent = context.watch<ParentController>();
    final wanted = _wantedFilter(c);
    if (wanted != c.studentFilter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<NotificationsController>().setStudentFilter(_wantedFilter(c));
      });
    }

    final filterBar = parent.children.length < 2
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(parent.selectedChild?.label ?? 'Selected child'),
                  selected: !c.showAllChildren,
                  onSelected: (_) => c.setShowAllChildren(false),
                ),
                ChoiceChip(
                  label: const Text('All children'),
                  selected: c.showAllChildren,
                  onSelected: (_) => c.setShowAllChildren(true),
                ),
              ],
            ),
          );

    Widget body;
    if (c.loading && c.items.isEmpty) {
      body = const LoadingView();
    } else if (c.error != null && c.items.isEmpty) {
      body = ErrorView(message: c.error!, onRetry: c.load);
    } else if (c.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: c.load,
        child: ListView(children: const [
          SizedBox(height: 120),
          EmptyView(icon: Icons.notifications_none, title: 'No notifications yet'),
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
            itemCount: c.items.length + (c.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i >= c.items.length) {
                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              }
              return _NotificationTile(item: c.items[i]);
            },
          ),
        ),
      );
    }

    if (filterBar == null) return body;
    return Column(children: [filterBar, Expanded(child: body)]);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = !item.isRead;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: unread ? AppColors.brand.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest,
        child: Icon(_icon(item.type), color: unread ? AppColors.brand : AppColors.slate),
      ),
      title: Text(item.title, style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.message),
          if (item.createdAt != null)
            Text(DateFormat('d MMM, h:mm a').format(item.createdAt!), style: theme.textTheme.bodySmall),
        ],
      ),
      isThreeLine: true,
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Delete',
        onPressed: () async {
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
      ),
      onTap: () {
        final c = context.read<NotificationsController>();
        c.markRead(item);
        final hasTarget = item.data.containsKey('trip_id') || item.data.containsKey('student_id');
        if (hasTarget) context.read<AppServices>().deepLinks.open({...item.data, 'type': item.type});
      },
    );
  }
}
