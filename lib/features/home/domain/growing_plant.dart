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
    required this.id,
    required this.badge,
    required this.tone,
    required this.name,
    required this.species,
    required this.vitality,
    required this.condition,
    this.image,
    this.coverPhotoPath,
  });

  /// The plant document's id, so tapping the card can open its profile.
  final String id;

  /// Already-resolved artwork. Null renders the blush placeholder, which is
  /// also what a plant with no photo yet shows.
  final ImageProvider? image;

  /// Cloud Storage path for the cover photo, if there is one. The card resolves
  /// it to a signed URL on demand, because those URLs expire.
  final String? coverPhotoPath;

  final String badge;
  final PlantStatusTone tone;
  final String name;
  final String species;

  /// The green readout on the left, e.g. "98% Vigor".
  final PlantStat vitality;

  /// The brown readout on the right, e.g. "Moist".
  final PlantStat condition;

  GrowingPlant withImage(ImageProvider? image) => GrowingPlant(
    id: id,
    badge: badge,
    tone: tone,
    name: name,
    species: species,
    vitality: vitality,
    condition: condition,
    image: image,
    coverPhotoPath: coverPhotoPath,
  );
}
