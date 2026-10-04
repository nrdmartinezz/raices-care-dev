import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/assets.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../data/home_providers.dart';
import 'plant_card.dart';
import 'section_heading.dart';
import 'section_state.dart';

/// Section 4: the Growing Now plant cards.
class GrowingNowSection extends ConsumerWidget {
  const GrowingNowSection({super.key, this.onViewAll});

  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(growingNowProvider);
    final count = ref.watch(activePlantCountProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(
          icon: AppIcons.growingSprout,
          iconSize: const Size(14.667, 14.667),
          title: 'Growing Now',
          trailing: count == 0
              ? const SizedBox.shrink()
              : GestureDetector(
                  onTap: onViewAll,
                  child: Text(
                    'View all $count',
                    style: AppText.label.copyWith(color: AppColors.terracotta),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        // A value is shown whenever there is one, even while the stream is
        // re-subscribing: a refresh carries the previous data along with
        // `AsyncLoading`, and dropping back to the skeleton makes the cards
        // flicker away for no reason the gardener can see.
        switch (plants) {
          AsyncValue(:final value?) when value.isEmpty => const SectionMessage(
            title: 'No plants yet',
            body: 'Tap the add button to plant your first one.',
          ),
          AsyncValue(:final value?) => Column(
            children: [
              for (final plant in value) ...[
                PlantCard(
                  plant: plant,
                  // `go`, not `push`: the profile belongs to the My Plants
                  // branch, so opening it moves to that tab.
                  onTap: () => context.goNamed(
                    PlantDetailRoute.name,
                    pathParameters: {'plantId': plant.id},
                  ),
                ),
                if (plant != value.last) const SizedBox(height: 12),
              ],
            ],
          ),
          AsyncError(:final error) => SectionMessage(
            title: 'Your plants could not load',
            body: describeSectionError(error),
          ),
          _ => const SectionSkeleton(rows: 2, height: 220),
        },
      ],
    );
  }
}
