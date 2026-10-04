import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_screen.dart';

/// Application routes.
///
/// Only the garden home exists so far. When the auth screens land, add a
/// `redirect` here that watches `authStateProvider` and sends signed-out users
/// to the sign-in route — doing it in the router keeps every screen free of
/// its own auth check.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: HomeRoute.path,
    routes: [
      GoRoute(
        path: HomeRoute.path,
        name: HomeRoute.name,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});

abstract final class HomeRoute {
  static const name = 'home';
  static const path = '/';
}
