import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme.dart';
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

class _Photo extends StatelessWidget {
  const _Photo({required this.plant});

  final GrowingPlant plant;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.imageRadius),
      child: Container(
        height: 112,
        width: double.infinity,
        color: AppColors.surfaceBlush,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(plant.image, fit: BoxFit.cover),
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
