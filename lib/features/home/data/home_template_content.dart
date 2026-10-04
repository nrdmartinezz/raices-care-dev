import 'package:flutter/widgets.dart';

import '../../../app/assets.dart';
import '../domain/care_task.dart';
import '../domain/growing_plant.dart';

/// Placeholder content matching the Figma template. Replace with Firestore
/// data once the plant and care repositories land.
abstract final class HomeTemplateContent {
  static const dateLabel = 'THURSDAY, OCTOBER 24';
  static const greeting = 'Good morning,\nMartín';
  static const ritualPillLabel = 'Morning\nwatering';

  static const temperature = '24°C';
  static const sky = 'Sunny';
  static const weatherNote = 'Ideal absorption conditions';
  static const humidity = '48%';
  static const uvIndex = 'UV 6';

  static const ritualProgressLabel = '2 of 4 tasks done';

  static const traditionNumber = 'Tradition #14';
  static const wisdomQuote =
      '“Touch the soil with your knuckles before watering. '
      'If fresh dust clings, let the roots breathe until dusk.”';
  static const wisdomAuthor = 'Don Aurelio • Mindful Care';

  static const plantCountLabel = 'View all 12';

  static const tasks = <CareTask>[
    CareTask(
      plantName: "Grandmother's Spearmint",
      time: '08:30 AM',
      instruction: '150ml resting water at the base',
      category: CareCategory.hydration,
      location: 'East Patio',
      isDone: true,
    ),
    CareTask(
      plantName: 'Monstera Deliciosa',
      time: '09:15 AM',
      instruction: 'Mist foliage and aerial roots',
      category: CareCategory.misting,
      location: 'Living Room',
      isDone: true,
    ),
    CareTask(
      plantName: 'Blue Agave',
      time: '10:00 AM',
      instruction: 'Rotate 90° towards gentle sun',
      category: CareCategory.rotation,
      location: 'Terracotta Pot',
      isDone: false,
      isDueNow: true,
    ),
    CareTask(
      plantName: 'Rubber Plant (Ficus Elastica)',
      time: '05:00 PM',
      instruction: 'Wipe leaves with warm damp cloth',
      category: CareCategory.cleaning,
      location: 'North Balcony',
      isDone: false,
    ),
  ];

  static const plants = <GrowingPlant>[
    GrowingPlant(
      image: AppImages.plantMonstera,
      badge: 'New sprout',
      tone: PlantStatusTone.fresh,
      name: 'Queen Monstera',
      species: 'Monstera deliciosa',
      vitality: PlantStat(
        icon: AppIcons.statVigor,
        iconSize: Size(13.333, 12),
        label: '98% Vigor',
      ),
      condition: PlantStat(
        icon: AppIcons.statMoisture,
        iconSize: Size(10.667, 13.333),
        label: 'Moist',
      ),
    ),
    GrowingPlant(
      image: AppImages.plantHabanero,
      badge: 'Flowering active',
      tone: PlantStatusTone.blooming,
      name: 'Habanero Pepper',
      species: 'Capsicum chinense',
      vitality: PlantStat(
        icon: AppIcons.statHealth,
        iconSize: Size(10.667, 12.667),
        label: '92% Health',
      ),
      condition: PlantStat(
        icon: AppIcons.statSun,
        iconSize: Size(14.667, 14.667),
        label: 'Full Sun',
      ),
    ),
    GrowingPlant(
      image: AppImages.plantRosemary,
      badge: 'Ready for cutting',
      tone: PlantStatusTone.harvest,
      name: 'Garden Rosemary',
      species: 'Salvia rosmarinus',
      vitality: PlantStat(
        icon: AppIcons.statCutting,
        iconSize: Size(13.333, 13.333),
        label: 'Cutting ready',
      ),
      condition: PlantStat(
        icon: AppIcons.statMoisture,
        iconSize: Size(10.667, 13.333),
        label: 'Dry soil',
      ),
    ),
  ];
}
