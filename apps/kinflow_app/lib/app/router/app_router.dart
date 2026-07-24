import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/screens/not_found_screen.dart';
import 'package:kinflow_app/features/foundation/presentation/screens/foundation_home_screen.dart';

abstract final class AppRoutes {
  static const String home = '/';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: FoundationHomeScreen());
        },
      ),
    ],
    errorPageBuilder: (BuildContext context, GoRouterState state) {
      return NoTransitionPage<void>(
        key: state.pageKey,
        child: const NotFoundScreen(),
      );
    },
  );

  ref.onDispose(router.dispose);
  return router;
});
