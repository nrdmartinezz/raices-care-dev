import 'package:flutter_test/flutter_test.dart';
import 'package:raices/features/care/data/chore_completion.dart';
import 'package:raices/features/care/data/garden_schedule.dart';
import 'package:raices/features/care/domain/care_event.dart';
import 'package:raices/features/care/domain/care_task_type.dart';
import 'package:raices/features/care/domain/reminder.dart';
import 'package:raices/features/plants/domain/plant.dart';
import 'package:raices/features/plants/presentation/care_labels.dart';

void main() {
  test('care events cover the recurring chores', () {
    expect(careEventFor(ReminderTaskType.waterCheck), CareEventType.watered);
    expect(careEventFor(ReminderTaskType.fertilize), CareEventType.fertilized);
    expect(careEventFor(ReminderTaskType.prune), CareEventType.pruned);
    expect(careEventFor(ReminderTaskType.repot), CareEventType.repotted);
    expect(
      careEventFor(ReminderTaskType.pestCheck),
      CareEventType.pestInspection,
    );
    expect(careEventFor(ReminderTaskType.harvest), isNull);
    expect(careEventFor(ReminderTaskType.custom), isNull);
  });

  test('open reminders join only the plants still in the garden', () {
    final now = DateTime(2026, 10, 5, 9);
    final kept = _plant('kept', lastWateredAt: now);
    final schedule = gardenScheduleFrom(
      now: now,
      plants: [kept],
      reminders: [
        _reminder('late', plantId: 'kept', dueAt: DateTime(2026, 10, 4)),
        _reminder('today', plantId: 'kept', dueAt: DateTime(2026, 10, 5, 18)),
        _reminder('later', plantId: 'kept', dueAt: DateTime(2026, 10, 8)),
        _reminder('gone', plantId: 'removed', dueAt: DateTime(2026, 10, 5)),
      ],
    );

    expect(schedule.overdue.map((chore) => chore.reminder.id), ['late']);
    expect(schedule.today.map((chore) => chore.reminder.id), ['today']);
    expect(schedule.later.map((chore) => chore.reminder.id), ['later']);
  });

  test('a plant that still needs water is a chore for today', () {
    final now = DateTime(2026, 10, 7, 9);
    final schedule = gardenScheduleFrom(
      now: now,
      plants: [_plant('celery')],
      reminders: [
        _reminder(
          'water',
          plantId: 'celery',
          dueAt: DateTime(2026, 10, 14),
          intervalDays: 7,
        ),
      ],
    );

    expect(schedule.later.map((chore) => chore.reminder.id), ['water']);
    final due = wateringDue(
      all: [...schedule.overdue, ...schedule.today, ...schedule.later],
      plants: [_plant('celery')],
      now: now,
    );
    expect(due.map((chore) => chore.reminder.id), ['water']);
  });

  test('a recent watering keeps the next check for later', () {
    final now = DateTime(2026, 10, 7, 9);
    final schedule = gardenScheduleFrom(
      now: now,
      plants: [_plant('celery', lastWateredAt: DateTime(2026, 10, 6))],
      reminders: [
        _reminder(
          'water',
          plantId: 'celery',
          dueAt: DateTime(2026, 10, 13),
          intervalDays: 7,
        ),
      ],
    );

    expect(schedule.today, isEmpty);
    expect(schedule.later.map((chore) => chore.reminder.id), ['water']);
  });

  test('watered today is not due again until tomorrow', () {
    final morning = DateTime(2026, 10, 8, 9);
    final evening = DateTime(2026, 10, 8, 21);
    expect(wateredToday(evening, morning), isTrue);
    expect(wateredToday(evening, DateTime(2026, 10, 9, 8)), isFalse);
    expect(wateredToday(null, morning), isFalse);
  });

  test('estimated age counts years, months, then days', () {
    final now = DateTime(2026, 10, 8);
    expect(estimatedAgeLabel(DateTime(2024, 6, 8), now), '2 yrs 4 mos');
    expect(estimatedAgeLabel(DateTime(2026, 7, 8), now), '3 mos');
    expect(estimatedAgeLabel(DateTime(2026, 9, 26), now), '12 days');
  });

  test('a plant watered today with a future check is not on today\'s list', () {
    final now = DateTime(2026, 10, 8, 9);
    final plant = _plant(
      'basil',
      lastWateredAt: now,
      nextWaterCheckAt: DateTime(2026, 10, 15, 9),
    );
    final schedule = gardenScheduleFrom(
      now: now,
      plants: [plant],
      reminders: [
        _reminder(
          'basil__water_check',
          plantId: 'basil',
          dueAt: DateTime(2026, 10, 15, 9),
          intervalDays: 7,
        ),
      ],
    );
    final listed = wateringDue(
      all: [...schedule.overdue, ...schedule.today, ...schedule.later],
      plants: [plant],
      now: now,
    );

    expect(schedule.today, isEmpty);
    expect(listed, isEmpty);
  });
}

Plant _plant(
  String id, {
  DateTime? lastWateredAt,
  DateTime? nextWaterCheckAt,
}) => Plant(
  id: id,
  speciesId: 'species',
  displayName: id,
  currentCare: PlantCurrentCare(lastWateredAt: lastWateredAt),
  nextActions: PlantNextActions(nextWaterCheckAt: nextWaterCheckAt),
);

Reminder _reminder(
  String id, {
  required String plantId,
  required DateTime dueAt,
  int? intervalDays,
}) {
  return Reminder(
    id: id,
    plantId: plantId,
    taskType: ReminderTaskType.waterCheck,
    title: 'Water',
    dueAt: dueAt,
    schedule: ReminderSchedule(intervalDays: intervalDays),
  );
}
