import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../../core/api/api_providers.dart';
import '../../../core/api/worker_repositories.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../../core/utils/firestore_values.dart';
import '../../plants/domain/care_profile.dart';
import '../domain/care_task_type.dart';
import '../domain/reminder.dart';

/// One user's reminders.
///
/// Care chores are written here from the species care profile. The rules only
/// let a client create reminders with `schedule.source == user`, so each chore
/// uses the id `{plantId}__{taskType}` and that source. Completing, skipping,
/// snoozing, and deleting stay client actions.
class ReminderRepository {
  ReminderRepository({required this._firestore, required this._userId});

  final FirebaseFirestore _firestore;
  final String? _userId;

  /// Open reminders, soonest first.
  ///
  /// The reminders subcollection is listened to whole and filtered here.
  /// `where('status')` plus `orderBy('dueAt')` needs a composite index; until
  /// that index is built the snapshot errors, and both Chores and Today's
  /// Ritual stay on the failure card. One person's list is small enough to
  /// sort in memory, and a plain collection listen does not need that index.
  Stream<List<Reminder>> watchOpen({int limit = 100}) {
    return _sorted().map((reminders) => _take(reminders, limit));
  }

  /// Everything already due, for the Today's Ritual list.
  Stream<List<Reminder>> watchDue({DateTime? asOf, int limit = 100}) {
    final cutoff = asOf ?? DateTime.now();
    return _sorted().map(
      (reminders) => _take(
        [
          for (final reminder in reminders)
            if (!reminder.dueAt.isAfter(cutoff)) reminder,
        ],
        limit,
      ),
    );
  }

  Stream<List<Reminder>> _sorted() {
    return _reminders.snapshots().map((snapshot) {
      final reminders = <Reminder>[];
      for (final doc in snapshot.docs) {
        final reminder = Reminder.fromFirestore(doc);
        if (reminder.status == ReminderStatus.open) {
          reminders.add(reminder);
        }
      }
      reminders.sort((a, b) => a.dueAt.compareTo(b.dueAt));
      return reminders;
    });
  }

  List<Reminder> _take(List<Reminder> reminders, int limit) {
    if (reminders.length <= limit) {
      return reminders;
    }
    return reminders.sublist(0, limit);
  }

