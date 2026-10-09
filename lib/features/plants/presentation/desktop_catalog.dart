import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/assets.dart';
import '../../../app/shell/desktop_header_actions.dart';
import '../../../app/theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../care/domain/reminder.dart';
import '../../home/data/home_mappers.dart';
import '../../home/data/home_providers.dart';
import '../domain/garden_spot.dart';
import '../domain/plant.dart';
import 'add_plant_flow.dart';
import 'care_labels.dart';

/// My Plants on a laptop or desktop: a catalog grid instead of a phone list.
class DesktopPlantCatalog extends ConsumerStatefulWidget {
  const DesktopPlantCatalog({
    super.key,
    required this.plants,
    required this.nextByPlant,
    required this.now,
    required this.onOpen,
  });

  final List<Plant> plants;
  final Map<String, Reminder> nextByPlant;
  final DateTime now;
  final ValueChanged<String> onOpen;

  @override
  ConsumerState<DesktopPlantCatalog> createState() =>
      _DesktopPlantCatalogState();
}

class _DesktopPlantCatalogState extends ConsumerState<DesktopPlantCatalog> {
  final _query = TextEditingController();
  String? _spot;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider).value;
    final filtered = _visible();
    final spots = _spots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          count: widget.plants.length,
          place: _place(profile?.homeLocation),
          season: _season(widget.now),
        ),
        if (widget.plants.isEmpty) ...[
          const SizedBox(height: 24),
          const _EmptyCatalog(),
        ] else ...[
          const SizedBox(height: 24),
          _SearchField(
            controller: _query,
            onChanged: (_) => setState(() {}),
          ),
          if (spots.length > 1) ...[
            const SizedBox(height: 16),
            _SpotFilters(
              spots: spots,
              selected: _spot,
              onSelected: (spot) => setState(() => _spot = spot),
            ),
          ],
          const SizedBox(height: 20),
          if (filtered.isEmpty)
            Text(
              'No plants match that search.',
              style: AppText.bodyLarge.copyWith(color: AppColors.body),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = 20.0;
                final columns = constraints.maxWidth >= 980
                    ? 3
                    : constraints.maxWidth >= 640
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final plant in filtered)
                      SizedBox(
                        width: cardWidth,
                        child: _CatalogCard(
                          plant: plant,
                          next: widget.nextByPlant[plant.id],
                          now: widget.now,
                          onOpen: () => widget.onOpen(plant.id),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ],
    );
  }

  List<Plant> _visible() {
    final query = _query.text.trim().toLowerCase();
    return [
      for (final plant in widget.plants)
        if (_spot == null || plant.gardenId == _spot)
          if (query.isEmpty ||
              plant.displayName.toLowerCase().contains(query) ||
              (plant.speciesNameSnapshot ?? '').toLowerCase().contains(query))
            plant,
    ];
  }

  List<GardenSpot> _spots() {
    final seen = <GardenSpot>[];
    for (final plant in widget.plants) {
      final spot = GardenSpot.fromWire(plant.gardenId);
      if (spot != null && !seen.contains(spot)) {
        seen.add(spot);
      }
    }
    return seen;
  }
}

String _season(DateTime now) {
  final name = switch (now.month) {
    12 || 1 || 2 => 'Winter',
    3 || 4 || 5 => 'Spring',
    6 || 7 || 8 => 'Summer',
    _ => 'Autumn',
  };
  return '$name Season ${now.year}';
}

String? _place(HomeLocation? location) {
  if (location == null) {
    return null;
  }
  final city = location.city?.trim();
  final state = location.state?.trim();
  if (city != null && city.isNotEmpty && state != null && state.isNotEmpty) {
    return '$city, $state';
  }
  if (city != null && city.isNotEmpty) {
    return city;
  }
  return null;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.count,
    required this.season,
    required this.place,
  });

  final int count;
  final String season;
  final String? place;

  @override
  Widget build(BuildContext context) {
    final countLabel = count == 1 ? '1 Plant' : '$count Plants';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GARDEN SPACE',
                style: AppText.eyebrow.copyWith(color: AppColors.amberText),
              ),
              const SizedBox(height: 4),
              Text(
                'Living Catalog',
                style: AppText.displayLarge.copyWith(color: AppColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                season,
                style: AppText.bodyMedium.copyWith(color: AppColors.body),
              ),
              if (place case final line?) ...[
                const SizedBox(height: 2),
                Text(
                  line,
                  style: AppText.title.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 16),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.mint.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(AppSizes.pill),
            boxShadow: AppShadows.card,
          ),
          child: Text(
            countLabel,
            style: AppText.labelSemiBold.copyWith(color: AppColors.canopyDeep),
          ),
        ),
        const SizedBox(width: 12),
        const DesktopHeaderActions(),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surfaceBlush,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppText.input.copyWith(color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'Search by common or botanical name...',
          hintStyle: AppText.input.copyWith(color: AppColors.body),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: SvgPicture.asset(AppIcons.searchGlass, width: 15, height: 15),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 43),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SpotFilters extends StatelessWidget {
  const _SpotFilters({
    required this.spots,
    required this.selected,
    required this.onSelected,
  });

  final List<GardenSpot> spots;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterPill(
          label: 'All',
          selected: selected == null,
          onTap: () => onSelected(null),
        ),
        for (final spot in spots)
          _FilterPill(
            label: gardenSpotLabel(spot),
            selected: selected == spot.wire,
            onTap: () => onSelected(spot.wire),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.terracotta : AppColors.surfaceBlush,
      borderRadius: BorderRadius.circular(AppSizes.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            label,
            style: AppText.fieldLabel.copyWith(
              color: selected ? Colors.white : AppColors.body,
            ),
          ),
        ),
      ),
    );
  }
}

