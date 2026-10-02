import 'package:flutter/material.dart';

import '../../widgets/state_views.dart';
import 'attendance_roster.dart';

/// React `/driver/emergency` and `/helper/emergency`.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Emergency SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Only trigger for a genuine emergency (breakdown, accident, medical). This alerts school admins and parents.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              width: 180,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.red,
                  shape: const CircleBorder(),
                  textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                ),
                onPressed: () => showSosFlow(context),
                child: const Text('SOS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
