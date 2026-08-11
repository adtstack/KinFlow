import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/router/app_route_recovery_policy.dart';
import 'package:kinflow_app/app/router/auth_route_guard.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';

import '../support/fakes/fake_auth_dependencies.dart';
import '../support/fakes/fake_household_dependencies.dart';

void main() {
  late AuthRouteGuard guard;

  setUp(() {
    const AppRouteRecoveryPolicy recoveryPolicy = AppRouteRecoveryPolicy();
    guard = AuthRouteGuard(
      authLoadingPath: '/auth/loading',
      guidedChoreSetupPath: '/onboarding/chores',
      householdOnboardingPath: '/onboarding/household',
      invitePath: '/invite',
      rootPath: '/',
      settingsPath: '/settings',
      signInPath: '/sign-in',
      todayPath: '/today',
      intentResolver: recoveryPolicy.intentFor,
      continuationResolver: recoveryPolicy.intentForContinuationMarker,
    );
  });

  test('bootstrapping redirects to the auth loading route', () {
    expect(
      guard.redirect(const AuthBootstrapping(), Uri.parse('/household')),
      '/auth/loading',
    );
    expect(
      guard.redirect(const AuthBootstrapping(), Uri.parse('/auth/loading')),
      isNull,
    );
  });

  test('household resolution and recovery cannot expose product routes', () {
    final session = authSessionFixture();

    expect(
      guard.redirect(AuthResolvingHousehold(session), Uri.parse('/today')),
      '/auth/loading',
    );
    expect(
      guard.redirect(
        AuthHouseholdResolutionFailed(
          session,
          const HouseholdFailure(HouseholdFailureKind.temporarilyUnavailable),
        ),
        Uri.parse('/auth/loading'),
      ),
      isNull,
    );
  });

  test('unauthenticated access is redirected to Google sign-in', () {
    expect(
      guard.redirect(const AuthUnauthenticated(), Uri.parse('/today')),
      '/sign-in?continue=today',
    );
    expect(
      guard.redirect(const AuthUnauthenticated(), Uri.parse('/sign-in')),
      isNull,
    );
    expect(
      guard.redirect(
        const AuthUnauthenticated(),
        Uri.parse('/onboarding/household'),
      ),
      '/sign-in',
    );
  });

  test('authenticated user without a household is forced to onboarding', () {
    final AuthAuthenticatedNoHousehold authenticated =
        AuthAuthenticatedNoHousehold(authSessionFixture());

    expect(
      guard.redirect(authenticated, Uri.parse('/today')),
      '/onboarding/household',
    );
    expect(
      guard.redirect(authenticated, Uri.parse('/onboarding/household')),
      isNull,
    );
    expect(
      guard.redirect(authenticated, Uri.parse('/onboarding/chores')),
      '/onboarding/household',
    );
  });

  test(
    'authenticated user without a household can manage account deletion',
    () {
      final AuthAuthenticatedNoHousehold authenticated =
          AuthAuthenticatedNoHousehold(authSessionFixture());

      expect(
        guard.redirect(authenticated, Uri.parse('/settings/account-deletion')),
        isNull,
      );
      expect(guard.redirect(authenticated, Uri.parse('/settings')), isNull);
    },
  );

  test(
    'diagnostic settings route is authenticated but household independent',
    () {
      expect(
        guard.redirect(
          const AuthUnauthenticated(),
          Uri.parse('/settings/diagnostics'),
        ),
        '/sign-in?continue=settings',
      );
      expect(
        guard.redirect(
          AuthAuthenticatedNoHousehold(authSessionFixture()),
          Uri.parse('/settings/diagnostics'),
        ),
        isNull,
      );
    },
  );

  test('restores an intended account deletion path without a household', () {
    guard.redirect(
      const AuthUnauthenticated(),
      Uri.parse('/settings/account-deletion?discard=this'),
    );

    expect(
      guard.redirect(
        AuthAuthenticatedNoHousehold(authSessionFixture()),
        Uri.parse('/sign-in?continue=settings'),
      ),
      '/settings/account-deletion',
    );
  });

  test('active household enters Today and retains unknown-route handling', () {
    final AuthAuthenticatedActiveHousehold authenticated =
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        );

    expect(guard.redirect(authenticated, Uri.parse('/')), '/today');
    expect(guard.redirect(authenticated, Uri.parse('/today')), isNull);
    expect(
      guard.redirect(authenticated, Uri.parse('/onboarding/chores')),
      isNull,
    );
    expect(
      guard.redirect(authenticated, Uri.parse('/missing')),
      '/route-recovery/not-found',
    );
    expect(
      guard.redirect(authenticated, Uri.parse('/onboarding/household')),
      '/today',
    );
  });

  test('active direct URL is canonicalized before product rendering', () {
    final AuthAuthenticatedActiveHousehold authenticated =
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        );
    const String occurrenceId = '44444444-4444-4444-8444-444444444444';

    expect(
      guard.redirect(
        authenticated,
        Uri.parse(
          '/calendar/event/$occurrenceId?access_token=discarded#callback',
        ),
      ),
      '/calendar/event/$occurrenceId',
    );
  });

  test('restores a safe protected path and drops unrelated URL data', () {
    guard.redirect(
      const AuthUnauthenticated(),
      Uri.parse('/settings/account-deletion?sensitive=discarded#callback'),
    );

    expect(
      guard.redirect(
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        ),
        Uri.parse('/sign-in?continue=settings'),
      ),
      '/settings/account-deletion',
    );
  });

  test(
    'invitation routes stay public and raw token paths are never retained',
    () {
      const String rawToken = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';

      expect(
        guard.redirect(
          const AuthBootstrapping(),
          Uri.parse('/invite/$rawToken'),
        ),
        isNull,
      );
      expect(
        guard.redirect(
          const AuthUnauthenticated(),
          Uri.parse('/invite/$rawToken'),
        ),
        isNull,
      );
      expect(
        guard.redirect(
          AuthAuthenticatedActiveHousehold(
            authSessionFixture(),
            activeHouseholdFixture(),
          ),
          Uri.parse('/sign-in'),
        ),
        '/today',
      );
    },
  );

  test('safe invitation continuation marker survives authentication', () {
    expect(
      guard.redirect(
        const AuthUnauthenticated(),
        Uri.parse('/sign-in?continue=invite&token=discarded'),
      ),
      isNull,
    );
    expect(
      guard.redirect(
        AuthAuthenticatedNoHousehold(authSessionFixture()),
        Uri.parse('/sign-in?continue=invite'),
      ),
      '/invite',
    );
  });

  test('first-household onboarding clears an unrelated intended route', () {
    guard.redirect(const AuthUnauthenticated(), Uri.parse('/missing'));

    expect(
      guard.redirect(
        AuthAuthenticatedNoHousehold(authSessionFixture()),
        Uri.parse('/sign-in'),
      ),
      '/onboarding/household',
    );
    expect(
      guard.redirect(
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        ),
        Uri.parse('/onboarding/household'),
      ),
      '/today',
    );
  });

  test('locked state never permits a protected route', () {
    expect(
      guard.redirect(const AuthLocked(), Uri.parse('/today')),
      '/sign-in?continue=today',
    );
    expect(
      guard.redirect(const AuthLocked(), Uri.parse('/onboarding/chores')),
      '/sign-in?continue=chores',
    );
  });

  test('preserves only the valid due-date query for chore creation', () {
    expect(
      guard.redirect(
        const AuthUnauthenticated(),
        Uri.parse('/chores/new?due=2026-08-10&token=discarded#callback'),
      ),
      '/sign-in?continue=chores',
    );

    expect(
      guard.redirect(
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        ),
        Uri.parse('/sign-in?continue=chores'),
      ),
      '/chores/new?due=2026-08-10',
    );
  });

  test('a fresh guard restores only the coarse fixed continuation', () {
    const AppRouteRecoveryPolicy recoveryPolicy = AppRouteRecoveryPolicy();
    final AuthRouteGuard refreshedGuard = AuthRouteGuard(
      authLoadingPath: '/auth/loading',
      guidedChoreSetupPath: '/onboarding/chores',
      householdOnboardingPath: '/onboarding/household',
      invitePath: '/invite',
      rootPath: '/',
      settingsPath: '/settings',
      signInPath: '/sign-in',
      todayPath: '/today',
      intentResolver: recoveryPolicy.intentFor,
      continuationResolver: recoveryPolicy.intentForContinuationMarker,
    );

    expect(
      refreshedGuard.redirect(
        const AuthUnauthenticated(),
        Uri.parse('/sign-in?continue=calendar&occurrenceId=discarded#callback'),
      ),
      isNull,
    );
    expect(
      refreshedGuard.redirect(
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        ),
        Uri.parse('/sign-in?continue=calendar'),
      ),
      '/calendar',
    );
  });

  test('duplicate and unknown continuation markers are rejected', () {
    expect(
      guard.redirect(
        const AuthUnauthenticated(),
        Uri.parse('/sign-in?continue=calendar&continue=settings'),
      ),
      isNull,
    );
    expect(
      guard.redirect(
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        ),
        Uri.parse('/sign-in?continue=calendar&continue=settings'),
      ),
      '/today',
    );

    expect(
      guard.redirect(
        const AuthUnauthenticated(),
        Uri.parse('/sign-in?continue=%2Fsettings'),
      ),
      isNull,
    );
    expect(
      guard.redirect(
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        ),
        Uri.parse('/sign-in?continue=%2Fsettings'),
      ),
      '/today',
    );
  });

  test('plain sign-in navigation cancels a stale continuation', () {
    guard.redirect(
      const AuthUnauthenticated(),
      Uri.parse('/settings/account-deletion'),
    );

    expect(
      guard.redirect(const AuthUnauthenticated(), Uri.parse('/sign-in')),
      isNull,
    );
    expect(
      guard.redirect(
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        ),
        Uri.parse('/sign-in'),
      ),
      '/today',
    );
  });

  test('session expiry retains the exact same-runtime protected route', () {
    final AuthAuthenticatedActiveHousehold authenticated =
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        );
    const AuthLocked expired = AuthLocked(
      failure: AuthFailure(AuthFailureKind.sessionExpired),
    );
    const String occurrenceId = '44444444-4444-4444-8444-444444444444';

    guard.handleAuthStateTransition(authenticated, expired);
    expect(
      guard.redirect(
        expired,
        Uri.parse('/calendar/event/$occurrenceId?token=discarded#callback'),
      ),
      '/sign-in?continue=calendar',
    );
    expect(
      guard.redirect(authenticated, Uri.parse('/sign-in?continue=calendar')),
      '/calendar/event/$occurrenceId',
    );
  });

  test('session expiry never transfers an exact route to another user', () {
    final AuthAuthenticatedActiveHousehold authenticated =
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        );
    const AuthLocked expired = AuthLocked(
      failure: AuthFailure(AuthFailureKind.sessionExpired),
    );
    final differentSession = authSessionFixture(
      userId: '77777777-7777-4777-8777-777777777777',
    );

    guard.handleAuthStateTransition(authenticated, expired);
    expect(
      guard.redirect(
        expired,
        Uri.parse('/calendar/event/44444444-4444-4444-8444-444444444444'),
      ),
      '/sign-in?continue=calendar',
    );

    final AuthResolvingHousehold resolving = AuthResolvingHousehold(
      differentSession,
    );
    guard.handleAuthStateTransition(expired, resolving);
    final AuthAuthenticatedActiveHousehold differentUser =
        AuthAuthenticatedActiveHousehold(
          differentSession,
          activeHouseholdFixture(),
        );
    guard.handleAuthStateTransition(resolving, differentUser);

    expect(
      guard.redirect(differentUser, Uri.parse('/sign-in?continue=calendar')),
      '/today',
    );
  });

  test('explicit logout discards the previous protected destination', () {
    final AuthAuthenticatedActiveHousehold authenticated =
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        );
    const AuthLocked locked = AuthLocked();

    guard.handleAuthStateTransition(authenticated, locked);
    expect(
      guard.redirect(
        locked,
        Uri.parse('/calendar/event/44444444-4444-4444-8444-444444444444'),
      ),
      '/sign-in',
    );
    expect(
      guard.redirect(const AuthUnauthenticated(), Uri.parse('/sign-in')),
      isNull,
    );
    expect(guard.redirect(authenticated, Uri.parse('/sign-in')), '/today');
  });

  test('household switch forces a safe primary destination', () {
    final AuthAuthenticatedActiveHousehold first =
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        );
    final AuthAuthenticatedActiveHousehold second =
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(
            householdId: '55555555-5555-4555-8555-555555555555',
            memberId: '66666666-6666-4666-8666-666666666666',
          ),
        );

    guard.handleAuthStateTransition(first, second);
    expect(
      guard.redirect(
        second,
        Uri.parse('/chores/occurrence/44444444-4444-4444-8444-444444444444'),
      ),
      '/today',
    );
  });
}
