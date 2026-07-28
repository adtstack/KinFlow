import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';

sealed class AuthLifecycleState {
  const AuthLifecycleState();

  AuthSession? get session => switch (this) {
    AuthResolvingHousehold(:final session) => session,
    AuthHouseholdResolutionFailed(:final session) => session,
    AuthAuthenticatedNoHousehold(:final session) => session,
    AuthAuthenticatedActiveHousehold(:final session) => session,
    AuthRefreshing(:final session) => session,
    AuthDeleting(:final session) => session,
    _ => null,
  };

  ActiveHousehold? get activeHousehold => switch (this) {
    AuthAuthenticatedActiveHousehold(:final household) => household,
    AuthRefreshing(:final activeHousehold) => activeHousehold,
    _ => null,
  };

  HouseholdFailure? get householdFailure => switch (this) {
    AuthHouseholdResolutionFailed(:final householdResolutionFailure) =>
      householdResolutionFailure,
    _ => null,
  };

  AuthFailure? get failure => switch (this) {
    AuthUnauthenticated(:final failure) => failure,
    AuthLocked(:final failure) => failure,
    _ => null,
  };

  bool get permitsProtectedRoutes {
    return this is AuthAuthenticatedNoHousehold ||
        this is AuthAuthenticatedActiveHousehold ||
        this is AuthRefreshing;
  }
}

final class AuthBootstrapping extends AuthLifecycleState {
  const AuthBootstrapping();
}

final class AuthUnauthenticated extends AuthLifecycleState {
  const AuthUnauthenticated({this.failure});

  @override
  final AuthFailure? failure;
}

final class AuthAuthenticating extends AuthLifecycleState {
  const AuthAuthenticating();
}

final class AuthResolvingHousehold extends AuthLifecycleState {
  const AuthResolvingHousehold(this.session);

  @override
  final AuthSession session;
}

final class AuthHouseholdResolutionFailed extends AuthLifecycleState {
  const AuthHouseholdResolutionFailed(
    this.session,
    this.householdResolutionFailure,
  );

  @override
  final AuthSession session;

  final HouseholdFailure householdResolutionFailure;
}

final class AuthAuthenticatedNoHousehold extends AuthLifecycleState {
  const AuthAuthenticatedNoHousehold(this.session);

  @override
  final AuthSession session;
}

final class AuthAuthenticatedActiveHousehold extends AuthLifecycleState {
  const AuthAuthenticatedActiveHousehold(this.session, this.household);

  @override
  final AuthSession session;

  final ActiveHousehold household;
}

final class AuthRefreshing extends AuthLifecycleState {
  const AuthRefreshing(this.session, {this.activeHousehold});

  @override
  final AuthSession session;

  @override
  final ActiveHousehold? activeHousehold;
}

final class AuthLocked extends AuthLifecycleState {
  const AuthLocked({this.failure});

  @override
  final AuthFailure? failure;
}

final class AuthDeleting extends AuthLifecycleState {
  const AuthDeleting(this.session);

  @override
  final AuthSession session;
}
