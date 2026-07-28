import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';

abstract interface class AuthSessionRepository {
  Stream<AuthSessionEvent> get sessionEvents;

  Future<AuthSessionResult> restoreSession();

  Future<AuthSessionResult> refreshSession();

  Future<AuthSignOutResult> signOut();
}

sealed class AuthSessionResult {
  const AuthSessionResult();
}

final class AuthSessionAvailable extends AuthSessionResult {
  const AuthSessionAvailable(this.session);

  final AuthSession session;
}

final class AuthSessionAbsent extends AuthSessionResult {
  const AuthSessionAbsent();
}

final class AuthSessionFailed extends AuthSessionResult {
  const AuthSessionFailed(this.failure);

  final AuthFailure failure;
}

sealed class AuthSignOutResult {
  const AuthSignOutResult();
}

final class AuthSignOutCompleted extends AuthSignOutResult {
  const AuthSignOutCompleted();
}

final class AuthSignOutFailed extends AuthSignOutResult {
  const AuthSignOutFailed(this.failure);

  final AuthFailure failure;
}

enum AuthSessionTerminationReason { signedOut, expired, revoked }

sealed class AuthSessionEvent {
  const AuthSessionEvent();
}

final class AuthSessionEstablished extends AuthSessionEvent {
  const AuthSessionEstablished(this.session);

  final AuthSession session;
}

final class AuthSessionTerminated extends AuthSessionEvent {
  const AuthSessionTerminated(this.reason);

  final AuthSessionTerminationReason reason;
}

final class AuthSessionEventFailed extends AuthSessionEvent {
  const AuthSessionEventFailed(this.failure);

  final AuthFailure failure;
}
