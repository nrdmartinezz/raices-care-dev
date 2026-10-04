import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../data/home_providers.dart';
import 'care_task_card.dart';
import 'section_heading.dart';
import 'section_state.dart';

/// Section 3: the care checklist with a completion bar above it.
class TodaysRitualSection extends ConsumerWidget {
  const TodaysRitualSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(ritualSummaryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          icon: AppIcons.ritualCalendar,
          iconSize: const Size(16.5, 18.333),
          title: "Today's Ritual",
          trailing: Text(
            summary.value?.progressLabel ?? '',
            maxLines: 1,
            style: AppText.labelSemiBold.copyWith(color: AppColors.green),
          ),
        ),
        const SizedBox(height: 8),
        switch (summary) {
          AsyncError(:final error) => SectionMessage(
            title: 'Today\'s ritual could not load',
            body: describeSectionError(error),
          ),
          AsyncLoading() => const SectionSkeleton(rows: 3),
          AsyncValue(:final value?) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProgressStrip(value: value.progress),
              const SizedBox(height: 12),
              if (value.tasks.isEmpty)
                SectionMessage(
                  title: value.doneCount > 0
                      ? 'All done for today'
                      : 'Nothing scheduled',
                  body: value.doneCount > 0
                      ? 'Everything due today has been tended to.'
                      : 'Add a plant and its care reminders appear here.',
                )
              else
                for (final task in value.tasks) ...[
                  CareTaskCard(task: task),
                  if (task != value.tasks.last) const SizedBox(height: 10),
                ],
            ],
          ),
        },
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
