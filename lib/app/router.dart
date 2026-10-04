import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/care/presentation/chores_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/plants/presentation/add_plant_screen.dart';
import '../features/plants/presentation/my_plants_screen.dart';
import '../features/wisdom/presentation/wisdom_screen.dart';
import 'shell/app_shell.dart';

abstract final class HomeRoute {
  static const name = 'home';
  static const path = '/';
}

abstract final class MyPlantsRoute {
  static const name = 'myPlants';
  static const path = '/plants';
}

abstract final class ChoresRoute {
  static const name = 'chores';
  static const path = '/chores';
}

abstract final class WisdomRoute {
  static const name = 'wisdom';
  static const path = '/wisdom';
}

abstract final class AddPlantRoute {
  static const name = 'addPlant';
  static const path = '/add-plant';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Application routes.
///
/// The four tabs are branches of a [StatefulShellRoute], so each keeps its own
/// navigation stack and scroll position while you move between them. Add-plant
/// is deliberately outside the shell: it renders over the nav instead of
/// beside it.
///
/// When the auth screens land, add a `redirect` here that watches
/// `authStateProvider` and sends signed-out users to the sign-in route —
/// doing it in the router keeps every screen free of its own auth check.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: HomeRoute.path,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // Branch order must match AppTab, which the nav indexes into.
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: HomeRoute.path,
                name: HomeRoute.name,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MyPlantsRoute.path,
                name: MyPlantsRoute.name,
                builder: (context, state) => const MyPlantsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ChoresRoute.path,
                name: ChoresRoute.name,
                builder: (context, state) => const ChoresScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: WisdomRoute.path,
                name: WisdomRoute.name,
                builder: (context, state) => const WisdomScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AddPlantRoute.path,
        name: AddPlantRoute.name,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddPlantScreen(),
      ),
    ],
  );
});