  /// Backed by the `plantId, status, dueAt` index.
  Stream<List<Reminder>> watchForPlant(String plantId) {
    return _reminders
        .where('plantId', isEqualTo: plantId)
        .where('status', isEqualTo: ReminderStatus.open.wire)
        .orderBy('dueAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Reminder.fromFirestore).toList());
  }

  /// Writes one open reminder per care-profile task.
  ///
  /// Existing `{plantId}__{taskType}` reminders are left alone, so adding a
  /// plant twice does not reset a chore that is already on the list.
  Future<void> addPlantToChores({
    required String plantId,
    required String? speciesId,
    required List<CareProfile> profiles,
  }) {
    final tasks = [
      for (final profile in profiles)
        for (final task in profile.tasks) (profile: profile, task: task),
    ];
    if (tasks.isEmpty) {
      throw const UnexpectedException(
        'This species has no care rhythm yet. Try again in a moment.',
      );
    }

    return guardFirebase(() async {
      final batch = _firestore.batch();
      final dueBase = DateTime.now();
      var writes = 0;

      for (final entry in tasks) {
        final id = '${plantId}__${entry.task.taskType.wire}';
        final ref = _reminders.doc(id);
        final existing = await ref.get();
        if (existing.exists) {
          continue;
        }
        batch.set(
          ref,
          Reminder(
            id: id,
            plantId: plantId,
            speciesId: speciesId,
            taskType: entry.task.taskType,
            title: entry.task.title,
            instructions: entry.task.instructions,
            dueAt: dueBase.add(Duration(days: entry.task.intervalDays)),
            priority: entry.task.priority,
            schedule: ReminderSchedule(
              mode: ScheduleMode.interval,
              intervalDays: entry.task.intervalDays,
              careProfileId: entry.profile.id,
            ),
          ).toCreateJson(),
        );
        writes += 1;
      }

      if (writes > 0) {
        await batch.commit();
      }
    });
  }

  /// Drops the care-profile reminders that put a plant on the chores list.
  ///
  /// Care events stay. Adding the plant again recreates the reminders.
  Future<void> removePlantChores(Iterable<String> reminderIds) async {
    for (final id in reminderIds) {
      await delete(id);
    }
  }

  /// Adds a reminder the user asked for, as opposed to a derived one.
  Future<String> createManual(Reminder reminder) {
    return guardFirebase(() async {
      final ref = await _reminders.add(reminder.toCreateJson());
      return ref.id;
    });
  }

  /// Marks a reminder done.
  ///
  /// For recurring reminders, prefer logging the matching care event instead:
  /// `onCareEventCreated` rolls the reminder forward to its next due date and
  /// updates the plant at the same time, so the two stay consistent.
  Future<void> complete(String reminderId, {DateTime? completedAt}) {
    return _setStatus(
      reminderId,
      ReminderStatus.completed,
      extra: {'completedAt': Timestamp.fromDate(completedAt ?? DateTime.now())},
    );
  }

  Future<void> skip(String reminderId) =>
      _setStatus(reminderId, ReminderStatus.skipped);

  Future<void> cancel(String reminderId) =>
      _setStatus(reminderId, ReminderStatus.cancelled);

  Future<void> snooze(String reminderId, {required DateTime until}) {
    return _setStatus(
      reminderId,
      ReminderStatus.snoozed,
      extra: {
        'snoozedUntil': Timestamp.fromDate(until),
        // Move the due date too, so the scheduled sweep stops picking it up.
        'dueAt': Timestamp.fromDate(until),
      },
    );
  }

  /// Returns a snoozed or skipped reminder to the open list.
  Future<void> reopen(String reminderId, {required DateTime dueAt}) {
    return _setStatus(
      reminderId,
      ReminderStatus.open,
      extra: {
        'dueAt': Timestamp.fromDate(dueAt),
        'snoozedUntil': null,
        'completedAt': null,
      },
    );
  }

  Future<void> delete(String reminderId) {
    return guardFirebase(() => _reminders.doc(reminderId).delete());
  }

  Future<void> _setStatus(
    String reminderId,
    ReminderStatus status, {
    Map<String, Object?> extra = const {},
  }) {
    return guardFirebase(
      () => _reminders.doc(reminderId).set({
        'status': status.wire,
        ...extra,
        'updatedAt': FieldValue.serverTimestamp(),
        'schemaVersion': kSchemaVersion,
      }, SetOptions(merge: true)),
    );
  }

  CollectionReference<Map<String, dynamic>> get _reminders {
    final uid = _userId;
    if (uid == null) {
      throw const UnauthenticatedException();
    }
    return _firestore.collection('users').doc(uid).collection('reminders');
  }
}

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  final firestore = ref.watch(firestoreProvider);
  if (usesWorkerApi) {
    return WorkerReminderRepository(
      firestore: firestore,
      userId: userId,
      backend: ref.watch(workerBackendProvider),
    );
  }
  return ReminderRepository(firestore: firestore, userId: userId);
});

/// Reminders already due, which is what the home screen's ritual list shows.
final dueRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const []);
  }
  return ref.watch(reminderRepositoryProvider).watchDue();
});

/// Every open reminder, soonest first.
///
/// One query for the whole garden, so a list of plants can show each plant's
/// next task without a read per card.
final openRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const []);
  }
  return ref.watch(reminderRepositoryProvider).watchOpen();
});

/// The soonest open reminder for each plant, keyed by plant id.
final nextReminderByPlantProvider = Provider<Map<String, Reminder>>((ref) {
  final reminders = ref.watch(openRemindersProvider).value ?? const [];
  final soonest = <String, Reminder>{};
  for (final reminder in reminders) {
    final held = soonest[reminder.plantId];
    if (held == null || reminder.dueAt.isBefore(held.dueAt)) {
      soonest[reminder.plantId] = reminder;
    }
  }
  return soonest;
});

/// Open reminders for one plant, soonest first, for its profile.
final plantRemindersProvider = StreamProvider.family<List<Reminder>, String>((
  ref,
  plantId,
) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const []);
  }
  return ref.watch(reminderRepositoryProvider).watchForPlant(plantId);
});
