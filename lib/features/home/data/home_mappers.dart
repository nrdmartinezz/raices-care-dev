/// Turns domain models into the view models the home widgets already draw.
///
/// Kept as free functions with no Firebase or Riverpod imports, so the shaping
/// rules can be read and tested on their own.
library;

import 'package:flutter/widgets.dart';

import '../../../app/assets.dart';
import '../../care/domain/care_task_type.dart';
import '../../care/domain/reminder.dart';
import '../../plants/domain/plant.dart';
import '../domain/care_task.dart';
import '../domain/growing_plant.dart';

const _weekdays = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

const _months = [
  'JANUARY',
  'FEBRUARY',
  'MARCH',
  'APRIL',
  'MAY',
  'JUNE',
  'JULY',
  'AUGUST',
  'SEPTEMBER',
  'OCTOBER',
  'NOVEMBER',
  'DECEMBER',
];

/// "THURSDAY, OCTOBER 24".
String formatDateLabel(DateTime date) =>
    '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';

/// "08:30 AM".
String formatTimeLabel(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  return '${hour.toString().padLeft(2, '0')}:$minute '
      '${time.hour < 12 ? 'AM' : 'PM'}';
}

String _partOfDay(DateTime time) => switch (time.hour) {
  < 12 => 'Morning',
  < 18 => 'Afternoon',
  _ => 'Evening',
};

/// "Good morning,\nMartín". Falls back to a neutral address when the profile
/// has no name, which is the case until the user sets one.
String greetingFor(DateTime now, String? displayName) {
  final firstName = displayName?.trim().split(RegExp(r'\s+')).first;
  final name = (firstName == null || firstName.isEmpty)
      ? 'gardener'
      : firstName;
  return 'Good ${_partOfDay(now).toLowerCase()},\n$name';
}

/// Label for the mint pill beside the greeting.
///
/// An empty garden is not caught up. [hasPlants] has to be known; callers
/// should wait until the plant list has arrived.
String ritualPillLabel(Reminder? next, {required bool hasPlants}) {
  if (!hasPlants) {
    return 'Add a\nplant';
  }
  if (next == null) {
    return 'All\ncaught up';
  }
  return '${_partOfDay(next.dueAt)}\n${_taskNoun(next.taskType)}';
}

String _taskNoun(ReminderTaskType type) => switch (type) {
  ReminderTaskType.waterCheck => 'watering',
  ReminderTaskType.fertilize => 'feeding',
  ReminderTaskType.prune => 'pruning',
  ReminderTaskType.repot => 'repotting',
  ReminderTaskType.pestCheck => 'inspection',
  ReminderTaskType.harvest => 'harvest',
  ReminderTaskType.seasonalTask => 'seasonal care',
  ReminderTaskType.custom => 'care',
};

/// Shown when a reminder carries no instructions of its own.
String _defaultInstruction(ReminderTaskType type) => switch (type) {
  ReminderTaskType.waterCheck => 'Check the soil, water if dry',
  ReminderTaskType.fertilize => 'Feed at half strength',
  ReminderTaskType.prune => 'Trim spent growth',
  ReminderTaskType.repot => 'Move up one pot size',
  ReminderTaskType.pestCheck => 'Check leaf undersides for pests',
  ReminderTaskType.harvest => 'Harvest what is ready',
  ReminderTaskType.seasonalTask => 'Seasonal care',
  ReminderTaskType.custom => 'Tend to this plant',
};

String _locationLabel(Plant? plant) => switch (plant?.locationType) {
  LocationType.indoor => 'Indoors',
  LocationType.outdoor => 'Outdoors',
  LocationType.greenhouse => 'Greenhouse',
  LocationType.other || null => 'Unplaced',
};

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Builds one checklist row.
///
/// [plant] is the reminder's plant when it is loaded. It can be absent while
/// the two streams are out of step, so the reminder's own title stands in.
CareTask careTaskFrom(
  Reminder reminder,
  Plant? plant, {
  required DateTime now,
}) {
  return CareTask(
    plantName: plant?.displayName ?? reminder.title,
    time: formatTimeLabel(reminder.dueAt),
    instruction:
        reminder.instructions ?? _defaultInstruction(reminder.taskType),
    category: CareCategory.forTaskType(reminder.taskType),
    location: _locationLabel(plant),
    isDone: reminder.status != ReminderStatus.open,
    isDueNow: !reminder.dueAt.isAfter(now),
  );
}

