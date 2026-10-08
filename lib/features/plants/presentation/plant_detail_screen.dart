import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/assets.dart';
import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_exception.dart';
import '../../care/data/care_event_repository.dart';
import '../../care/data/reminder_repository.dart';
import '../../care/domain/care_event.dart';
import '../../care/domain/care_task_type.dart';
import '../../care/domain/reminder.dart';
import '../../home/data/home_providers.dart';
import '../../planting/data/planting_repository.dart';
import '../../planting/domain/harvest_countdown.dart';
import '../../planting/domain/sowing_calendar.dart';
import '../../planting/presentation/sowing_calendar_section.dart';
import '../data/observation_repository.dart';
import '../data/plant_repository.dart';
import '../data/species_repository.dart';
import '../domain/care_profile.dart';
import '../domain/garden_spot.dart';
import '../domain/observation.dart';
import '../domain/plant.dart';
import '../domain/species.dart';
import 'add_plant_flow.dart';
import 'care_labels.dart';

/// One plant: what it is, where it lives, what it needs next, and the notes
/// kept about it.
///
/// Chores are opt-in. Adding the plant to the schedule writes reminders from
/// its catalog care profile, and the open-reminder stream fills this page in.
class PlantDetailScreen extends ConsumerStatefulWidget {
  const PlantDetailScreen({
    super.key,
    required this.plantId,
    this.isNew = false,
  });

  final String plantId;

  /// True when arriving straight from the add-plant flow, which is the only
  /// time the confirmation banner is shown.
  final bool isNew;

