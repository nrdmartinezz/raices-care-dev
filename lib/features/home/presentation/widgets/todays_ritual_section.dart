import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../care/data/care_event_repository.dart';
import '../../../care/data/chore_completion.dart';
import '../../../care/data/reminder_repository.dart';
import '../../data/home_providers.dart';
import '../../domain/care_task.dart';
import 'care_task_card.dart';
import 'section_heading.dart';
import 'section_state.dart';

/// Section 3: the care checklist with a completion bar above it.
class TodaysRitualSection extends ConsumerStatefulWidget {
  const TodaysRitualSection({super.key});

  @override
  ConsumerState<TodaysRitualSection> createState() =>
      _TodaysRitualSectionState();
}

class _TodaysRitualSectionState extends ConsumerState<TodaysRitualSection> {
  final _busy = <String>{};
  String? _error;

  Future<void> _complete(CareTask task) async {
    final plantId = task.plantId;
    final reminderId = task.reminderId;
    final taskType = task.taskType;
    if (plantId == null || reminderId == null || taskType == null) {
      return;
    }
    if (!_busy.add(reminderId)) {
      return;
    }
    setState(() => _error = null);
    try {
      await recordChore(
        events: ref.read(careEventRepositoryProvider),
        reminders: ref.read(reminderRepositoryProvider),
        plantId: plantId,
        reminderId: reminderId,
        taskType: taskType,
        at: ref.read(nowProvider),
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(reminderId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              if (value.hasPlants) ...[
                _ProgressStrip(value: value.progress),
                const SizedBox(height: 12),
              ],
              if (value.tasks.isEmpty)
                SectionMessage(
                  title: value.hasPlants
                      ? 'All done for today'
                      : 'No plants yet',
                  body: value.hasPlants
                      ? 'Nothing is due today.'
                      : 'Nothing to tend yet, because the garden is empty. '
                            'Tap the add button to add your first plant.',
                )
              else
                for (final task in value.tasks) ...[
                  CareTaskCard(
                    task: task,
                    onToggle: task.reminderId == null ||
                            _busy.contains(task.reminderId)
                        ? null
                        : () => _complete(task),
                  ),
                  if (task != value.tasks.last) const SizedBox(height: 10),
                ],
              if (_error case final message?) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: AppText.body.copyWith(
                    color: AppColors.terracottaBright,
                  ),
                ),
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
