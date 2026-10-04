import 'package:flutter/widgets.dart';

import '../../../app/theme.dart';

/// Colour treatment for the status badge that floats over a plant photo.
enum PlantStatusTone {
  fresh(
    background: Color(0xE6BCEDDA),
    foreground: AppColors.greenSoft,
    shadow: BoxShadow(
      color: Color(0x0D000000),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ),
  blooming(
    background: AppColors.amber,
    foreground: AppColors.amberInk,
    shadow: BoxShadow(
      color: Color(0x0D000000),
      offset: Offset(0, 1),
      blurRadius: 1,
    ),
  ),
  harvest(
    background: AppColors.surfaceClay,
    foreground: AppColors.body,
    shadow: BoxShadow(
      color: Color(0x0D000000),
      offset: Offset(0, 1),
      blurRadius: 1,
    ),
  );

  const PlantStatusTone({
    required this.background,
    required this.foreground,
    required this.shadow,
  });

  final Color background;
  final Color foreground;
  final BoxShadow shadow;
}

/// One icon-and-label readout on the footer of a plant card.
class PlantStat {
  const PlantStat({
    required this.icon,
    required this.iconSize,
    required this.label,
  });

  final String icon;
  final Size iconSize;
  final String label;
}

/// A plant shown in the Growing Now carousel.
class GrowingPlant {
  const GrowingPlant({
    required this.image,
    required this.badge,
    required this.tone,
    required this.name,
    required this.species,
    required this.vitality,
    required this.condition,
  });

  final String image;
  final String badge;
  final PlantStatusTone tone;
  final String name;
  final String species;

  /// The green readout on the left, e.g. "98% Vigor".
  final PlantStat vitality;

  /// The brown readout on the right, e.g. "Moist".
  final PlantStat condition;
}