  @override
  ConsumerState<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends ConsumerState<PlantDetailScreen> {
  late bool _showBanner = widget.isNew;
  var _removing = false;
  var _scheduling = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final plantAsync = ref.watch(plantProvider(widget.plantId));

    return ShellScrollView(
      // The plant wins over the spinner whenever one has arrived, since a
      // re-subscribing stream reports `AsyncLoading` while still holding it.
      // `hasValue` with a null plant is the different case: loaded and gone.
      child: switch (plantAsync) {
        AsyncValue(value: final plant?) => _body(plant),
        AsyncError(:final error) => _Notice(
          title: 'This plant could not load',
          body: error is AppException
              ? error.message
              : 'Something went wrong reading your garden.',
        ),
        AsyncValue(hasValue: true) => const _Notice(
          title: 'Plant not found',
          body: 'It may have been removed from your garden.',
        ),
        _ => const Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }

  Widget _body(Plant plant) {
    final species = ref.watch(speciesProvider(plant.speciesId)).value;
    final profiles = ref.watch(careProfilesProvider(plant.speciesId)).value;
    final reminders =
        ref.watch(plantRemindersProvider(plant.id)).value ?? const <Reminder>[];
    final waterTask = _waterTask(profiles);
    // Every date on this screen is read as "how far from now", so the clock
    // comes from the provider the rest of the app pins in tests.
    final now = ref.watch(nowProvider);
    final calendarAsync = ref.watch(sowingForSpeciesProvider(plant.speciesId));
    final calendar = calendarAsync.value;
    final harvestDays = _harvestDays(calendarAsync, species);
    final remaining = HarvestCountdown.remainingDays(
      daysToHarvest: harvestDays,
      createdAt: plant.createdAt,
      now: now,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showBanner) ...[
          _AddedBanner(
            name: plant.displayName,
            onDismiss: () => setState(() => _showBanner = false),
          ),
          const SizedBox(height: AppSizes.sectionGap),
        ],
        _Hero(plant: plant, species: species),
        const SizedBox(height: AppSizes.sectionGap),
        _Stats(plant: plant),
        const SizedBox(height: AppSizes.sectionGap),
        _QuickActions(
          onWater: () => _logWatering(plant),
          onNote: () => _writeNote(plant),
        ),
        if (_error case final message?) ...[
          const SizedBox(height: 12),
          Text(
            message,
            style: AppText.body.copyWith(color: AppColors.terracottaBright),
          ),
        ],
        const SizedBox(height: AppSizes.sectionGap),
        _NextCare(
          plant: plant,
          reminders: reminders,
          waterTask: waterTask,
          now: now,
          isBusy: _scheduling,
          onAdd: () => _addToChores(plant),
          onRemove: () => _removeFromChores(plant, reminders),
        ),
        if (remaining != null) ...[
          const SizedBox(height: AppSizes.sectionGap),
          _HarvestCountdown(days: remaining),
        ],
        const SizedBox(height: AppSizes.sectionGap),
        _CareGuide(species: species, waterTask: waterTask, calendar: calendar),
        const SizedBox(height: AppSizes.sectionGap),
        _Upcoming(reminders: reminders, now: now),
        const SizedBox(height: AppSizes.sectionGap),
        _Journal(plantId: plant.id, now: now, onAdd: () => _writeNote(plant)),
        const SizedBox(height: AppSizes.sectionGap),
        _AddAnother(onTap: () => context.pushNamed(AddPlantRoute.name)),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: _removing ? null : () => _confirmRemove(plant),
            child: Text(
              _removing ? 'Removing…' : 'Remove plant',
              style: AppText.titleSemiBold.copyWith(
                color: AppColors.terracotta,
              ),
            ),
          ),
        ),
        if (species?.attribution case final attribution?) ...[
          const SizedBox(height: 16),
          Text(
            attribution.text,
            style: AppText.caption.copyWith(color: AppColors.muted),
          ),
        ],
      ],
    );
  }

  /// The watering entry of the first care profile, which is what the catalog
  /// derivation writes. Null until `resolveSpecies` has run for the species.
  CareProfileTask? _waterTask(List<CareProfile>? profiles) {
    for (final profile in profiles ?? const <CareProfile>[]) {
      for (final task in profile.tasks) {
        if (task.taskType == ReminderTaskType.waterCheck) {
          return task;
        }
      }
    }
    return null;
  }

  /// Resolves the species when its care profile is missing, then writes the
  /// chores from that profile. A fresh catalog cache is reused.
  Future<void> _addToChores(Plant plant) async {
    if (_scheduling) {
      return;
    }
    setState(() {
      _scheduling = true;
      _error = null;
    });
    try {
      final profiles = ref.read(careProfilesProvider(plant.speciesId)).value;
      final needsResolve =
          plant.catalogStatus == CatalogStatus.speciesMissing ||
          profiles == null ||
          profiles.isEmpty ||
          profiles.every((profile) => profile.tasks.isEmpty);
      if (needsResolve && plant.speciesId.isNotEmpty) {
        await ref
            .read(speciesRepositoryProvider)
            .resolve(speciesId: plant.speciesId);
        ref.invalidate(careProfilesProvider(plant.speciesId));
      }
      final resolved = await ref.read(
        careProfilesProvider(plant.speciesId).future,
      );
      await ref
          .read(reminderRepositoryProvider)
          .addPlantToChores(
            plantId: plant.id,
            speciesId: plant.speciesId.isEmpty ? null : plant.speciesId,
            profiles: resolved,
          );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _scheduling = false);
      }
    }
  }

  /// Deletes the care chores. Logged care stays on the plant.
  Future<void> _removeFromChores(Plant plant, List<Reminder> reminders) async {
    if (_scheduling) {
      return;
    }
    final ids = [
      for (final reminder in reminders)
        if (reminder.isPlantChore(plant.id)) reminder.id,
    ];
    if (ids.isEmpty) {
      return;
    }
    setState(() {
      _scheduling = true;
      _error = null;
    });
    try {
      await ref.read(reminderRepositoryProvider).removePlantChores(ids);
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _scheduling = false);
      }
    }
  }

  /// Logging the event is the only way to move the plant's care dates: the
  /// `onCareEventCreated` trigger updates the plant and rolls the reminder
  /// forward, so nothing is written here but the event.
  Future<void> _confirmRemove(Plant plant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Remove ${plant.displayName}?',
          style: AppText.cardTitle.copyWith(color: AppColors.ink),
        ),
        content: Text(
          'This removes the plant, its photos, notes, and reminders.',
          style: AppText.body.copyWith(color: AppColors.body),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Keep',
              style: AppText.label.copyWith(color: AppColors.green),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Remove',
              style: AppText.label.copyWith(color: AppColors.terracotta),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _removing = true;
      _error = null;
    });
    try {
      await ref.read(plantRepositoryProvider).deletePlant(plant.id);
      if (!mounted) {
        return;
      }
      context.goNamed(MyPlantsRoute.name);
    } on AppException catch (error) {
      if (mounted) {
        setState(() {
          _removing = false;
          _error = error.message;
        });
      }
    }
  }

  Future<void> _logWatering(Plant plant) async {
    setState(() => _error = null);
    try {
      await ref
          .read(careEventRepositoryProvider)
          .logEvent(
            plantId: plant.id,
            event: CareEvent(
              id: '',
              eventType: CareEventType.watered,
              occurredAt: DateTime.now(),
            ),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Watering logged for ${plant.displayName}.')),
        );
      }
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }

  Future<void> _writeNote(Plant plant) async {
    final note = await showNoteSheet(context, plantName: plant.displayName);
    if (note == null || !mounted) {
      return;
    }
    setState(() => _error = null);
    try {
      await ref
          .read(observationRepositoryProvider)
          .add(plantId: plant.id, note: note);
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    }
  }
}

