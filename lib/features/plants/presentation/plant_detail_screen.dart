import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
import 'catalog_image.dart';
import '../domain/garden_spot.dart';
import '../domain/observation.dart';
import '../domain/plant.dart';
import '../domain/species.dart';
import 'add_plant_flow.dart';
import 'care_labels.dart';
import 'edit_care_guide_screen.dart';

/// One plant: what it is, where it lives, what it needs next, and the notes
/// kept about it.
///
/// Chores come from the care saved on this plant. A new plant fills that in
/// after it is created, and the gardener can change the cadence.
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
  var _loggingWater = false;
  var _loadingCare = false;
  var _careAttempted = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final plantAsync = ref.watch(plantProvider(widget.plantId));
    ref.listen(plantProvider(widget.plantId), (previous, next) {
      final plant = next.value;
      if (plant == null || !widget.isNew || _careAttempted) return;
      if (plant.careTasks.isNotEmpty) return;
      _careAttempted = true;
      _loadCare(plant.id);
    });

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
    final waterTask = _savedWater(plant) ?? _waterTask(profiles);
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
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.pushNamed(
              PlantEditRoute.name,
              pathParameters: {'plantId': plant.id},
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.terracotta,
              padding: EdgeInsets.zero,
            ),
            child: Text(
              'Edit plant details',
              style: AppText.label.copyWith(color: AppColors.terracotta),
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sectionGap),
        _PlantOverview(
          plant: plant,
          waterTask: waterTask,
          now: now,
          loggingWater: _loggingWater,
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
        _CareGuide(
          plant: plant,
          species: species,
          tasks: plant.careTasks,
          profiles: profiles,
          waterTask: waterTask,
          loading: _loadingCare && plant.careTasks.isEmpty,
          calendar: calendar,
          difficulty: plant.careDifficulty,
          light: plant.careLight,
          sourceUrl: plant.careSourceUrl,
          sourceLabel: plant.careSourceLabel,
          onEditTasks: plant.careTasks.isEmpty ? null : () => _editCare(plant),
          onEditGuide: () => context.pushNamed(
            PlantCareGuideRoute.name,
            pathParameters: {'plantId': plant.id},
          ),
        ),
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

  CareProfileTask? _savedWater(Plant plant) {
    for (final task in plant.careTasks) {
      if (task.taskType == ReminderTaskType.waterCheck) return task;
    }
    return null;
  }

  Future<void> _loadCare(String plantId) async {
    setState(() {
      _loadingCare = true;
      _error = null;
    });
    try {
      await ref.read(plantRepositoryProvider).loadCare(plantId);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loadingCare = false);
    }
  }

  Future<void> _editCare(Plant plant) async {
    final edited = await showDialog<List<CareProfileTask>>(
      context: context,
      builder: (context) => _CareEditDialog(tasks: plant.careTasks),
    );
    if (edited == null || !mounted) return;
    setState(() => _error = null);
    try {
      await ref.read(plantRepositoryProvider).updateCare(plant.id, edited);
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
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
    if (_loggingWater ||
        wateredToday(plant.currentCare.lastWateredAt, ref.read(nowProvider))) {
      return;
    }
    setState(() {
      _error = null;
      _loggingWater = true;
    });
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
    } finally {
      if (mounted) setState(() => _loggingWater = false);
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
    final scientific =
        plant.scientificName ??
        species?.scientificName ??
        plant.speciesNameSnapshot;

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
              (_, final url?) when url.isNotEmpty => CatalogImage(url: url),
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

class _PlantOverview extends StatelessWidget {
  const _PlantOverview({
    required this.plant,
    required this.waterTask,
    required this.now,
    required this.loggingWater,
    required this.onWater,
    required this.onNote,
  });

  final Plant plant;
  final CareProfileTask? waterTask;
  final DateTime now;
  final bool loggingWater;
  final VoidCallback onWater;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final watered = wateredToday(plant.currentCare.lastWateredAt, now);
    return Column(
      children: [
        _Stats(plant: plant, now: now),
        const SizedBox(height: 12),
        _WateringStatus(
          plant: plant,
          waterTask: waterTask,
          now: now,
          watered: watered,
        ),
        const SizedBox(height: 12),
        _QuickActions(
          watered: watered,
          logging: loggingWater,
          onWater: onWater,
          onNote: onNote,
        ),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.plant, required this.now});

  final Plant plant;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final garden = GardenSpot.fromWire(plant.gardenId);
    final born =
        plant.ageFrom ??
        plant.plantedAt ??
        plant.acquiredAt ??
        plant.createdAt;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatChip(
              icon: AppIcons.statPlace,
              iconWash: AppColors.mint,
              background: AppColors.mintSoft,
              value: garden == null ? 'Not set' : gardenSpotLabel(garden),
              caption: garden == null ? 'Place' : gardenSpotHint(garden),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              icon: AppIcons.statAge,
              iconWash: AppColors.surfaceBlush,
              background: AppColors.surfaceWarm,
              value: plant.plantAgeStage == PlantAgeStage.unknown
                  ? (born == null ? 'Not set' : estimatedAgeLabel(born, now))
                  : plantStageLabel(plant.plantAgeStage),
              caption: 'Age',
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatChip(
              icon: AppIcons.statGrowth,
              iconWash: AppColors.mint,
              background: AppColors.mintSoft,
              value: switch (plant.status.health) {
                PlantHealth.healthy => 'Thriving',
                PlantHealth.needsAttention => 'Needs care',
                PlantHealth.recovering => 'Recovering',
                PlantHealth.unknown => 'Not set',
              },
              caption: 'Growth status',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.iconWash,
    required this.background,
    required this.value,
    required this.caption,
  });

  final String icon;
  final Color iconWash;
  final Color background;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconWash,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(icon),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  style: AppText.label.copyWith(
                    color: AppColors.ink,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            caption,
            style: AppText.caption.copyWith(
              color: AppColors.body,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _WateringStatus extends StatelessWidget {
  const _WateringStatus({
    required this.plant,
    required this.waterTask,
    required this.now,
    required this.watered,
  });

  final Plant plant;
  final CareProfileTask? waterTask;
  final DateTime now;
  final bool watered;

  static const _dropletWash = Color(0xFFF4D8C7);
  static const _caption = Color(0xFF8A5A3C);
  static const _fallbackTitle = 'Check soil moisture today';
  static const _fallbackHint = 'Water only if the top 5 cm is dry.';

  @override
  Widget build(BuildContext context) {
    final next = plant.nextActions.nextWaterCheckAt;
    final due = next == null || !next.isAfter(now);
    final title = watered
        ? 'Watered today'
        : due
        ? 'Due for check'
        : dueLabel(next, now: now);
    final detail = watered
        ? nextCheckLabel(next ?? _fallbackNext(now))
        : (waterTask?.title ?? _fallbackTitle);
    final hint = waterTask?.instructions ?? _fallbackHint;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _dropletWash,
                  shape: BoxShape.circle,
                ),
                child: SvgPicture.asset(AppIcons.statusDroplets),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastWateredCaption(plant.currentCare.lastWateredAt, now),
                      style: AppText.caption.copyWith(
                        color: _caption,
                        fontSize: 10,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          const SizedBox(height: 8),
          Text(
            detail,
            style: AppText.caption.copyWith(
              color: AppColors.body,
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            hint,
            style: AppText.caption.copyWith(
              color: AppColors.body,
              fontSize: 10,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _fallbackNext(DateTime now) {
    final days = waterTask?.intervalDays ?? 7;
    final last = plant.currentCare.lastWateredAt ?? now;
    return last.add(Duration(days: days));
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.watered,
    required this.logging,
    required this.onWater,
    required this.onNote,
  });

  final bool watered;
  final bool logging;
  final VoidCallback onWater;
  final VoidCallback onNote;

  @override
  Widget build(BuildContext context) {
    final canWater = !watered && !logging;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: AppIcons.actionLogWatering,
            label: watered
                ? 'Watered today'
                : logging
                ? 'Saving'
                : 'Log watering',
            background: AppColors.green,
            foreground: AppColors.surface,
            enabled: canWater,
            onTap: onWater,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: AppIcons.actionAddNote,
            label: 'Add note',
            background: AppColors.surfaceBlush,
            foreground: AppColors.terracotta,
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
    required this.background,
    required this.foreground,
    required this.onTap,
    this.enabled = true,
  });

  final String icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.cardRadius);
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: radius,
          child: SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(icon),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.label.copyWith(
                      color: foreground,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
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
    required this.now,
    required this.isBusy,
    required this.onAdd,
    required this.onRemove,
  });

  final Plant plant;
  final List<Reminder> reminders;
  final DateTime now;
  final bool isBusy;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  bool get _onSchedule =>
      reminders.any((reminder) => reminder.isPlantChore(plant.id));

  @override
  Widget build(BuildContext context) {
    final others = [
      for (final reminder in reminders)
        if (reminder.taskType != ReminderTaskType.waterCheck) reminder,
    ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    final next = others.firstOrNull;

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
              if (next == null && !_onSchedule)
                Text(
                  'This plant is not on the chores list yet.',
                  style: AppText.bodyLarge.copyWith(color: AppColors.body),
                )
              else if (next != null) ...[
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
    required this.plant,
    required this.species,
    required this.tasks,
    required this.profiles,
    required this.waterTask,
    required this.loading,
    required this.calendar,
    required this.difficulty,
    required this.light,
    required this.sourceUrl,
    required this.sourceLabel,
    required this.onEditTasks,
    required this.onEditGuide,
  });

  final Plant plant;
  final Species? species;
  final List<CareProfileTask> tasks;
  final List<CareProfile>? profiles;
  final CareProfileTask? waterTask;
  final bool loading;
  final SowingCalendar? calendar;
  final String? difficulty;
  final String? light;
  final String? sourceUrl;
  final String? sourceLabel;
  final VoidCallback? onEditTasks;
  final VoidCallback onEditGuide;

  @override
  Widget build(BuildContext context) {
    final shown = tasks.isNotEmpty
        ? tasks
        : [if (waterTask != null) waterTask!];
    final plantLight = light?.trim();
    final level = difficulty?.trim();
    final saved = plant.careGuide;
    final suggested = suggestCareGuide(species, profiles);
    String show(String? own, String? catalog, String empty) =>
        own ?? catalog ?? empty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionHeading(
                icon: AppIcons.careGuideHeading,
                title: 'Care guide',
              ),
            ),
            if (onEditTasks != null)
              TextButton(
                onPressed: onEditTasks,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.terracotta,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  'Edit',
                  style: AppText.label.copyWith(color: AppColors.terracotta),
                ),
              ),
            TextButton(
              onPressed: onEditGuide,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.terracotta,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                'Edit guide',
                style: AppText.label.copyWith(color: AppColors.terracotta),
              ),
            ),
          ],
        ),
        if (calendar != null && calendar!.hasWindows) ...[
          const SizedBox(height: 10),
          SowingCalendarSection(calendar: calendar!),
        ],
        const SizedBox(height: 10),
        if (loading)
          Text(
            'Finding care advice…',
            style: AppText.body.copyWith(color: AppColors.body),
          )
        else ...[
          if (level != null && level.isNotEmpty) ...[
            Text(
              'Difficulty · ${_careLabel(level)}',
              style: AppText.label.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: 10),
          ],
          if (shown.isEmpty)
            _CareCard(
              icon: AppIcons.careWatering,
              label: 'WATERING',
              value: 'Being worked out',
              hint: 'A cadence appears once care is saved on this plant.',
            )
          else
            for (final task in shown) ...[
              _CareCard(
                icon: _careIcon(task.taskType),
                label: task.title.toUpperCase(),
                value:
                    'Every ${task.intervalDays == 1 ? 'day' : '${task.intervalDays} days'}',
                hint: task.instructions?.trim().isNotEmpty == true
                    ? task.instructions
                    : 'A starting point. Adjust it as you learn the plant.',
              ),
              const SizedBox(height: 10),
            ],
          if (plantLight != null && plantLight.isNotEmpty)
            _CareCard(
              icon: AppIcons.careLight,
              label: 'LIGHT',
              value: plantLight,
            )
          else if (species != null)
            _CareCard(
              icon: AppIcons.careLight,
              label: 'LIGHT',
              value: lightLabel(species?.growth.light),
              hint: species?.growth.light == null
                  ? 'The catalog has no light reading for this species.'
                  : null,
            ),
          if (sourceUrl case final url?) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Care tips from ${sourceLabel ?? 'PlantSolve'}',
                  style: AppText.caption.copyWith(color: AppColors.green),
                ),
              ),
            ),
          ],
        ],
        const SizedBox(height: 10),
        if ((plantLight == null || plantLight.isEmpty) && species == null)
          _CareCard(
            icon: AppIcons.careLight,
            label: 'LIGHT',
            value: show(saved?.light, suggested.light, 'Not known'),
          ),
        if ((plantLight == null || plantLight.isEmpty) && species == null)
          const SizedBox(height: 10),
        _CareCard(
          icon: AppIcons.taskPest,
          label: 'PESTS',
          value: show(saved?.pests, suggested.pests, 'Nothing noted yet'),
        ),
        const SizedBox(height: 10),
        _CareCard(
          icon: AppIcons.taskFertilize,
          label: 'FEEDING',
          value: show(saved?.feeding, suggested.feeding, 'Nothing noted yet'),
        ),
        const SizedBox(height: 10),
        _CareCard(
          icon: AppIcons.careWatering,
          label: 'PRUNING',
          value: show(saved?.pruning, suggested.pruning, 'Nothing noted yet'),
        ),
        const SizedBox(height: 10),
        _CareCard(
          icon: AppIcons.careLight,
          label: 'HUMIDITY',
          value: show(saved?.humidity, suggested.humidity, 'Not known'),
        ),
        const SizedBox(height: 10),
        _CareCard(
          icon: AppIcons.careWatering,
          label: 'REPOTTING',
          value: show(
            saved?.repotting,
            suggested.repotting,
            'Nothing noted yet',
          ),
        ),
      ],
    );
  }
}

