import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/screens/not_found_screen.dart';
import 'package:kinflow_app/app/router/app_route_recovery_policy.dart';
import 'package:kinflow_app/app/router/app_routes.dart';
import 'package:kinflow_app/app/router/auth_route_guard.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/analytics/presentation/screens/analytics_privacy_screen.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/screens/auth_loading_screen.dart';
import 'package:kinflow_app/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:kinflow_app/features/billing/presentation/screens/subscription_settings_screen.dart';
import 'package:kinflow_app/features/calendar/presentation/screens/calendar_events_screen.dart';
import 'package:kinflow_app/features/calendar/presentation/calendar_import_route_context.dart';
import 'package:kinflow_app/features/calendar/presentation/screens/calendar_import_screen.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/screens/chore_occurrence_target_screen.dart';
import 'package:kinflow_app/features/chores/presentation/screens/guided_chore_setup_screen.dart';
import 'package:kinflow_app/features/chores/presentation/screens/one_time_chore_creation_screen.dart';
import 'package:kinflow_app/features/chores/presentation/screens/one_time_chore_trash_screen.dart';
import 'package:kinflow_app/features/chores/presentation/screens/today_chores_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_onboarding_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_selection_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_members_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_invite_creation_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/household_invite_screen.dart';
import 'package:kinflow_app/features/household/presentation/screens/invite_link_capture_screen.dart';
import 'package:kinflow_app/features/notifications/presentation/screens/notification_center_screen.dart';
import 'package:kinflow_app/features/platform_capabilities/presentation/screens/platform_capabilities_screen.dart';
import 'package:kinflow_app/features/settings/presentation/screens/account_deletion_screen.dart';
import 'package:kinflow_app/features/settings/presentation/screens/data_export_screen.dart';
import 'package:kinflow_app/features/settings/presentation/screens/diagnostic_report_screen.dart';
import 'package:kinflow_app/features/settings/presentation/screens/household_privacy_screen.dart';
import 'package:kinflow_app/features/settings/presentation/screens/legal_support_screen.dart';
import 'package:kinflow_app/features/settings/presentation/screens/profile_preferences_screen.dart';
import 'package:kinflow_app/features/settings/presentation/screens/settings_screen.dart';

export 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final _AuthRouterRefreshNotifier refreshNotifier =
      _AuthRouterRefreshNotifier();
  const AppRouteRecoveryPolicy recoveryPolicy = AppRouteRecoveryPolicy();
  final AuthRouteGuard authRouteGuard = AuthRouteGuard(
    authLoadingPath: AppRoutes.authLoading,
    guidedChoreSetupPath: AppRoutes.guidedChoreSetup,
    householdOnboardingPath: AppRoutes.householdOnboarding,
    invitePath: AppRoutes.invite,
    rootPath: AppRoutes.home,
    settingsPath: AppRoutes.settings,
    signInPath: AppRoutes.signIn,
    todayPath: AppRoutes.today,
    intentResolver: recoveryPolicy.intentFor,
    continuationResolver: recoveryPolicy.intentForContinuationMarker,
  );
  ref.listen<AuthLifecycleState>(authLifecycleProvider, (
    AuthLifecycleState? previous,
    AuthLifecycleState next,
  ) {
    authRouteGuard.handleAuthStateTransition(previous, next);
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
        path: AppRoutes.guidedChoreSetup,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: GuidedChoreSetupScreen());
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
        path: AppRoutes.family,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: HouseholdMembersScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.householdMembers,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: HouseholdMembersScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.today,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: TodayChoresScreen(key: ValueKey<String>('route.today')),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.chores,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: TodayChoresScreen.chores(
              key: ValueKey<String>('route.chores'),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.calendar,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: CalendarEventsScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.calendarImport,
        redirect: (BuildContext context, GoRouterState state) {
          final Object? extra = state.extra;
          final activeHousehold = ref
              .read(authLifecycleProvider)
              .activeHousehold;
          return extra is! CalendarImportRouteContext ||
                  activeHousehold == null ||
                  extra.householdId != activeHousehold.householdId
              ? AppRoutes.calendar
              : null;
        },
        pageBuilder: (BuildContext context, GoRouterState state) {
          return NoTransitionPage<void>(
            child: CalendarImportScreen(
              routeContext: state.extra! as CalendarImportRouteContext,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.calendarEvent,
        redirect: (BuildContext context, GoRouterState state) {
          return CalendarEventOccurrenceId.tryParse(
                    state.pathParameters['occurrenceId'] ?? '',
                  ) ==
                  null
              ? AppRoutes.routeNotFound
              : null;
        },
        pageBuilder: (BuildContext context, GoRouterState state) {
          return NoTransitionPage<void>(
            child: CalendarEventsScreen(
              initialOccurrenceId: CalendarEventOccurrenceId.tryParse(
                state.pathParameters['occurrenceId'] ?? '',
              ),
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.choreCreate,
        redirect: (BuildContext context, GoRouterState state) {
          return ChoreLocalDate.tryParse(
                    state.uri.queryParameters['due'] ?? '',
                  ) ==
                  null
              ? AppRoutes.routeNotFound
              : null;
        },
        pageBuilder: (BuildContext context, GoRouterState state) {
          final ChoreLocalDate dueLocalDate = ChoreLocalDate.tryParse(
            state.uri.queryParameters['due'] ?? '',
          )!;
          return NoTransitionPage<void>(
            child: OneTimeChoreCreationScreen(
              initialDueLocalDate: dueLocalDate,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.choreOccurrence,
        redirect: (BuildContext context, GoRouterState state) {
          return ChoreOccurrenceId.tryParse(
                    state.pathParameters['occurrenceId'] ?? '',
                  ) ==
                  null
              ? AppRoutes.routeNotFound
              : null;
        },
        pageBuilder: (BuildContext context, GoRouterState state) {
          return NoTransitionPage<void>(
            child: ChoreOccurrenceTargetScreen(
              occurrenceId: ChoreOccurrenceId.tryParse(
                state.pathParameters['occurrenceId'] ?? '',
              )!,
            ),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.choreTrash,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: OneTimeChoreTrashScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: NotificationCenterScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: SettingsScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.householdSwitch,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: HouseholdSelectionScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.subscription,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: SubscriptionSettingsScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.profilePreferences,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: ProfilePreferencesScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.dataExport,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: DataExportScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.diagnostics,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: DiagnosticReportScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.deviceCapabilities,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(
            child: PlatformCapabilitiesScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.householdPrivacy,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: HouseholdPrivacyScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.accountDeletion,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: AccountDeletionScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.analyticsPrivacy,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: AnalyticsPrivacyScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.legalSupport,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: LegalSupportScreen());
        },
      ),
      GoRoute(
        path: AppRoutes.routeNotFound,
        pageBuilder: (BuildContext context, GoRouterState state) {
          return const NoTransitionPage<void>(child: NotFoundScreen());
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
