import 'package:flutter_test/flutter_test.dart';
import 'package:raices/features/care/domain/care_task_type.dart';
import 'package:raices/features/care/domain/reminder.dart';
import 'package:raices/features/home/data/home_mappers.dart';
import 'package:raices/features/home/domain/care_task.dart';
import 'package:raices/features/home/domain/growing_plant.dart';
import 'package:raices/features/plants/domain/plant.dart';

Plant _plant({
  String id = 'p1',
  PlantHealth health = PlantHealth.unknown,
  PlantAgeStage age = PlantAgeStage.mature,
  PlantCurrentCare currentCare = const PlantCurrentCare(),
  PlantNextActions nextActions = const PlantNextActions(),
}) => Plant(
  id: id,
  speciesId: 'monstera-deliciosa',
  displayName: 'Queen Monstera',
  speciesNameSnapshot: 'Monstera deliciosa',
  plantAgeStage: age,
  status: PlantStatus(health: health),
  currentCare: currentCare,
  nextActions: nextActions,
);

Reminder _reminder({
  ReminderTaskType type = ReminderTaskType.waterCheck,
  required DateTime dueAt,
  String? instructions,
}) => Reminder(
  id: 'p1__water_check',
  plantId: 'p1',
  taskType: type,
  title: 'Water check',
  dueAt: dueAt,
  instructions: instructions,
);

void main() {
  final now = DateTime(2026, 10, 3, 9, 30);

  group('labels', () {
    test('formats the date line as the design does', () {
      expect(formatDateLabel(DateTime(2026, 10, 24)), 'SATURDAY, OCTOBER 24');
    });

    test('formats midnight and noon without a zero hour', () {
      expect(formatTimeLabel(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
      expect(formatTimeLabel(DateTime(2026, 1, 1, 12, 0)), '12:00 PM');
      expect(formatTimeLabel(DateTime(2026, 1, 1, 17)), '05:00 PM');
    });

    test('greets by first name, and neutrally when there is none', () {
      expect(greetingFor(now, 'Martín Herrera'), 'Good morning,\nMartín');
      expect(greetingFor(now, '  '), 'Good morning,\ngardener');
      expect(greetingFor(now, null), 'Good morning,\ngardener');
    });

    test('ritual pill falls back to an all-clear', () {
      expect(ritualPillLabel(null), 'All\ncaught up');
      expect(
        ritualPillLabel(_reminder(dueAt: DateTime(2026, 10, 3, 8, 30))),
        'Morning\nwatering',
      );
    });
  });

  group('careTaskFrom', () {
    test('prefers the plant name and the reminder instructions', () {
      final task = careTaskFrom(
        _reminder(dueAt: now, instructions: '150ml at the base'),
        _plant(),
        now: now,
      );

      expect(task.plantName, 'Queen Monstera');
      expect(task.instruction, '150ml at the base');
      expect(task.category, CareCategory.hydration);
    });

    test('falls back to the reminder title when the plant is not loaded', () {
      final task = careTaskFrom(_reminder(dueAt: now), null, now: now);

      expect(task.plantName, 'Water check');
      expect(task.instruction, 'Check the soil, water if dry');
      expect(task.location, 'Unplaced');
    });

    test('marks a task due only once its time has passed', () {
      expect(
        careTaskFrom(
          _reminder(dueAt: now.add(const Duration(hours: 1))),
          null,
          now: now,
        ).isDueNow,
        isFalse,
      );
      expect(careTaskFrom(_reminder(dueAt: now), null, now: now).isDueNow,
          isTrue);
    });
  });

  group('careActionsToday', () {
    test('counts each kind of care separately, and only for today', () {
      final plants = [
        _plant(
          currentCare: PlantCurrentCare(
            lastWateredAt: now,
            lastFertilizedAt: now,
            lastPrunedAt: now.subtract(const Duration(days: 2)),
          ),
        ),
        _plant(id: 'p2', currentCare: PlantCurrentCare(lastWateredAt: now)),
      ];

      expect(careActionsToday(plants, now: now), 3);
    });

    test('is zero for an untended garden', () {
      expect(careActionsToday([_plant()], now: now), 0);
    });
  });

  group('growingPlantFrom', () {
    test('an unhealthy plant outranks a young one in the badge', () {
      final card = growingPlantFrom(
        _plant(health: PlantHealth.needsAttention, age: PlantAgeStage.seedling),
        now: now,
      );

      expect(card.badge, 'Needs attention');
      expect(card.tone, PlantStatusTone.blooming);
    });

    test('shows light position until a watering schedule exists', () {
      expect(
        growingPlantFrom(_plant(), now: now).condition.label,
        'Light unset',
      );
      expect(
        growingPlantFrom(
          _plant(
            nextActions: PlantNextActions(
              nextWaterCheckAt: now.subtract(const Duration(days: 1)),
            ),
          ),
          now: now,
        ).condition.label,
        'Water due',
      );
    });

    test('falls back to the species id when no name is cached', () {
      final card = growingPlantFrom(_plant(), now: now);
      expect(card.species, 'Monstera deliciosa');
    });
  });
}
