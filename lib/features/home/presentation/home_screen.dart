import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/theme.dart';
import 'widgets/greeting_section.dart';
import 'widgets/growing_now_section.dart';
import 'widgets/quick_actions_banner.dart';
import 'widgets/todays_ritual_section.dart';

/// Home — My Garden. The shell supplies the header and nav it scrolls beneath.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GreetingSection(),
          const SizedBox(height: AppSizes.sectionGap),
          const TodaysRitualSection(),
          const SizedBox(height: AppSizes.sectionGap),
          GrowingNowSection(
            onViewAll: () => context.goNamed(MyPlantsRoute.name),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          QuickActionsBanner(
            onNewSprout: () => context.pushNamed(AddPlantRoute.name),
          ),
        ],
      ),
    );
  }
}
