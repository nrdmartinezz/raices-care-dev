import 'package:flutter_test/flutter_test.dart';
import 'package:raices/features/care/data/chore_completion.dart';
import 'package:raices/features/care/data/garden_schedule.dart';
import 'package:raices/features/care/domain/care_event.dart';
import 'package:raices/features/care/domain/care_task_type.dart';
import 'package:raices/features/care/domain/reminder.dart';
import 'package:raices/features/plants/domain/plant.dart';

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

    expect(schedule.today.map((chore) => chore.reminder.id), ['water']);
    expect(schedule.later, isEmpty);
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
}

Plant _plant(String id, {DateTime? lastWateredAt}) => Plant(
  id: id,
  speciesId: 'species',
  displayName: id,
  currentCare: PlantCurrentCare(lastWateredAt: lastWateredAt),
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
