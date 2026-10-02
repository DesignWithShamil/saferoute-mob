import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_services.dart';
import '../../core/api/api_exception.dart';
import '../../widgets/state_views.dart';
import 'staff_message_thread_screen.dart';

/// Driver/helper inbox — one thread with school admin.
class StaffMessagesScreen extends StatefulWidget {
  const StaffMessagesScreen({super.key});

  @override
  State<StaffMessagesScreen> createState() => _StaffMessagesScreenState();
}

class _StaffMessagesScreenState extends State<StaffMessagesScreen> {
  String? _conversationId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final conv = await context.read<AppServices>().messaging.ensureOperatorConversation();
      if (mounted) setState(() => _conversationId = conv.publicId);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        child: _loading
            ? const LoadingView(label: 'Opening messages…')
            : _error != null
                ? ErrorView(message: _error!, onRetry: _open)
                : StaffMessageThreadScreen(conversationId: _conversationId!, readOnly: true),
      ),
    );
  }
}
