import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../domain/sowing_calendar.dart';

class SowingCalendarSection extends StatelessWidget {
  const SowingCalendarSection({required this.calendar, super.key});

  final SowingCalendar calendar;

  @override
  Widget build(BuildContext context) {
    final plans = [
      for (final plan in calendar.plans)
        if (plan.milestones.isNotEmpty) plan,
    ];
    if (plans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Planting', style: AppText.title.copyWith(color: AppColors.ink)),
        const SizedBox(height: 4),
        Text(
          'Dates use the 30-year average frost for your garden.',
          style: AppText.caption.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        for (final plan in plans) ...[
          Text(
            sowingSeasonLabel(plan.season),
            style: AppText.label.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 4),
          for (final milestone in plan.milestones) ...[
            Text(
              sowingMethodLabel(milestone.method),
              style: AppText.body.copyWith(color: AppColors.ink),
            ),
            Text(
              formatPlantingRange(milestone.start, milestone.end),
              style: AppText.body.copyWith(color: AppColors.body),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}
