import 'package:flutter/material.dart';

import '../../../../app/assets.dart';
import '../../../../app/theme.dart';
import '../../data/home_template_content.dart';
import 'plant_card.dart';
import 'section_heading.dart';

/// Section 4: the Growing Now plant cards.
class GrowingNowSection extends StatelessWidget {
  const GrowingNowSection({super.key, this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final plants = HomeTemplateContent.plants;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          icon: AppIcons.growingSprout,
          iconSize: const Size(14.667, 14.667),
          title: 'Growing Now',
          trailing: GestureDetector(
            onTap: onViewAll,
            child: Text(
              HomeTemplateContent.plantCountLabel,
              style: AppText.label.copyWith(color: AppColors.terracotta),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final plant in plants) ...[
          PlantCard(plant: plant),
          if (plant != plants.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
