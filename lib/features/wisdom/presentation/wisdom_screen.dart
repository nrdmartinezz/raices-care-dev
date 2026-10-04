import 'package:flutter/material.dart';

import '../../../app/assets.dart';
import '../../../app/shell/app_shell.dart';
import '../../../core/widgets/placeholder_view.dart';

/// Tab 4 — the species catalog and growing lore.
class WisdomScreen extends StatelessWidget {
  const WisdomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellScrollView(
      child: PlaceholderView(
        icon: AppIcons.navWisdom,
        iconSize: Size(22, 16),
        eyebrow: 'GROWING LORE',
        title: 'Wisdom',
        description:
            'The shared species catalog, plus the traditions that go with it. '
            'Look up a plant before you bring it home.',
        bullets: [
          'Search the species catalog and read care guidance',
          'Identify pests and diseases from the shared catalog',
          'Collect the traditions that appear on the home screen',
        ],
      ),
    );
  }
}
