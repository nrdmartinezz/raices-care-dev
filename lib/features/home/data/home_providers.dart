import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository.dart';
import '../../care/data/reminder_repository.dart';
import '../../care/domain/reminder.dart';
import '../../photos/data/photo_repository.dart';
import '../../plants/data/plant_repository.dart';
import '../../plants/domain/plant.dart';
import '../domain/care_task.dart';
import '../domain/growing_plant.dart';
import 'home_mappers.dart';

/// The clock the home screen reads.
///
/// Overridable so tests can pin a time, since nearly every label here —
/// greeting, due state, progress — is derived from "now".
final nowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Reminders still open and due by the end of today.
final todaysRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  if (ref.watch(currentUserIdProvider) == null) {
    return Stream.value(const []);
  }
  final now = ref.watch(nowProvider);
  final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
  return ref.watch(reminderRepositoryProvider).watchDue(asOf: endOfDay);
});

/// The date line and greeting above the weather strip.
final greetingProvider = Provider<({String date, String greeting})>((ref) {
  final now = ref.watch(nowProvider);
  final profile = ref.watch(userProfileProvider).valueOrNull;
  return (
    date: formatDateLabel(now),
    greeting: greetingFor(now, profile?.displayName),
  );
});

/// Label for the mint pill: the next thing due, or an all-clear.
final ritualPillProvider = Provider<String>((ref) {
  final reminders = ref.watch(todaysRemindersProvider).valueOrNull;
  final now = ref.watch(nowProvider);
  final upcoming = reminders?.where((r) => r.dueAt.isAfter(now));
  return ritualPillLabel(
    (upcoming != null && upcoming.isNotEmpty)
        ? upcoming.first
        : reminders?.firstOrNull,
  );
});

class RitualSummary {
  const RitualSummary({
    required this.tasks,
    required this.doneCount,
    required this.totalCount,
  });

  final List<CareTask> tasks;
  final int doneCount;
  final int totalCount;

  double get progress => totalCount == 0 ? 0 : doneCount / totalCount;

  String get progressLabel => totalCount == 0
      ? 'Nothing scheduled'
      : '$doneCount of $totalCount tasks done';
}

/// Today's Ritual: the open tasks, plus how many are already behind them.
///
/// Completed work is counted from the plants rather than listed, because the
/// `onCareEventCreated` trigger rolls a finished reminder forward to its next
/// due date instead of leaving it on today's list.
final ritualSummaryProvider = Provider<AsyncValue<RitualSummary>>((ref) {
  final remindersAsync = ref.watch(todaysRemindersProvider);
  final plantsAsync = ref.watch(activePlantsProvider);
  final now = ref.watch(nowProvider);

  final reminders = remindersAsync.valueOrNull;
  final plants = plantsAsync.valueOrNull;

  if (reminders == null || plants == null) {
    // Surface whichever stream is still loading or has failed.
    return remindersAsync.isLoading || plantsAsync.isLoading
        ? const AsyncValue.loading()
        : (remindersAsync.hasError ? remindersAsync : plantsAsync).map(
            data: (_) => const AsyncValue.loading(),
            error: (e) => AsyncValue.error(e.error, e.stackTrace),
            loading: (_) => const AsyncValue.loading(),
          );
  }

  final byId = {for (final plant in plants) plant.id: plant};
  final tasks = [
    for (final reminder in reminders)
      careTaskFrom(reminder, byId[reminder.plantId], now: now),
  ];
  final done = careActionsToday(plants, now: now);

  return AsyncValue.data(
    RitualSummary(
      tasks: tasks,
      doneCount: done,
      totalCount: done + tasks.length,
    ),
  );
});

/// The Growing Now cards.
final growingNowProvider = Provider<AsyncValue<List<GrowingPlant>>>((ref) {
  final now = ref.watch(nowProvider);
  return ref
      .watch(activePlantsProvider)
      .whenData(
        (plants) => [
          for (final plant in plants) growingPlantFrom(plant, now: now),
        ],
      );
});

/// Total active plants, for the "View all N" link.
final activePlantCountProvider = Provider<int>(
  (ref) => ref.watch(activePlantsProvider).valueOrNull?.length ?? 0,
);

/// Resolves a cover photo's Storage path to an image.
///
/// Download URLs are time-limited, so only the path is stored and the URL is
/// fetched when a card actually needs it. Keeping this in a provider means the
/// result is cached for as long as a card is on screen.
final plantCoverImageProvider = FutureProvider.family<ImageProvider?, String>((
  ref,
  storagePath,
) async {
  final url = await ref.watch(photoRepositoryProvider).downloadUrl(storagePath);
  return NetworkImage(url);
});

/// Convenience view of whether the garden is empty, used to pick between the
/// plant list and the first-plant prompt.
final hasPlantsProvider = Provider<bool>(
  (ref) => (ref.watch(activePlantsProvider).valueOrNull ?? const []).isNotEmpty,
);

typedef PlantsAsync = AsyncValue<List<Plant>>;
