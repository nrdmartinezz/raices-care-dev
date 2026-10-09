import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../layout.dart';
import '../router.dart';
import '../theme.dart';
import 'app_bottom_nav.dart';
import 'app_header.dart';
import 'desktop_sidebar.dart';
import 'flow_header.dart';
import 'header_bell.dart';

/// The tab shell, remembered so account routes beside the branches can still
/// highlight a tab and switch to it.
class ShellTab {
  const ShellTab({required this.shell, required this.index});

  final StatefulNavigationShell shell;
  final int index;
}

class ShellTabHandle extends Notifier<ShellTab?> {
  @override
  ShellTab? build() => null;

  void publish(StatefulNavigationShell shell) {
    if (state?.shell == shell && state?.index == shell.currentIndex) {
      return;
    }
    state = ShellTab(shell: shell, index: shell.currentIndex);
  }
}

final shellTabProvider = NotifierProvider<ShellTabHandle, ShellTab?>(
  ShellTabHandle.new,
);

/// Publishes the tab shell from inside the branch navigator.
///
/// The index lives on the shell object and changes in place, so this widget
/// remembers the last index it sent and publishes again when that changes.
class PublishNavigationShell extends ConsumerStatefulWidget {
  const PublishNavigationShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<PublishNavigationShell> createState() =>
      _PublishNavigationShellState();
}

class _PublishNavigationShellState
    extends ConsumerState<PublishNavigationShell> {
  StatefulNavigationShell? _published;
  int? _publishedIndex;

  @override
  void initState() {
    super.initState();
    _schedulePublish();
  }

  @override
  void didUpdateWidget(PublishNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePublish();
  }

  void _schedulePublish() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final shell = widget.navigationShell;
      if (_published == shell && _publishedIndex == shell.currentIndex) {
        return;
      }
      _published = shell;
      _publishedIndex = shell.currentIndex;
      ref.read(shellTabProvider.notifier).publish(shell);
    });
  }

  @override
  Widget build(BuildContext context) => widget.navigationShell;
}

/// Frame shared by every tab: the frosted header above, the nav below, and
/// the active branch between them.
///
/// The header and nav float over the content rather than boxing it in, which
/// is what gives the design its frosted-glass edges. Content therefore has to
/// pad itself clear of both — use [ShellScrollView] rather than doing it by
/// hand.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  /// The shell navigator: the active tab, or an account page pushed over it.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(shellTabProvider);
    final index = tab?.index ?? 0;
    void selectTab(int selected) => _selectTab(context, ref, selected);
    void addPlant() => context.pushNamed(AddPlantRoute.name);

    if (AppLayout.isWide(context)) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopSidebar(
                currentIndex: index,
                onSelect: selectTab,
                onAdd: addPlant,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth.clamp(
                      0.0,
                      AppLayout.contentMaxWidth,
                    );
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: width,
                        height: constraints.maxHeight,
                        child: Column(
                          children: [
                            ?_pushedHeader(context),
                            Expanded(
                              child: _BranchFade(index: index, child: child),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          Positioned.fill(
            child: _BranchFade(index: index, child: child),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _header(context)),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AppBottomNav(
              currentIndex: index,
              onSelect: selectTab,
              onAdd: addPlant,
            ),
          ),
        ],
      ),
    );
  }

  void _selectTab(BuildContext context, WidgetRef ref, int index) {
    final tab = ref.read(shellTabProvider);
    if (tab == null) {
      return;
    }
    final onAccount = isAccountRoute(GoRouterState.of(context).topRoute?.name);
    if (onAccount) {
      // Leave the account pages for the tab that was tapped. `go` drops the
      // profile stack; the branch underneath keeps the tab the gardener was on
      // until this choice.
      context.go(_tabPath(index));
      return;
    }
    tab.shell.goBranch(
      index,
      // Tapping the tab you are already on returns to its root,
      // the usual way to escape a stack you have pushed into.
      initialLocation: index == tab.index,
    );
  }

  String _tabPath(int index) => switch (index) {
    0 => HomeRoute.path,
    1 => MyPlantsRoute.path,
    2 => ChoresRoute.path,
    _ => WisdomRoute.path,
  };

  /// A back bar for screens pushed over a tab. Tab roots draw their own title.
  Widget? _pushedHeader(BuildContext context) {
    final routeName = GoRouterState.of(context).topRoute?.name;
    if (routeName == ProfileRoute.name) {
      return FlowHeader(
        eyebrow: 'YOUR ACCOUNT',
        title: 'Profile',
        onBack: () => context.canPop()
            ? context.pop()
            : context.goNamed(HomeRoute.name),
        action: const HeaderBell(showUnread: true),
      );
    }
    if (routeName == AccountSettingsRoute.name ||
        routeName == SupportRoute.name) {
      return FlowHeader(
        eyebrow: 'YOUR ACCOUNT',
        title: routeName == SupportRoute.name ? 'Support' : 'Settings',
        onBack: () => context.canPop()
            ? context.pop()
            : context.goNamed(ProfileRoute.name),
        action: const HeaderBell(showUnread: true),
      );
    }
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
    return null;
  }

  /// The bar at the top of the frame.
  ///
  /// Home keeps the logo bar. The other tab roots keep the logo and center
  /// a weather line.
  /// A pushed screen keeps the nav, and gets [FlowHeader] for a way back.
  Widget _header(BuildContext context) {
    final routeName = GoRouterState.of(context).topRoute?.name;
    if (routeName == ProfileRoute.name) {
      return const AppHeader(showBell: true);
    }
    if (routeName == AccountSettingsRoute.name ||
        routeName == SupportRoute.name) {
      return FlowHeader(
        eyebrow: 'YOUR ACCOUNT',
        title: routeName == SupportRoute.name ? 'Support' : 'Settings',
        onBack: () => context.canPop()
            ? context.pop()
            : context.goNamed(ProfileRoute.name),
        action: const HeaderBell(showUnread: true),
      );
    }
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
    return AppHeader(
      showWeather: routeName != HomeRoute.name,
      onProfile: () => context.pushNamed(ProfileRoute.name),
    );
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
    final wide = AppLayout.isWide(context);
    return SingleChildScrollView(
      padding: wide
          ? EdgeInsets.fromLTRB(
              AppLayout.contentPadding,
              AppLayout.contentPadding,
              AppLayout.contentPadding,
              AppLayout.contentPadding + insets.bottom,
            )
          : EdgeInsets.only(
              top:
                  AppSizes.headerHeight +
                  AppSizes.headerContentGap +
                  insets.top,
              bottom: AppSizes.navHeight + 32 + insets.bottom,
              left: AppSizes.screenPadding,
              right: AppSizes.screenPadding,
            ),
      child: child,
    );
  }
}
