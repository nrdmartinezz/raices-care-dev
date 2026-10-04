import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/assets.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/placeholder_view.dart';

/// The central add button's destination.
///
/// Routed above the shell rather than as a tab, so the bottom nav is hidden
/// and the flow reads as a task you finish or abandon.
class AddPlantScreen extends StatelessWidget {
  const AddPlantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: insets.top + 12,
          bottom: insets.bottom + 32,
          left: AppSizes.screenPadding,
          right: AppSizes.screenPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.pop(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.terracotta,
                ),
                child: Text(
                  'Close',
                  style: AppText.label.copyWith(color: AppColors.terracotta),
                ),
              ),
            ),
            const PlaceholderView(
              icon: AppIcons.actionNewSprout,
              iconSize: Size(18.333, 16.667),
              eyebrow: 'NEW SPROUT',
              title: 'Add a plant',
              description:
                  'Name the plant, find its species, and the first reminders '
                  'are scheduled for you.',
              bullets: [
                'Search the catalog, which caches the species on first use',
                'Set where it lives, its pot and its light',
                'Reminders arrive a moment later, from the species profile',
              ],
            ),
          ],
        ),
      ),
    );
  }
}
