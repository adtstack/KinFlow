import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';

sealed class AuthLifecycleState {
  const AuthLifecycleState();

  AuthSession? get session => switch (this) {
    AuthAuthenticatedNoHousehold(:final session) => session,
    AuthAuthenticatedActiveHousehold(:final session) => session,
    AuthRefreshing(:final session) => session,
    AuthDeleting(:final session) => session,
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

final class AuthAuthenticatedNoHousehold extends AuthLifecycleState {
  const AuthAuthenticatedNoHousehold(this.session);

  @override
  final AuthSession session;
}

final class AuthAuthenticatedActiveHousehold extends AuthLifecycleState {
  const AuthAuthenticatedActiveHousehold(this.session);

  @override
  final AuthSession session;
}

final class AuthRefreshing extends AuthLifecycleState {
  const AuthRefreshing(this.session);

  @override
  final AuthSession session;
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
