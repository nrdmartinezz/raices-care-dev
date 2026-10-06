import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/api/authenticated_image.dart';
import '../../../core/firebase/firebase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../care/data/reminder_repository.dart';
import '../../care/domain/reminder.dart';
import '../../photos/data/image_revision.dart';
import '../../photos/domain/garden_image_url.dart';
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
  final profile = ref.watch(userProfileProvider).value;
  return (
    date: formatDateLabel(now),
    greeting: greetingFor(now, profile?.displayName),
  );
});

/// Label for the mint pill: the next thing due, an all-clear, or a prompt
/// to add a plant. Blank until both streams have a value, so a loading
/// garden is not announced as empty or caught up.
final ritualPillProvider = Provider<String>((ref) {
  final plants = ref.watch(activePlantsProvider).value;
  final reminders = ref.watch(todaysRemindersProvider).value;
  if (plants == null || reminders == null) {
    return '';
  }
  final now = ref.watch(nowProvider);
  final upcoming = reminders.where((r) => r.dueAt.isAfter(now));
  return ritualPillLabel(
    upcoming.isNotEmpty ? upcoming.first : reminders.firstOrNull,
    hasPlants: plants.isNotEmpty,
  );
});

class RitualSummary {
  const RitualSummary({
    required this.tasks,
    required this.doneCount,
    required this.totalCount,
    required this.hasPlants,
  });

  final List<CareTask> tasks;
  final int doneCount;
  final int totalCount;

  /// False when the garden has no plants, which is a different empty state
  /// from a tended garden with nothing due.
  final bool hasPlants;

  /// Full when plants exist and nothing is open, so the bar does not sit
  /// empty under "All done". Zero when there is no garden yet.
  double get progress {
    if (!hasPlants) {
      return 0;
    }
    if (tasks.isEmpty) {
      return 1;
    }
    return totalCount == 0 ? 0 : doneCount / totalCount;
  }

  /// Null when there is no garden, so the heading stays bare and the card
  /// carries the reason. "All done" when plants exist and nothing is open.
  String? get progressLabel {
    if (!hasPlants) {
      return null;
    }
    if (tasks.isEmpty) {
      return 'All done';
    }
    return '$doneCount of $totalCount tasks done';
  }
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

  // Either stream failing fails the section; neither is optional here.
  final error = remindersAsync.error ?? plantsAsync.error;
  if (error != null) {
    return AsyncValue.error(
      error,
      remindersAsync.stackTrace ?? plantsAsync.stackTrace ?? StackTrace.empty,
    );
  }

  final reminders = remindersAsync.value;
  final plants = plantsAsync.value;
  if (reminders == null || plants == null) {
    return const AsyncValue.loading();
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
      hasPlants: plants.isNotEmpty,
    ),
  );
});

/// The Growing Now cards.
///
/// A list that has already arrived is kept across a reload or a later error,
/// so the cards do not vanish when the stream re-subscribes. An error that
/// only still holds an empty list stays an error: that is a failed read, not
/// an empty garden. [AsyncValue.whenData] drops the previous value in both of
/// those cases, which is why this does not use it.
final growingNowProvider = Provider<AsyncValue<List<GrowingPlant>>>((ref) {
  final now = ref.watch(nowProvider);
  final plants = ref.watch(activePlantsProvider);

  List<GrowingPlant> cards(List<Plant> list) => [
    for (final plant in list) growingPlantFrom(plant, now: now),
  ];

  final value = plants.value;
  if (value != null && (value.isNotEmpty || !plants.hasError)) {
    return AsyncData(cards(value));
  }
  if (plants.hasError) {
    return AsyncError(plants.error!, plants.stackTrace ?? StackTrace.empty);
  }
  return const AsyncLoading();
});

/// Total active plants, for the "View all N" link.
final activePlantCountProvider = Provider<int>(
  (ref) => ref.watch(activePlantsProvider).value?.length ?? 0,
);

/// Resolves a cover photo. Worker photos are streamed with the ID token.
/// Public R2 URLs remain for plants saved before that switch.
final plantCoverImageProvider = Provider.family<ImageProvider, String>((
  ref,
  storagePath,
) {
  if (storagePath.startsWith(workerPhotoPrefix)) {
    final id = storagePath.substring(workerPhotoPrefix.length);
    return AuthenticatedImage(ref.watch(apiClientProvider), '/v1/photos/$id');
  }
  final version = ref.watch(imageRevisionProvider)[storagePath];
  return NetworkImage(gardenImageUrl(storagePath, version: version));
});

/// Convenience view of whether the garden is empty, used to pick between the
/// plant list and the first-plant prompt.
final hasPlantsProvider = Provider<bool>(
  (ref) => (ref.watch(activePlantsProvider).value ?? const []).isNotEmpty,
);