String _careLabel(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}

String _careIcon(ReminderTaskType type) {
  return switch (type) {
    ReminderTaskType.waterCheck => AppIcons.careWatering,
    ReminderTaskType.fertilize => AppIcons.careLight,
    _ => AppIcons.careGuideHeading,
  };
}

class _CareEditDialog extends StatefulWidget {
  const _CareEditDialog({required this.tasks});

  final List<CareProfileTask> tasks;

  @override
  State<_CareEditDialog> createState() => _CareEditDialogState();
}

class _CareEditDialogState extends State<_CareEditDialog> {
  late final List<TextEditingController> _days = [
    for (final task in widget.tasks)
      TextEditingController(text: '${task.intervalDays}'),
  ];
  late final List<TextEditingController> _notes = [
    for (final task in widget.tasks)
      TextEditingController(text: task.instructions ?? ''),
  ];
  String? _error;

  @override
  void dispose() {
    for (final controller in _days) {
      controller.dispose();
    }
    for (final controller in _notes) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final next = <CareProfileTask>[];
    for (var index = 0; index < widget.tasks.length; index++) {
      final days = int.tryParse(_days[index].text.trim());
      if (days == null || days < 1 || days > 365) {
        setState(() => _error = 'Use a number of days from 1 to 365.');
        return;
      }
      final task = widget.tasks[index];
      next.add(
        CareProfileTask(
          taskType: task.taskType,
          title: task.title,
          intervalDays: days,
          instructions: _notes[index].text.trim(),
          priority: task.priority,
          basis: task.basis,
        ),
      );
    }
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit care'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < widget.tasks.length; index++) ...[
              TextField(
                controller: _days[index],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '${widget.tasks[index].title} (days)',
                ),
              ),
              TextField(
                controller: _notes[index],
                decoration: const InputDecoration(labelText: 'Instructions'),
              ),
              const SizedBox(height: 12),
            ],
            if (_error != null)
              Text(
                _error!,
                style: AppText.body.copyWith(color: AppColors.terracottaBright),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _save, child: const Text('Save')),
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