// ------------------------------------------------------------------- sections

class _AddedBanner extends StatelessWidget {
  const _AddedBanner({required this.name, required this.onDismiss});

  final String name;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        children: [
          SvgPicture.asset(AppIcons.profileAddedCheck, width: 22, height: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plant added',
                  style: AppText.subtitleBold.copyWith(color: AppColors.green),
                ),
                const SizedBox(height: 2),
                Text(
                  '$name is in your garden. Add it to chores when you '
                  'want a care rhythm.',
                  style: AppText.caption.copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Dismiss',
            child: GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: SvgPicture.asset(
                AppIcons.profileDismiss,
                width: 14,
                height: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero({required this.plant, required this.species});

  final Plant plant;
  final Species? species;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The gardener's own photo first, then the catalog's, then nothing.
    final path = plant.coverPhotoPath;
    final stored = path == null
        ? null
        : ref.watch(plantCoverImageProvider(path));
    final catalogUrl = species?.imageUrl;
    final scientific = species?.scientificName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
          child: Container(
            height: 200,
            width: double.infinity,
            color: AppColors.surfaceBlush,
            child: switch ((stored, catalogUrl)) {
              (final image?, _) => Image(image: image, fit: BoxFit.cover),
              (_, final url?) when url.isNotEmpty => Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _HeroPlaceholder(),
              ),
              _ => const _HeroPlaceholder(),
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          plant.displayName,
          style: AppText.display.copyWith(color: AppColors.ink),
        ),
        if (scientific != null && scientific != plant.displayName) ...[
          const SizedBox(height: 2),
          Text(
            scientific,
            style: AppText.bodyItalic.copyWith(color: AppColors.body),
          ),
        ],
      ],
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.35,
        child: SvgPicture.asset(AppIcons.growingSprout, width: 36, height: 36),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final garden = GardenSpot.fromWire(plant.gardenId);

    // Intrinsic height so the three tiles match the tallest, which they
    // cannot work out for themselves inside a scroll view.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatTile(
              icon: AppIcons.statGarden,
              label: 'GARDEN',
              value: garden == null ? 'Not set' : gardenSpotLabel(garden),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: AppIcons.statStage,
              label: 'STAGE',
              value: plantStageLabel(plant.plantAgeStage),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StatTile(
              icon: AppIcons.statHealth,
              label: 'CONDITION',
              value: switch (plant.status.health) {
                PlantHealth.healthy => 'Thriving',
                PlantHealth.needsAttention => 'Needs care',
                PlantHealth.recovering => 'Recovering',
                PlantHealth.unknown => 'Not set',
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final String icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(icon, width: 16, height: 16),
          const SizedBox(height: 8),
          Text(label, style: AppText.eyebrow.copyWith(color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppText.subtitleBold.copyWith(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onWater, required this.onNote});

  final VoidCallback onWater;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: AppIcons.actionLogWatering,
            label: 'Log watering',
            isPrimary: true,
            onTap: onWater,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: AppIcons.actionAddNote,
            label: 'Add note',
            isPrimary: false,
            onTap: onNote,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.cardRadius);
    return Material(
      color: isPrimary ? AppColors.terracotta : AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: isPrimary ? AppColors.terracotta : AppColors.border,
            ),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(icon, width: 16, height: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppText.titleSemiBold.copyWith(
                  color: isPrimary ? AppColors.surface : AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The soonest open reminder, with how far through its cycle the plant is.
class _NextCare extends StatelessWidget {
  const _NextCare({
    required this.plant,
    required this.reminders,
    required this.waterTask,
    required this.now,
    required this.isBusy,
    required this.onAdd,
    required this.onRemove,
  });

  final Plant plant;
  final List<Reminder> reminders;
  final CareProfileTask? waterTask;
  final DateTime now;
  final bool isBusy;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  bool get _onSchedule =>
      reminders.any((reminder) => reminder.isPlantChore(plant.id));

  @override
  Widget build(BuildContext context) {
    final next = reminders.firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          icon: AppIcons.nextCareHeading,
          title: 'Next care moment',
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surfaceWarm,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (next == null)
                Text(
                  'This plant is not on the chores list yet.',
                  style: AppText.bodyLarge.copyWith(color: AppColors.body),
                )
              else ...[
                Row(
                  children: [
                    SvgPicture.asset(
                      AppIcons.nextCareDroplet,
                      width: 18,
                      height: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        next.title,
                        style: AppText.title.copyWith(color: AppColors.ink),
                      ),
                    ),
                    Text(
                      dueLabel(next.dueAt, now: now),
                      style: AppText.label.copyWith(
                        color: next.dueAt.isAfter(now)
                            ? AppColors.green
                            : AppColors.terracotta,
                      ),
                    ),
                  ],
                ),
                if (next.instructions case final instructions?) ...[
                  const SizedBox(height: 8),
                  Text(
                    instructions,
                    style: AppText.bodyLarge.copyWith(color: AppColors.body),
                  ),
                ],
                if (_cycle case final progress?) ...[
                  const SizedBox(height: 12),
                  _Meter(progress: progress),
                  const SizedBox(height: 6),
                  Text(
                    'Since the last watering',
                    style: AppText.caption.copyWith(color: AppColors.body),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              if (_onSchedule) ...[
                Text(
                  'On the schedule',
                  style: AppText.label.copyWith(color: AppColors.green),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: isBusy ? null : onRemove,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isBusy ? 'Removing…' : 'Remove from chores',
                      style: AppText.titleSemiBold.copyWith(
                        color: AppColors.terracotta,
                      ),
                    ),
                  ),
                ),
              ] else
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: isBusy ? null : onAdd,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isBusy ? 'Adding…' : 'Add to chores',
                      style: AppText.titleSemiBold.copyWith(
                        color: AppColors.green,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// How far the plant is through its watering interval, 0 to 1.
  ///
  /// Null until both the cadence and a first watering exist, which is the
  /// usual state for a plant added a minute ago.
  double? get _cycle {
    final interval = waterTask?.intervalDays;
    final last = plant.currentCare.lastWateredAt;
    if (interval == null || interval <= 0 || last == null) {
      return null;
    }
    final elapsed = now.difference(last).inHours / 24;
    return (elapsed / interval).clamp(0, 1).toDouble();
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.pill),
      child: SizedBox(
        height: 7,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: AppColors.track,
          valueColor: const AlwaysStoppedAnimation(AppColors.terracotta),
        ),
      ),
    );
  }
}

/// Watering and light only. The catalog has more, but the rest is reference
/// botany rather than something to act on today.
int? _harvestDays(AsyncValue<SowingCalendar?>? calendar, Species? species) {
  final fallback = species?.growth.daysToHarvest;
  if (calendar == null) return fallback;
  if (calendar.isLoading && !calendar.hasValue) return null;
  return calendar.value?.daysToHarvest ?? fallback;
}

class _HarvestCountdown extends StatelessWidget {
  const _HarvestCountdown({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          HarvestCountdown.label(days),
          style: AppText.title.copyWith(color: AppColors.ink),
        ),
        const SizedBox(height: 4),
        Text(
          'Counted from the day you added this plant.',
          style: AppText.caption.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _CareGuide extends StatelessWidget {
  const _CareGuide({
    required this.species,
    required this.waterTask,
    required this.calendar,
  });

  final Species? species;
  final CareProfileTask? waterTask;
  final SowingCalendar? calendar;

  @override
  Widget build(BuildContext context) {
    final interval = waterTask?.intervalDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(icon: AppIcons.careGuideHeading, title: 'Care guide'),
        if (calendar != null && calendar!.hasWindows) ...[
          const SizedBox(height: 10),
          SowingCalendarSection(calendar: calendar!),
        ],
        const SizedBox(height: 10),
        _CareCard(
          icon: AppIcons.careWatering,
          label: 'WATERING',
          value: interval == null
              ? 'Being worked out'
              : 'Every ${interval == 1 ? 'day' : '$interval days'}',
          hint: waterTask == null
              ? 'A cadence appears once the catalog record is ready.'
              : waterTask!.isDefaultCadence
              ? 'A starting point. Adjust it as you learn the plant.'
              : waterTask!.instructions,
        ),
        const SizedBox(height: 10),
        _CareCard(
          icon: AppIcons.careLight,
          label: 'LIGHT',
          value: lightLabel(species?.growth.light),
          hint: species?.growth.light == null
              ? 'The catalog has no light reading for this species.'
              : null,
        ),
      ],
    );
  }
}

class _CareCard extends StatelessWidget {
  const _CareCard({
    required this.icon,
    required this.label,
    required this.value,
    this.hint,
  });

  final String icon;
  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius + 4),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceBlush,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            ),
            child: SvgPicture.asset(icon, width: 17, height: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppText.eyebrow.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: AppText.subtitleBold.copyWith(color: AppColors.ink),
                ),
                if (hint case final text?) ...[
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: AppText.caption.copyWith(color: AppColors.body),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.reminders, required this.now});

  final List<Reminder> reminders;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // The first is already the headline above.
    final rest = reminders.skip(1).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(icon: AppIcons.upcomingHeading, title: 'Upcoming care'),
        const SizedBox(height: 10),
        if (rest.isEmpty)
          Text(
            'Nothing else is scheduled.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
        for (final reminder in rest) ...[
          _TaskRow(reminder: reminder, now: now),
          if (reminder != rest.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.reminder, required this.now});

  final Reminder reminder;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            switch (reminder.taskType) {
              ReminderTaskType.fertilize => AppIcons.taskFertilize,
              ReminderTaskType.pestCheck => AppIcons.taskPest,
              _ => AppIcons.taskWater,
            },
            width: 16,
            height: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reminder.title,
              style: AppText.subtitleBold.copyWith(color: AppColors.ink),
            ),
          ),
          Text(
            dueLabel(reminder.dueAt, now: now),
            style: AppText.label.copyWith(
              color: reminder.dueAt.isAfter(now)
                  ? AppColors.body
                  : AppColors.terracotta,
            ),
          ),
        ],
      ),
    );
  }
}

