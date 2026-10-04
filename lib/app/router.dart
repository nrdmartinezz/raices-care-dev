import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/auth_mode.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/care/presentation/chores_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/plants/presentation/add_plant_screen.dart';
import '../features/plants/presentation/my_plants_screen.dart';
import '../features/plants/presentation/plant_detail_screen.dart';
import '../features/wisdom/presentation/wisdom_screen.dart';
import 'shell/app_shell.dart';

abstract final class HomeRoute {
  static const name = 'home';
  static const path = '/';
}

abstract final class SplashRoute {
  static const name = 'splash';
  static const path = '/splash';
}

abstract final class SignInRoute {
  static const name = 'signIn';
  static const path = '/sign-in';
}

abstract final class SignUpRoute {
  static const name = 'signUp';
  static const path = '/sign-up';
}

abstract final class MyPlantsRoute {
  static const name = 'myPlants';
  static const path = '/plants';
}

/// One plant, nested under the My Plants tab so the nav stays visible.
abstract final class PlantDetailRoute {
  static const name = 'plantDetail';
  static const path = ':plantId';
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

abstract final class OnboardingRoute {
  static const name = 'onboarding';
  static const path = '/onboarding';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Application routes.
///
/// The four tabs are branches of a [StatefulShellRoute], so each keeps its own
/// navigation stack and scroll position while you move between them. Add-plant
/// is deliberately outside the shell: it renders over the nav instead of
/// beside it.
///
/// Auth and onboarding are gated here rather than in each screen, so no
/// screen has to check for a session or a finished profile before it renders.
final routerProvider = Provider<GoRouter>((ref) {
  // go_router does not re-run `redirect` when a provider changes, so the auth
  // status is bridged to something it will listen to. Rebuilding the GoRouter
  // instead would work, but would discard the navigation stack every time the
  // session changed.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authStatusProvider, (_, _) => refresh.value++);
  ref.listen(onboardingGateProvider, (_, _) => refresh.value++);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: SplashRoute.path,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authStatusProvider);
      final location = state.matchedLocation;
      final onSplash = location == SplashRoute.path;
      final onAuth =
          location == SignInRoute.path || location == SignUpRoute.path;
      final onOnboarding = location == OnboardingRoute.path;

      return switch (status) {
        // Hold on the splash until the session is known. Treating this as
        // signed out would flash the sign-in screen at a returning user.
        AuthStatus.unknown => onSplash ? null : SplashRoute.path,
        AuthStatus.signedOut => onAuth ? null : SignInRoute.path,
        AuthStatus.signedIn => switch (ref.read(onboardingGateProvider)) {
          // The profile stream is the second thing to wait for. Sending a
          // signed-in gardener home before it resolves would skip onboarding
          // for anyone whose document is a moment behind the session.
          OnboardingGate.pending => onSplash ? null : SplashRoute.path,
          OnboardingGate.required => onOnboarding ? null : OnboardingRoute.path,
          OnboardingGate.finished =>
            (onAuth || onSplash || onOnboarding) ? HomeRoute.path : null,
        },
      };
    },
    routes: [
      GoRoute(
        path: SplashRoute.path,
        name: SplashRoute.name,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: SignInRoute.path,
        name: SignInRoute.name,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: SignUpRoute.path,
        name: SignUpRoute.name,
        builder: (context, state) =>
            const AuthScreen(initialMode: AuthMode.signUp),
      ),
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
                routes: [
                  GoRoute(
                    path: PlantDetailRoute.path,
                    name: PlantDetailRoute.name,
                    builder: (context, state) => PlantDetailScreen(
                      plantId: state.pathParameters['plantId']!,
                      // Set by the add-plant flow, so the profile can open
                      // with its "added" banner and not show it again later.
                      isNew: state.uri.queryParameters['new'] == '1',
                    ),
                  ),
                ],
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
        path: OnboardingRoute.path,
        name: OnboardingRoute.name,
        builder: (context, state) => const OnboardingScreen(),
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
