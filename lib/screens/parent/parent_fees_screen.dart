import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/parent_controller.dart';
import '../../widgets/sr_animations.dart';
import '../../widgets/state_views.dart';
import 'parent_widgets.dart';

/// Matches the React parent fees page: there is no live fees API yet, so this
/// is the same placeholder the web parent panel shows.
class ParentFeesScreen extends StatelessWidget {
  const ParentFeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final child = context.watch<ParentController>().selectedChild;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        const SelectedChildHeader(),
        SrFadeIn(
          delay: const Duration(milliseconds: 60),
          child: SectionCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(Icons.credit_score_rounded, size: 32, color: AppColors.green),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No outstanding dues',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink, letterSpacing: -0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  child == null
                      ? 'Transport fees for the current term are fully paid.'
                      : 'Transport fees for ${child.student.fullName} at ${child.school.name} are fully paid.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.slate, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        const SrFadeIn(
          delay: Duration(milliseconds: 140),
          child: SectionCard(
            title: 'Payment history',
            child: Row(
              children: [
                Icon(Icons.receipt_long_outlined, color: AppColors.brand),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Term 1 Transport Fee',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink),
                      ),
                      SizedBox(height: 2),
                      Text('Paid on 01 Sep 2026', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                StatusChip(label: 'PAID', color: AppColors.green),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
