import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/router/app_route_recovery_policy.dart';
import 'package:kinflow_app/app/router/app_routes.dart';
import 'package:kinflow_app/app/router/auth_route_guard.dart';

void main() {
  const AppRouteRecoveryPolicy policy = AppRouteRecoveryPolicy();
  const String occurrenceId = '44444444-4444-4444-8444-444444444444';

  test('retains an exact valid resource path only in the in-memory intent', () {
    final AuthRouteIntent intent = policy.intentFor(
      Uri.parse(
        '/calendar/event/$occurrenceId?access_token=discarded#callback',
      ),
    );

    expect(intent.location.toString(), '/calendar/event/$occurrenceId');
    expect(intent.continuationMarker, 'calendar');
    expect(intent.continuationMarker, isNot(contains(occurrenceId)));
    expect(intent.location.hasQuery, isFalse);
    expect(intent.location.hasFragment, isFalse);
  });

  test('canonicalizes the only replayable chore creation query', () {
    final AuthRouteIntent intent = policy.intentFor(
      Uri.parse('/chores/new?due=2026-08-10&access_token=discarded#callback'),
    );

    expect(intent.location.toString(), '/chores/new?due=2026-08-10');
    expect(intent.continuationMarker, 'chores');
  });

  test('invalid route parameters resolve to a fixed not-found route', () {
    expect(
      policy
          .intentFor(Uri.parse('/calendar/event/not-a-uuid?token=discarded'))
          .location
          .toString(),
      AppRoutes.routeNotFound,
    );
    expect(
      policy
          .intentFor(Uri.parse('/chores/new?due=2026-02-31'))
          .location
          .toString(),
      AppRoutes.routeNotFound,
    );
    expect(
      policy.intentFor(Uri.parse('/unknown/private/value')).location.toString(),
      AppRoutes.routeNotFound,
    );
    expect(
      policy.intentFor(Uri.parse('/unknown/private/value')).continuationMarker,
      AppRouteRecoveryPolicy.notFoundMarker,
    );
  });

  test('non-replayable import route falls back to Calendar', () {
    final AuthRouteIntent intent = policy.intentFor(
      Uri.parse('/calendar/import?payload=discarded'),
    );

    expect(intent.location.toString(), AppRoutes.calendar);
    expect(intent.continuationMarker, 'calendar');
    expect(intent.canonicalizeWhenAuthenticated, isFalse);
  });

  test('fixed continuation markers restore only coarse destinations', () {
    expect(
      policy.intentForContinuationMarker('notifications')?.location.toString(),
      AppRoutes.notifications,
    );
    expect(
      policy.intentForContinuationMarker('settings')?.location.toString(),
      AppRoutes.settings,
    );
    expect(policy.intentForContinuationMarker('/settings'), isNull);
    expect(policy.intentForContinuationMarker(occurrenceId), isNull);
  });

  test('all static protected destinations scrub query and fragment data', () {
    for (final String path in <String>[
      AppRoutes.today,
      AppRoutes.chores,
      AppRoutes.choreTrash,
      AppRoutes.calendar,
      AppRoutes.family,
      AppRoutes.inviteCreate,
      AppRoutes.householdMembers,
      AppRoutes.notifications,
      AppRoutes.settings,
      AppRoutes.householdSwitch,
      AppRoutes.subscription,
      AppRoutes.accountDeletion,
      AppRoutes.analyticsPrivacy,
      AppRoutes.dataExport,
      AppRoutes.diagnostics,
      AppRoutes.deviceCapabilities,
      AppRoutes.householdPrivacy,
      AppRoutes.legalSupport,
      AppRoutes.profilePreferences,
      AppRoutes.guidedChoreSetup,
      AppRoutes.routeNotFound,
    ]) {
      final AuthRouteIntent intent = policy.intentFor(
        Uri.parse('$path?token=discarded#callback'),
      );
      expect(intent.location.path, path, reason: path);
      expect(intent.location.hasQuery, isFalse, reason: path);
      expect(intent.location.hasFragment, isFalse, reason: path);
      expect(
        intent.continuationMarker,
        matches(RegExp(r'^[a-z0-9-]+$')),
        reason: path,
      );
    }
  });
}
