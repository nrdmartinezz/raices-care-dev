import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/firestore_values.dart';
import 'care_task_type.dart';

/// How a reminder recurs, and who decided so.
class ReminderSchedule {
  const ReminderSchedule({
    this.mode = ScheduleMode.manual,
    this.source = ScheduleSource.user,
    this.careProfileId,
    this.intervalDays,
  });

  final ScheduleMode mode;
  final ScheduleSource source;
  final String? careProfileId;

  /// Cadence used when rolling the reminder forward after a care event.
  final int? intervalDays;

  factory ReminderSchedule.fromMap(Map<String, dynamic> map) =>
      ReminderSchedule(
        mode: ScheduleMode.fromWire(map['mode']),
        source: ScheduleSource.fromWire(map['source']),
        careProfileId: FirestoreValue.text(map['careProfileId']),
        intervalDays: FirestoreValue.integer(map['intervalDays']),
      );

  Map<String, Object?> toMap() => {
    'mode': mode.wire,
    'source': source.wire,
    'careProfileId': careProfileId,
    'intervalDays': intervalDays,
  };
}

/// A scheduled task at /users/{uid}/reminders/{reminderId}.
///
/// Two kinds live here. Reminders seeded from a species care profile are
/// written by `addPlantToChores` with a deterministic id of
/// `{plantId}__{taskType}`, and are rolled forward rather than completed when
/// their care event is logged. Reminders a user adds by hand carry
/// `schedule.source == user`, which is the only value the rules let a client
/// write.
class Reminder {
  const Reminder({
    required this.id,
    required this.plantId,
    required this.taskType,
    required this.title,
    required this.dueAt,
    this.speciesId,
    this.instructions,
    this.status = ReminderStatus.open,
    this.priority = ReminderPriority.normal,
    this.schedule = const ReminderSchedule(),
    this.completedAt,
    this.snoozedUntil,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String plantId;
  final ReminderTaskType taskType;
  final String title;
  final DateTime dueAt;
  final String? speciesId;
  final String? instructions;
  final ReminderStatus status;
  final ReminderPriority priority;
  final ReminderSchedule schedule;
  final DateTime? completedAt;
  final DateTime? snoozedUntil;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDue =>
      status == ReminderStatus.open && !dueAt.isAfter(DateTime.now());

  /// True for reminders the scheduler owns, which the user cannot re-point at
  /// another plant.
  bool get isFromCareProfile => schedule.source == ScheduleSource.careProfile;

  /// A chore belonging to this plant, whether the server wrote it or the app did.
  ///
  /// Server copies use [ScheduleSource.careProfile]. Copies written from the
  /// app use the id `{plantId}__{taskType}`, because the rules only let a
  /// client create reminders whose source is `user`.
  bool isPlantChore(String plantId) =>
      isFromCareProfile || id.startsWith('${plantId}__');

  factory Reminder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.requireData();
    return Reminder(
      id: snapshot.id,
      plantId: FirestoreValue.requireText(data['plantId'], 'plantId'),
      taskType: ReminderTaskType.fromWire(data['taskType']),
      title: FirestoreValue.text(data['title']) ?? 'Care task',
      dueAt: FirestoreValue.requireDateTime(data['dueAt'], 'dueAt'),
      speciesId: FirestoreValue.text(data['speciesId']),
      instructions: FirestoreValue.text(data['instructions']),
      status: ReminderStatus.fromWire(data['status']),
      priority: ReminderPriority.fromWire(data['priority']),
      schedule: ReminderSchedule.fromMap(FirestoreValue.map(data['schedule'])),
      completedAt: FirestoreValue.dateTime(data['completedAt']),
      snoozedUntil: FirestoreValue.dateTime(data['snoozedUntil']),
      createdAt: FirestoreValue.dateTime(data['createdAt']),
      updatedAt: FirestoreValue.dateTime(data['updatedAt']),
    );
  }

  /// Only valid for user-created reminders. The rules reject a client create
  /// whose `schedule.source` is anything but `user`.
  Map<String, Object?> toCreateJson() => {
    'plantId': plantId,
    'speciesId': speciesId,
    'taskType': taskType.wire,
    'title': title,
    'instructions': instructions,
    'dueAt': Timestamp.fromDate(dueAt),
    'status': status.wire,
    'priority': priority.wire,
    'schedule': ReminderSchedule(
      mode: schedule.mode,
      source: ScheduleSource.user,
      careProfileId: schedule.careProfileId,
      intervalDays: schedule.intervalDays,
    ).toMap(),
    'completedAt': null,
    'snoozedUntil': null,
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
    'schemaVersion': kSchemaVersion,
  };
}
