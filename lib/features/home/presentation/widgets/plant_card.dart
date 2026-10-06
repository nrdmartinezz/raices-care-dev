import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../data/home_providers.dart';
import '../../domain/growing_plant.dart';

/// A Growing Now card: cropped photo with a status badge, the common and
/// botanical names, then a vitality and condition readout.
class PlantCard extends StatelessWidget {
  const PlantCard({super.key, required this.plant, this.onTap});

  final GrowingPlant plant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        boxShadow: AppShadows.card,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Photo(plant: plant),
              const SizedBox(height: 12),
              Text(
                plant.name,
                style: AppText.plantName.copyWith(color: AppColors.ink),
              ),
              Text(
                plant.species,
                style: AppText.bodyItalic.copyWith(color: AppColors.body),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Stat(stat: plant.vitality, color: AppColors.green),
                  _Stat(stat: plant.condition, color: AppColors.body),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.plant});

  final GrowingPlant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A supplied image wins; otherwise the stored object key on the custom domain.
    final path = plant.coverPhotoPath;
    final image =
        plant.image ??
        (path == null ? null : ref.watch(plantCoverImageProvider(path)));

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.imageRadius),
      child: Container(
        height: 112,
        width: double.infinity,
        color: AppColors.surfaceBlush,
        child: Stack(
          children: [
            Positioned.fill(
              child: image == null
                  ? const _PhotoPlaceholder()
                  : Image(image: image, fit: BoxFit.cover),
            ),
            Positioned(
              left: 8,
              top: 8,
              child: _StatusBadge(label: plant.badge, tone: plant.tone),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown for a plant with no photo, and while a cover URL is resolving.
class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.35,
        child: SvgPicture.asset(AppIcons.growingSprout, width: 28, height: 28),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.tone});

  final String label;
  final PlantStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppSizes.pill);
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, boxShadow: [tone.shadow]),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
          child: Container(
            color: tone.background,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(
              label,
              style: AppText.label.copyWith(color: tone.foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.stat, required this.color});

  final PlantStat stat;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          stat.icon,
          width: stat.iconSize.width,
          height: stat.iconSize.height,
        ),
        const SizedBox(width: 4),
        Text(stat.label, style: AppText.label.copyWith(color: color)),
      ],
    );
  }
}