class _CatalogCard extends ConsumerWidget {
  const _CatalogCard({
    required this.plant,
    required this.next,
    required this.now,
    required this.onOpen,
  });

  final Plant plant;
  final Reminder? next;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = plant.coverPhotoPath;
    final image = path == null ? null : ref.watch(plantCoverImageProvider(path));
    final species = plant.speciesNameSnapshot;
    final stage = plant.plantAgeStage == PlantAgeStage.unknown
        ? null
        : plantStageLabel(plant.plantAgeStage);
    final sun = plant.environment.sunExposure == SunExposure.unknown
        ? null
        : _sunLabel(plant.environment.sunExposure);
    final health = _healthLabel(plant.status.health);

    return Material(
      color: AppColors.surfaceWarm,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: ColoredBox(
                  color: AppColors.surfaceBlush,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image == null)
                        Center(
                          child: Opacity(
                            opacity: 0.35,
                            child: SvgPicture.asset(
                              AppIcons.growingSprout,
                              width: 28,
                              height: 28,
                            ),
                          ),
                        )
                      else
                        Image(image: image, fit: BoxFit.cover),
                      if (health != null)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.mint.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(AppSizes.pill),
                            ),
                            child: Text(
                              health,
                              style: AppText.label.copyWith(
                                color: AppColors.green,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.catalogName.copyWith(color: AppColors.ink),
                  ),
                  if (species != null && species.isNotEmpty)
                    Text(
                      species,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyItalic.copyWith(color: AppColors.body),
                    ),
                  if (stage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBlush,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stage,
                        style: AppText.labelSemiBold.copyWith(
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Metric(
                          icon: AppIcons.nextCareDroplet,
                          iconSize: const Size(13.33, 16.67),
                          label: 'Next watering',
                          value: _nextLabel(next, now),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Metric(
                          icon: AppIcons.statSun,
                          iconSize: const Size(18, 18),
                          label: 'Sun exposure',
                          value: sun ?? 'Not set',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastWateredCaption(
                            plant.currentCare.lastWateredAt,
                            now,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label.copyWith(color: AppColors.muted),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onOpen,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.body,
                          backgroundColor: AppColors.surfaceBlush,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.pill),
                          ),
                        ),
                        child: Text(
                          'View Profile',
                          style: AppText.label.copyWith(color: AppColors.body),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.iconSize,
    required this.label,
    required this.value,
  });

  final String icon;
  final Size iconSize;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlush,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Row(
        children: [
          SvgPicture.asset(icon, width: iconSize.width, height: iconSize.height),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label.copyWith(color: AppColors.body),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
            'Use add a plant to choose your first one. Its care rhythm is built for you.',
            style: AppText.bodyLarge.copyWith(color: AppColors.body),
          ),
        ],
      ),
    );
  }
}

String _nextLabel(Reminder? next, DateTime now) {
  if (next == null) {
    return 'Not scheduled';
  }
  return '${dueLabel(next.dueAt, now: now)}, ${formatTimeLabel(next.dueAt)}';
}

String _sunLabel(SunExposure exposure) => switch (exposure) {
  SunExposure.fullSun => 'Full sun',
  SunExposure.partialSun => 'Partial sun',
  SunExposure.partialShade => 'Partial shade',
  SunExposure.fullShade => 'Full shade',
  SunExposure.brightIndirect => 'Bright indirect',
  SunExposure.lowLight => 'Low light',
  SunExposure.unknown => 'Not set',
};

String? _healthLabel(PlantHealth health) => switch (health) {
  PlantHealth.healthy => 'Healthy',
  PlantHealth.needsAttention => 'Needs care',
  PlantHealth.recovering => 'Recovering',
  PlantHealth.unknown => null,
};
