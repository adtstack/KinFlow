import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/router/auth_route_guard.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';

import '../support/fakes/fake_auth_dependencies.dart';
import '../support/fakes/fake_household_dependencies.dart';

void main() {
  late AuthRouteGuard guard;

  setUp(() {
    guard = AuthRouteGuard(
      authLoadingPath: '/auth/loading',
      householdOnboardingPath: '/onboarding/household',
      invitePath: '/invite',
      rootPath: '/',
      signInPath: '/sign-in',
      todayPath: '/today',
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
      '/sign-in',
    );
    expect(
      guard.redirect(const AuthUnauthenticated(), Uri.parse('/sign-in')),
      isNull,
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
  });

  test('active household enters Today and retains unknown-route handling', () {
    final AuthAuthenticatedActiveHousehold authenticated =
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        );

    expect(guard.redirect(authenticated, Uri.parse('/')), '/today');
    expect(guard.redirect(authenticated, Uri.parse('/today')), isNull);
    expect(guard.redirect(authenticated, Uri.parse('/missing')), isNull);
    expect(
      guard.redirect(authenticated, Uri.parse('/onboarding/household')),
      '/today',
    );
  });

  test('restores only a protected path and drops query or fragment data', () {
    guard.redirect(
      const AuthUnauthenticated(),
      Uri.parse('/household/settings?sensitive=discarded#callback'),
    );

    expect(
      guard.redirect(
        AuthAuthenticatedActiveHousehold(
          authSessionFixture(),
          activeHouseholdFixture(),
        ),
        Uri.parse('/sign-in'),
      ),
      '/household/settings',
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
    expect(guard.redirect(const AuthLocked(), Uri.parse('/today')), '/sign-in');
  });
}