class _Journal extends ConsumerWidget {
  const _Journal({
    required this.plantId,
    required this.now,
    required this.onAdd,
  });

  final String plantId;
  final DateTime now;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes =
        ref.watch(plantObservationsProvider(plantId)).value ??
        const <Observation>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionHeading(
                icon: AppIcons.journalHeading,
                title: 'Plant journal',
              ),
            ),
            GestureDetector(
              onTap: onAdd,
              child: Text(
                'Add note',
                style: AppText.label.copyWith(color: AppColors.terracotta),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (notes.isEmpty)
          Text(
            'No notes yet. Write down what you notice and it will be here '
            'next season.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
        for (final note in notes) ...[
          _NoteRow(note: note, now: now),
          if (note != notes.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.now});

  final Observation note;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            writtenLabel(note.observedAt, now: now),
            style: AppText.eyebrow.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            note.note,
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
        ],
      ),
    );
  }
}

class _AddAnother extends StatelessWidget {
  const _AddAnother({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.cardRadius);
    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.terracotta),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(AppIcons.ctaPlus, width: 16, height: 16),
              const SizedBox(width: 8),
              Text(
                'Add another plant',
                style: AppText.titleSemiBold.copyWith(
                  color: AppColors.terracotta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final String icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SvgPicture.asset(icon, width: 16, height: 16),
        const SizedBox(width: 8),
        Text(title, style: AppText.title.copyWith(color: AppColors.ink)),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.display.copyWith(color: AppColors.ink)),
          const SizedBox(height: 8),
          Text(body, style: AppText.bodyLarge.copyWith(color: AppColors.body)),
        ],
      ),
    );
  }
}

/// Asks for a note. Returns null when the gardener backs out.
Future<String?> showNoteSheet(
  BuildContext context, {
  required String plantName,
}) {
  final controller = TextEditingController();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenPadding,
        20,
        AppSizes.screenPadding,
        20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A NOTE ON $plantName'.toUpperCase(),
            style: AppText.eyebrow.copyWith(color: AppColors.terracotta),
          ),
          const SizedBox(height: 8),
          Text(
            'What did you notice?',
            style: AppText.title.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            minLines: 3,
            maxLength: Observation.noteLimit,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.input.copyWith(color: AppColors.ink),
            cursorColor: AppColors.terracotta,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceBlush,
              counterText: '',
              hintText: 'New leaf unfurling, soil dry to a knuckle…',
              hintStyle: AppText.input.copyWith(color: AppColors.muted),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.terracotta,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                ),
              ),
              onPressed: () {
                final note = controller.text.trim();
                Navigator.of(sheetContext).pop(note.isEmpty ? null : note);
              },
              child: Text(
                'Save note',
                style: AppText.title.copyWith(color: AppColors.surface),
              ),
            ),
          ),
        ],
      ),
    ),
  ).whenComplete(controller.dispose);
}
