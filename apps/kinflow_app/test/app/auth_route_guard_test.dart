import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/router/auth_route_guard.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';

import '../support/fakes/fake_auth_dependencies.dart';

void main() {
  late AuthRouteGuard guard;

  setUp(() {
    guard = AuthRouteGuard(
      authLoadingPath: '/auth/loading',
      homePath: '/',
      signInPath: '/sign-in',
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

  test('unauthenticated access is redirected to Google sign-in', () {
    expect(
      guard.redirect(const AuthUnauthenticated(), Uri.parse('/household')),
      '/sign-in',
    );
    expect(
      guard.redirect(const AuthUnauthenticated(), Uri.parse('/sign-in')),
      isNull,
    );
  });

  test('authenticated state can access protected and unknown routes', () {
    final AuthAuthenticatedNoHousehold authenticated =
        AuthAuthenticatedNoHousehold(authSessionFixture());

    expect(guard.redirect(authenticated, Uri.parse('/')), isNull);
    expect(guard.redirect(authenticated, Uri.parse('/missing')), isNull);
  });

  test('restores only the path and drops sensitive query or fragment data', () {
    guard.redirect(
      const AuthUnauthenticated(),
      Uri.parse('/invite/continue?sensitive=discarded#callback'),
    );

    expect(
      guard.redirect(
        AuthAuthenticatedNoHousehold(authSessionFixture()),
        Uri.parse('/sign-in'),
      ),
      '/invite/continue',
    );
  });

  test('locked state never permits a protected route', () {
    expect(guard.redirect(const AuthLocked(), Uri.parse('/')), '/sign-in');
  });
}
