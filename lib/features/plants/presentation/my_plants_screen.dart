import 'package:flutter/material.dart';

import '../../../app/assets.dart';
import '../../../app/shell/app_shell.dart';
import '../../../core/widgets/placeholder_view.dart';

/// Tab 2 — the full garden. Placeholder until the plant list is built.
class MyPlantsScreen extends StatelessWidget {
  const MyPlantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellScrollView(
      child: PlaceholderView(
        icon: AppIcons.navMyPlants,
        iconSize: Size(18, 20),
        eyebrow: 'YOUR GARDEN',
        title: 'My Plants',
        description:
            'Every plant you tend, in one place. The home screen shows only '
            'what needs you today; this is the whole collection.',
        bullets: [
          'Browse and search your plants, grouped by garden',
          'Open a plant for its care history, photos and observations',
          'Archive a plant without losing the history behind it',
        ],
      ),
    );
  }
}
