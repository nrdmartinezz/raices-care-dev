import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../app/assets.dart';
import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import '../../care/data/reminder_repository.dart';
import '../../care/domain/reminder.dart';
import '../../home/data/home_providers.dart';
import '../data/plant_repository.dart';
import '../domain/garden_spot.dart';
import '../domain/plant.dart';
import 'add_plant_flow.dart';
import 'care_labels.dart';

/// Tab 2 — the whole garden, one card per plant.
///
/// The home screen only shows what needs attention today; this is every
/// active plant, newest care first, each opening its profile.
class MyPlantsScreen extends ConsumerWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(activePlantsProvider);
    final nextByPlant = ref.watch(nextReminderByPlantProvider);
    final now = ref.watch(nowProvider);

    return ShellScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR GARDEN',
            style: AppText.eyebrow.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 7),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'My Plants',
                  style: AppText.display.copyWith(color: AppColors.ink),
                ),
              ),
              if (plantsAsync.value case final plants?
                  when plants.isNotEmpty) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    plants.length == 1 ? '1 plant' : '${plants.length} plants',
                    style: AppText.label.copyWith(color: AppColors.green),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.sectionGap),
          // A non-empty list wins over the spinner and over a later error, so a
          // re-subscribe does not flicker the cards away. An error with no
          // plants to show is a failed read, even when it still carries an
          // empty list — that is not the same as a garden that loaded empty.
          switch (plantsAsync) {
            AsyncValue(:final value?) when value.isNotEmpty => Column(
              children: [
                for (final plant in value) ...[
                  _PlantRowCard(
                    plant: plant,
                    next: nextByPlant[plant.id],
                    now: now,
                    onTap: () => context.goNamed(
                      PlantDetailRoute.name,
                      pathParameters: {'plantId': plant.id},
                    ),
                  ),
                  if (plant != value.last) const SizedBox(height: 12),
                ],
              ],
            ),
            AsyncValue(hasError: true) => Text(
              'Your plants could not load. Try again in a moment.',
              style: AppText.bodyLarge.copyWith(color: AppColors.body),
            ),
            AsyncValue(:final value?) when value.isEmpty =>
              const _EmptyGarden(),
            _ => const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(),
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _EmptyGarden extends StatelessWidget {
  const _EmptyGarden();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No plants yet',
            style: AppText.cardTitle.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the add button below to choose your first plant. Its care '
            'rhythm is built for you.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
        ],
      ),
    );
  }
}

/// One plant in the list: photo, names, where it lives and what it needs next.
class _PlantRowCard extends ConsumerWidget {
  const _PlantRowCard({
    required this.plant,
    required this.next,
    required this.now,
    required this.onTap,
  });

  final Plant plant;
  final Reminder? next;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = plant.coverPhotoPath;
    final image = path == null
        ? null
        : ref.watch(plantCoverImageProvider(path));
    final garden = GardenSpot.fromWire(plant.gardenId);
    final radius = BorderRadius.circular(AppSizes.cardRadius + 4);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  child: ColoredBox(
                    color: AppColors.surfaceBlush,
                    child: image == null
                        ? Center(
                            child: Opacity(
                              opacity: 0.35,
                              child: SvgPicture.asset(
                                AppIcons.growingSprout,
                                width: 24,
                                height: 24,
                              ),
                            ),
                          )
                        : Image(image: image, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.plantName.copyWith(color: AppColors.ink),
                    ),
                    if (plant.speciesNameSnapshot case final species?) ...[
                      Text(
                        species,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyItalic.copyWith(
                          color: AppColors.body,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (garden != null)
                          _Tag(label: gardenSpotLabel(garden)),
                        _Tag(label: plantStageLabel(plant.plantAgeStage)),
                      ],
                    ),
                    if (next case final reminder?) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          SvgPicture.asset(
                            AppIcons.nextCareDroplet,
                            width: 13,
                            height: 13,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${reminder.title} · '
                              '${dueLabel(reminder.dueAt, now: now)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.caption.copyWith(
                                color: reminder.dueAt.isAfter(now)
                                    ? AppColors.body
                                    : AppColors.terracotta,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SvgPicture.asset(AppIcons.resultChevron, width: 17, height: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppSizes.pill),
      ),
      child: Text(label, style: AppText.label.copyWith(color: AppColors.green)),
    );
  }
}
