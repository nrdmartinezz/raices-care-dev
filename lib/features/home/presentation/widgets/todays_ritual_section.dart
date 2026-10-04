import 'package:flutter/material.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../data/home_template_content.dart';
import 'care_task_card.dart';
import 'section_heading.dart';

/// Section 3: the care checklist with a completion bar above it.
class TodaysRitualSection extends StatelessWidget {
  const TodaysRitualSection({super.key});

  @override
  Widget build(BuildContext context) {
    final tasks = HomeTemplateContent.tasks;
    final doneCount = tasks.where((task) => task.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          icon: AppIcons.ritualCalendar,
          iconSize: const Size(16.5, 18.333),
          title: "Today's Ritual",
          trailing: Text(
            HomeTemplateContent.ritualProgressLabel,
            style: AppText.labelSemiBold.copyWith(color: AppColors.green),
          ),
        ),
        const SizedBox(height: 8),
        _ProgressStrip(value: doneCount / tasks.length),
        const SizedBox(height: 12),
        for (final task in tasks) ...[
          CareTaskCard(task: task),
          if (task != tasks.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.pill),
      child: Container(
        height: 10,
        color: AppColors.track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: BoxDecoration(color: AppColors.green),
          ),
        ),
      ),
    );
  }
}