/// Care actions already recorded today, across every plant.
///
/// Read off each plant's `currentCare` rather than by querying care events: a
/// collection-group query over the history would need its own security rule,
/// and the trigger has already rolled these timestamps forward for us.
int careActionsToday(List<Plant> plants, {required DateTime now}) {
  var count = 0;
  for (final plant in plants) {
    final care = plant.currentCare;
    for (final at in [
      care.lastWateredAt,
      care.lastFertilizedAt,
      care.lastPrunedAt,
      care.lastRepottedAt,
      care.lastPestInspectionAt,
    ]) {
      if (at != null && isSameDay(at, now)) {
        count++;
      }
    }
  }
  return count;
}

/// Builds one Growing Now card.
GrowingPlant growingPlantFrom(Plant plant, {required DateTime now}) {
  final (badge, tone) = _statusBadge(plant);
  return GrowingPlant(
    coverPhotoPath: plant.coverPhotoPath,
    badge: badge,
    tone: tone,
    name: plant.displayName,
    species: plant.speciesNameSnapshot ?? plant.speciesId,
    vitality: _vitalityStat(plant),
    condition: _conditionStat(plant, now: now),
  );
}

(String, PlantStatusTone) _statusBadge(Plant plant) {
  if (plant.status.health == PlantHealth.needsAttention) {
    return ('Needs attention', PlantStatusTone.blooming);
  }
  if (plant.status.health == PlantHealth.recovering) {
    return ('Recovering', PlantStatusTone.blooming);
  }
  if (plant.plantAgeStage == PlantAgeStage.seed ||
      plant.plantAgeStage == PlantAgeStage.seedling) {
    return ('New sprout', PlantStatusTone.fresh);
  }
  if (plant.status.health == PlantHealth.healthy) {
    return ('Thriving', PlantStatusTone.fresh);
  }
  return ('Settling in', PlantStatusTone.harvest);
}

PlantStat _vitalityStat(Plant plant) => switch (plant.status.health) {
  PlantHealth.healthy => const PlantStat(
    icon: AppIcons.statVigor,
    iconSize: Size(13.333, 12),
    label: 'Thriving',
  ),
  PlantHealth.recovering => const PlantStat(
    icon: AppIcons.statHealth,
    iconSize: Size(10.667, 12.667),
    label: 'Recovering',
  ),
  PlantHealth.needsAttention => const PlantStat(
    icon: AppIcons.statHealth,
    iconSize: Size(10.667, 12.667),
    label: 'Needs care',
  ),
  PlantHealth.unknown => const PlantStat(
    icon: AppIcons.statHealth,
    iconSize: Size(10.667, 12.667),
    label: 'Not checked',
  ),
};

/// The right-hand readout: watering status when the schedule knows, otherwise
/// the plant's light position, which is always known.
PlantStat _conditionStat(Plant plant, {required DateTime now}) {
  final nextWater = plant.nextActions.nextWaterCheckAt;
  if (nextWater == null) {
    return PlantStat(
      icon: AppIcons.statSun,
      iconSize: const Size(14.667, 14.667),
      label: _sunLabel(plant.environment.sunExposure),
    );
  }
  return PlantStat(
    icon: AppIcons.statMoisture,
    iconSize: const Size(10.667, 13.333),
    label: nextWater.isAfter(now) ? 'Moist' : 'Water due',
  );
}

String _sunLabel(SunExposure exposure) => switch (exposure) {
  SunExposure.fullSun => 'Full sun',
  SunExposure.partialSun => 'Partial sun',
  SunExposure.partialShade => 'Part shade',
  SunExposure.fullShade => 'Full shade',
  SunExposure.brightIndirect => 'Bright indirect',
  SunExposure.lowLight => 'Low light',
  SunExposure.unknown => 'Light unset',
};
