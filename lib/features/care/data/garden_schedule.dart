import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/data/home_providers.dart';
import '../../plants/data/plant_repository.dart';
import '../../plants/domain/plant.dart';
import '../domain/care_task_type.dart';
import '../domain/reminder.dart';
import 'reminder_repository.dart';

/// Where an open reminder sits relative to today.
enum ChoreWhen { overdue, today, later }

/// Calendar day of [dueAt] compared with [now].
ChoreWhen choreWhen(DateTime dueAt, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dueAt.year, dueAt.month, dueAt.day);
  if (due.isBefore(today)) {
    return ChoreWhen.overdue;
  }
  if (due == today) {
    return ChoreWhen.today;
  }
  return ChoreWhen.later;
}

/// One open reminder that still belongs to a plant in the garden.
class GardenChore {
  const GardenChore({required this.reminder, required this.plant});

  final Reminder reminder;
  final Plant plant;
}

/// Open reminders joined to active plants, grouped by when they are due.
class GardenSchedule {
  const GardenSchedule({
    required this.hasPlants,
    required this.overdue,
    required this.today,
    required this.later,
  });

  final bool hasPlants;
  final List<GardenChore> overdue;
  final List<GardenChore> today;
  final List<GardenChore> later;

  bool get isEmpty => overdue.isEmpty && today.isEmpty && later.isEmpty;
}

GardenSchedule gardenScheduleFrom({
  required List<Reminder> reminders,
  required List<Plant> plants,
  required DateTime now,
}) {
  final byId = {for (final plant in plants) plant.id: plant};
  final overdue = <GardenChore>[];
  final today = <GardenChore>[];
  final later = <GardenChore>[];

  for (final reminder in reminders) {
    final plant = byId[reminder.plantId];
    if (plant == null) {
      continue;
    }
    final chore = GardenChore(reminder: reminder, plant: plant);
    switch (choreWhen(reminder.dueAt, now)) {
      case ChoreWhen.overdue:
        overdue.add(chore);
      case ChoreWhen.today:
        today.add(chore);
      case ChoreWhen.later:
        later.add(chore);
    }
  }

  return GardenSchedule(
    hasPlants: plants.isNotEmpty,
    overdue: overdue,
    today: today,
    later: later,
  );
}

/// True when the plant's next water check has arrived, or it has never been watered.
bool needsWatering(Plant plant, DateTime now) {
  final next = plant.nextActions.nextWaterCheckAt;
  if (next != null) {
    return !next.isAfter(now);
  }
  return plant.currentCare.lastWateredAt == null;
}

/// Watering that still needs doing today: a due water reminder, a plant whose
/// next watering has arrived, or a plant that has never been watered.
List<GardenChore> wateringDue({
  required List<GardenChore> all,
  required List<Plant> plants,
  required DateTime now,
}) {
  final chores = <GardenChore>[];
  final covered = <String>{};
  for (final chore in all) {
    if (chore.reminder.taskType != ReminderTaskType.waterCheck) {
      continue;
    }
    final scheduled = choreWhen(chore.reminder.dueAt, now) != ChoreWhen.later;
    if (scheduled || needsWatering(chore.plant, now)) {
      chores.add(chore);
      covered.add(chore.plant.id);
    }
  }
  for (final plant in plants) {
    if (covered.contains(plant.id) || !needsWatering(plant, now)) {
      continue;
    }
    chores.add(
      GardenChore(
        reminder: Reminder(
          id: 'water:${plant.id}',
          plantId: plant.id,
          speciesId: plant.speciesId,
          taskType: ReminderTaskType.waterCheck,
          title: 'Water ${plant.displayName}',
          dueAt: now,
        ),
        plant: plant,
      ),
    );
  }
  return chores;
}

/// Every open reminder for the plants still in the garden.
final gardenScheduleProvider = Provider<AsyncValue<GardenSchedule>>((ref) {
  final remindersAsync = ref.watch(openRemindersProvider);
  final plantsAsync = ref.watch(activePlantsProvider);
  final now = ref.watch(nowProvider);

  final reminders = remindersAsync.value;
  final plants = plantsAsync.value;
  // A non-empty list wins over a later error, same as My Plants. An error
  // that only still holds an empty list stays an error: that is a failed
  // read, not a garden with nothing scheduled.
  final remindersReady =
      reminders != null && (reminders.isNotEmpty || !remindersAsync.hasError);
  final plantsReady =
      plants != null && (plants.isNotEmpty || !plantsAsync.hasError);
  if (remindersReady && plantsReady) {
    return AsyncValue.data(
      gardenScheduleFrom(reminders: reminders, plants: plants, now: now),
    );
  }

  final error = remindersAsync.error ?? plantsAsync.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      remindersAsync.stackTrace ?? plantsAsync.stackTrace ?? StackTrace.empty,
    );
  }
  return const AsyncValue.loading();
});
