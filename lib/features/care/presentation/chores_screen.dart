import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../home/presentation/widgets/section_state.dart';
import '../../plants/domain/plant.dart';
import '../../home/data/home_providers.dart';
import '../../plants/presentation/care_labels.dart';
import '../data/care_event_repository.dart';
import '../data/chore_completion.dart';
import '../data/garden_schedule.dart';
import '../data/reminder_repository.dart';

/// Tab 3 — every open reminder for the plants still in the garden.
class ChoresScreen extends ConsumerStatefulWidget {
  const ChoresScreen({super.key});

  @override
  ConsumerState<ChoresScreen> createState() => _ChoresScreenState();
}

class _ChoresScreenState extends ConsumerState<ChoresScreen> {
  final _busy = <String>{};
  String? _error;

  Future<void> _record(GardenChore chore) async {
    final id = chore.reminder.id;
    if (!_busy.add(id)) {
      return;
    }
    setState(() => _error = null);
    try {
      await recordChore(
        events: ref.read(careEventRepositoryProvider),
        reminders: ref.read(reminderRepositoryProvider),
        plantId: chore.plant.id,
        reminderId: id,
        taskType: chore.reminder.taskType,
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = ref.watch(gardenScheduleProvider);

    return ShellScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE SCHEDULE',
            style: AppText.eyebrow.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 7),
          Text(
            'Chores',
            style: AppText.display.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          switch (schedule) {
            AsyncError(:final error) => SectionMessage(
              title: 'Chores could not load',
              body: describeSectionError(error),
            ),
            AsyncLoading() => const SectionSkeleton(rows: 3),
            AsyncValue(:final value?) => _Schedule(
              schedule: value,
              now: ref.watch(nowProvider),
              busy: _busy,
              error: _error,
              onRecord: _record,
              onOpen: (plantId) => context.goNamed(
                PlantDetailRoute.name,
                pathParameters: {'plantId': plantId},
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _Schedule extends StatelessWidget {
  const _Schedule({
    required this.schedule,
    required this.now,
    required this.busy,
    required this.error,
    required this.onRecord,
    required this.onOpen,
  });

  final GardenSchedule schedule;
  final DateTime now;
  final Set<String> busy;
  final String? error;
  final ValueChanged<GardenChore> onRecord;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (!schedule.hasPlants) {
      return const SectionMessage(
        title: 'No plants yet',
        body:
            'Chores come from the plants in your garden. '
            'Add one and its care rhythm shows up here.',
      );
    }
    if (schedule.isEmpty) {
      return const SectionMessage(
        title: 'Nothing open',
        body: 'Every plant is between tasks. New ones appear as they come due.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in [
          ('Overdue', schedule.overdue),
          ('Today', schedule.today),
          ('Later', schedule.later),
        ])
          if (group.$2.isNotEmpty) ...[
            Text(
              group.$1,
              style: AppText.title.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 10),
            for (final chore in group.$2) ...[
              _ChoreRow(
                chore: chore,
                now: now,
                isBusy: busy.contains(chore.reminder.id),
                onOpen: () => onOpen(chore.plant.id),
                onRecord: () => onRecord(chore),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 8),
          ],
        if (error case final message?)
          Text(
            message,
            style: AppText.body.copyWith(color: AppColors.terracottaBright),
          ),
      ],
    );
  }
}

class _ChoreRow extends StatelessWidget {
  const _ChoreRow({
    required this.chore,
    required this.now,
    required this.isBusy,
    required this.onOpen,
    required this.onRecord,
  });

  final GardenChore chore;
  final DateTime now;
  final bool isBusy;
  final VoidCallback onOpen;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final reminder = chore.reminder;
    final canLog = careEventFor(reminder.taskType) != null;
    final radius = BorderRadius.circular(AppSizes.cardRadius);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onOpen,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: AppShadows.card,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chore.plant.displayName,
                      style: AppText.title.copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${reminder.title} · ${_place(chore.plant)}',
                      style: AppText.body.copyWith(color: AppColors.body),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dueLabel(reminder.dueAt, now: now),
                      style: AppText.label.copyWith(color: AppColors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: isBusy ? null : onRecord,
                child: Text(
                  isBusy
                      ? 'Saving'
                      : canLog
                      ? 'Done'
                      : 'Skip',
                  style: AppText.label.copyWith(color: AppColors.terracotta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _place(Plant plant) => switch (plant.locationType) {
  LocationType.indoor => 'Indoors',
  LocationType.outdoor => 'Outdoors',
  LocationType.greenhouse => 'Greenhouse',
  LocationType.other => 'Unplaced',
};
