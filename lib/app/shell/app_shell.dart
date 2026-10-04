import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme.dart';
import 'account_sheet.dart';
import 'app_bottom_nav.dart';
import 'app_header.dart';

/// Frame shared by every tab: the frosted header above, the nav below, and
/// the active branch between them.
///
/// The header and nav float over the content rather than boxing it in, which
/// is what gives the design its frosted-glass edges. Content therefore has to
/// pad itself clear of both — use [ShellScrollView] rather than doing it by
/// hand.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppHeader(
              onProfile: () => showAccountSheet(context, ref),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNav(
              currentIndex: navigationShell.currentIndex,
              onSelect: (index) => navigationShell.goBranch(
                index,
                // Tapping the tab you are already on returns to its root,
                // the usual way to escape a stack you have pushed into.
                initialLocation: index == navigationShell.currentIndex,
              ),
              onAdd: () => context.pushNamed(AddPlantRoute.name),
            ),
          ),
        ],
      ),
    );
  }
}

/// A scroll view inset to clear the shell's floating header and nav.
class ShellScrollView extends StatelessWidget {
  const ShellScrollView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: AppSizes.headerHeight + insets.top,
        bottom: AppSizes.navHeight + 32 + insets.bottom,
        left: AppSizes.screenPadding,
        right: AppSizes.screenPadding,
      ),
      child: child,
    );
  }
}
