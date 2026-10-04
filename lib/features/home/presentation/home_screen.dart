import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'widgets/greeting_section.dart';
import 'widgets/growing_now_section.dart';
import 'widgets/home_bottom_nav.dart';
import 'widgets/home_header.dart';
import 'widgets/quick_actions_banner.dart';
import 'widgets/todays_ritual_section.dart';
import 'widgets/wisdom_card.dart';

/// Home — My Garden. The content scrolls beneath the frosted header and nav.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: AppSizes.headerHeight + insets.top,
                bottom: AppSizes.navHeight + 32 + insets.bottom,
                left: AppSizes.screenPadding,
                right: AppSizes.screenPadding,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GreetingSection(),
                  SizedBox(height: AppSizes.sectionGap),
                  TodaysRitualSection(),
                  SizedBox(height: AppSizes.sectionGap),
                  WisdomCard(),
                  SizedBox(height: AppSizes.sectionGap),
                  GrowingNowSection(),
                  SizedBox(height: AppSizes.sectionGap),
                  QuickActionsBanner(),
                ],
              ),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: HomeHeader()),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: HomeBottomNav(),
          ),
        ],
      ),
    );
  }
}
