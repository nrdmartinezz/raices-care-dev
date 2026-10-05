import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import '../theme.dart';
import 'account_sheet.dart';
import 'app_bottom_nav.dart';
import 'app_header.dart';
import 'flow_header.dart';

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
          Positioned.fill(
            child: _BranchFade(
              index: navigationShell.currentIndex,
              child: navigationShell,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _header(context, ref),
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

  /// The bar at the top of the frame.
  ///
  /// A tab root gets the logo bar. A screen pushed inside a branch keeps the
  /// nav but needs a way back and a title instead, so it gets [FlowHeader].
  Widget _header(BuildContext context, WidgetRef ref) {
    final routeName = GoRouterState.of(context).topRoute?.name;
    if (routeName == PlantDetailRoute.name) {
      return FlowHeader(
        eyebrow: 'MY PLANTS',
        title: 'Plant profile',
        onBack: () => context.canPop()
            ? context.pop()
            : context.goNamed(MyPlantsRoute.name),
      );
    }
    if (routeName == SpeciesArticleRoute.name) {
      return FlowHeader(
        eyebrow: 'WISDOM',
        title: 'Species',
        onBack: () => context.canPop()
            ? context.pop()
            : context.goNamed(WisdomRoute.name),
      );
    }
    return AppHeader(onProfile: () => showAccountSheet(context, ref));
  }
}

/// Fades the shell body in when the active tab changes.
///
/// The [StatefulNavigationShell] stays the same child, so each branch keeps
/// its stack and scroll position.
class _BranchFade extends StatefulWidget {
  const _BranchFade({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_BranchFade> createState() => _BranchFadeState();
}

class _BranchFadeState extends State<_BranchFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
  }

  @override
  void didUpdateWidget(_BranchFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: widget.child);
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
