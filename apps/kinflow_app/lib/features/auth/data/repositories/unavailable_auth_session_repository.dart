import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';

final class UnavailableAuthSessionRepository implements AuthSessionRepository {
  const UnavailableAuthSessionRepository();

  @override
  Stream<AuthSessionEvent> get sessionEvents =>
      const Stream<AuthSessionEvent>.empty();

  @override
  Future<AuthSessionResult> restoreSession() async {
    return const AuthSessionAbsent();
  }

  @override
  Future<AuthSessionResult> refreshSession() async {
    return const AuthSessionFailed(
      AuthFailure(AuthFailureKind.providerUnavailable),
    );
  }

  @override
  Future<AuthSignOutResult> signOut() async {
    return const AuthSignOutCompleted();
  }
}
