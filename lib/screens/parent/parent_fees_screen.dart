import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/parent_controller.dart';
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
      padding: const EdgeInsets.all(16),
      children: [
        const SelectedChildHeader(),
        SectionCard(
          child: Column(
            children: [
              const Icon(Icons.credit_card, size: 40, color: AppColors.green),
              const SizedBox(height: 12),
              const Text('No outstanding dues', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 8),
              Text(
                child == null
                    ? 'Transport fees for the current term are fully paid.'
                    : 'Transport fees for ${child.student.fullName} at ${child.school.name} are fully paid.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SectionCard(
          title: 'Payment history',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Term 1 Transport Fee'),
            subtitle: Text('Paid on 01 Sep 2026'),
            trailing: StatusChip(label: 'PAID', color: AppColors.green),
          ),
        ),
      ],
    );
  }
}
