import '../domain/care_event.dart';
import '../domain/care_task_type.dart';
import 'care_event_repository.dart';
import 'reminder_repository.dart';

/// The care event that rolls a recurring reminder forward.
///
/// Harvest, seasonal, and custom tasks have no mapping. Those are skipped
/// instead of completed, so a profile-owned reminder is not closed for good.
CareEventType? careEventFor(ReminderTaskType type) => switch (type) {
  ReminderTaskType.waterCheck => CareEventType.watered,
  ReminderTaskType.fertilize => CareEventType.fertilized,
  ReminderTaskType.prune => CareEventType.pruned,
  ReminderTaskType.repot => CareEventType.repotted,
  ReminderTaskType.pestCheck => CareEventType.pestInspection,
  ReminderTaskType.harvest ||
  ReminderTaskType.seasonalTask ||
  ReminderTaskType.custom => null,
};

/// Marks a garden chore done.
///
/// Mapped tasks log a care event. `onCareEventCreated` rolls that plant's
/// reminder to the next due date. Unmapped tasks are skipped.
Future<void> recordChore({
  required CareEventRepository events,
  required ReminderRepository reminders,
  required String plantId,
  required String reminderId,
  required ReminderTaskType taskType,
  DateTime? at,
}) {
  final eventType = careEventFor(taskType);
  if (eventType == null) {
    return reminders.skip(reminderId);
  }
  return events.logEvent(
    plantId: plantId,
    event: CareEvent(
      id: '',
      eventType: eventType,
      occurredAt: at ?? DateTime.now(),
    ),
  );
}
