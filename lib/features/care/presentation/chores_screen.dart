import 'package:flutter/material.dart';

import '../../../app/assets.dart';
import '../../../app/shell/app_shell.dart';
import '../../../core/widgets/placeholder_view.dart';

/// Tab 3 — the full schedule. Placeholder until the reminder list is built.
class ChoresScreen extends StatelessWidget {
  const ChoresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShellScrollView(
      child: PlaceholderView(
        icon: AppIcons.navChores,
        iconSize: Size(20, 15.075),
        eyebrow: 'THE SCHEDULE',
        title: 'Chores',
        description:
            'Everything coming up, not just today. Reminders are generated '
            'from each species care profile and adjust as you log care.',
        bullets: [
          'See the week ahead, and anything overdue',
          'Snooze, skip or add a reminder of your own',
          'Log watering and feeding straight from the list',
        ],
      ),
    );
  }
}
