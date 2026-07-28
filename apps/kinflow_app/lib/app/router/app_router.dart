import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/screens/not_found_screen.dart';
import 'package:kinflow_app/app/router/auth_route_guard.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:kinflow_app/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_onboarding_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_invite_creation_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_invite_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/invite_link_capture_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/today_empty_screen.dart';

abstract final class AppRoutes {
  static const String home = '/';
  static const String authLoading = '/auth/loading';
  static const String householdOnboarding = '/onboarding/household';
  static const String invite = '/invite';
  static const String inviteCapture = '/invite/:token';
  static const String inviteCreate = '/family/invite';
  static const String signIn = '/sign-in';
  static const String today = '/today';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final _AuthRouterRefreshNotifier refreshNotifier =
      _AuthRouterRefreshNotifier();
  final AuthRouteGuard authRouteGuard = AuthRouteGuard(
    authLoadingPath: AppRoutes.authLoading,
    householdOnboardingPath: AppRoutes.householdOnboarding,
    invitePath: AppRoutes.invite,
    rootPath: AppRoutes.home,
    signInPath: AppRoutes.signIn,
    todayPath: AppRoutes.today,
  );
  ref.listen<AuthLifecycleState>(authLifecycleProvider, (
    AuthLifecycleState? previous,
    AuthLifecycleState next,
  ) {
    refreshNotifier.refresh();
  });

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      return authRouteGuard.redirect(
        ref.read(authLifecycleProvider),
        state.uri,
      );
    },
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: SizedBox.shrink());
        },
      ),
      GoRoute(
        path: AppRoutes.authLoading,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: AuthLoadingScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.signIn,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: SignInScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.householdOnboarding,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: HouseholdOnboardingScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.invite,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: HouseholdInviteScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.inviteCapture,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return NoTransitionPage<void>(
            child: InviteLinkCaptureScreen(
              rawToken: state.pathParameters['token'] ?? '',
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.inviteCreate,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: HouseholdInviteCreationScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.today,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: TodayEmptyScreen());
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

  ref.onDispose(() {
    router.dispose();
    refreshNotifier.dispose();
  });
  return router;
});

final class _AuthRouterRefreshNotifier extends ChangeNotifier {
  void refresh() {
    notifyListeners();
  }
}
