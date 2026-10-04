/// Care vocabulary shared by species care profiles and user reminders.
///
/// The wire values are the strings the Firestore rules validate against, so
/// they must stay in step with functions/src/schema.ts.
library;

enum ReminderTaskType {
  waterCheck('water_check'),
  fertilize('fertilize'),
  prune('prune'),
  repot('repot'),
  pestCheck('pest_check'),
  harvest('harvest'),
  seasonalTask('seasonal_task'),
  custom('custom');

  const ReminderTaskType(this.wire);
  final String wire;

  static ReminderTaskType fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => ReminderTaskType.custom,
  );
}

enum ReminderPriority {
  low('low'),
  normal('normal'),
  high('high');

  const ReminderPriority(this.wire);
  final String wire;

  static ReminderPriority fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => ReminderPriority.normal,
  );
}

enum ReminderStatus {
  open('open'),
  completed('completed'),
  skipped('skipped'),
  snoozed('snoozed'),
  expired('expired'),
  cancelled('cancelled');

  const ReminderStatus(this.wire);
  final String wire;

  static ReminderStatus fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => ReminderStatus.open,
  );
}

/// Where a reminder's schedule came from.
///
/// The Firestore rules only let a client create reminders with
/// [ScheduleSource.user]; the others are written by Cloud Functions.
enum ScheduleSource {
  careProfile('care_profile'),
  user('user'),
  system('system');

  const ScheduleSource(this.wire);
  final String wire;

  static ScheduleSource fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => ScheduleSource.user,
  );
}

enum ScheduleMode {
  conditionBased('condition_based'),
  interval('interval'),
  seasonal('seasonal'),
  manual('manual');

  const ScheduleMode(this.wire);
  final String wire;

  static ScheduleMode fromWire(Object? raw) => values.firstWhere(
    (value) => value.wire == raw,
    orElse: () => ScheduleMode.manual,
  );
}
