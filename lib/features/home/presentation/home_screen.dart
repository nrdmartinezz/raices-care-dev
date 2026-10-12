import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/layout.dart';
import '../../../app/router.dart';
import '../../../app/shell/app_shell.dart';
import '../../../app/shell/desktop_header_actions.dart';
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
    if (!AppLayout.isWide(context)) {
      return const ShellScrollView(child: _PhoneHome());
    }
    return const ShellScrollView(child: _DesktopHome());
  }
}

class _PhoneHome extends StatelessWidget {
  const _PhoneHome();

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _DesktopHome extends StatelessWidget {
  const _DesktopHome();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: GreetingSection(compact: true)),
            SizedBox(width: 16),
            DesktopHeaderActions(),
          ],
        ),
        const SizedBox(height: 45),
        LayoutBuilder(
          builder: (context, constraints) {
            final growing = GrowingNowSection(
              onViewAll: () => context.goNamed(MyPlantsRoute.name),
            );
            const ritual = TodaysRitualSection();
            final gap = 36.0;
            final stacked = constraints.maxWidth < 560;
            final garden = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GardenWeatherStrip(showRitual: true),
                const SizedBox(height: 12),
                growing,
              ],
            );
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  garden,
                  const SizedBox(height: 36),
                  ritual,
                ],
              );
            }
            // 407 is the garden column in the 1440 frame, after the 36 gap.
            final leftWidth = ((constraints.maxWidth - gap) * 407 / 1060)
                .clamp(240.0, 460.0);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: leftWidth, child: garden),
                SizedBox(width: gap),
                const Expanded(child: ritual),
              ],
            );
          },
        ),
      ],
    );
  }
}
