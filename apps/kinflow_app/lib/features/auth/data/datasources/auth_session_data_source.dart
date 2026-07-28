enum AuthSessionDataFailureKind {
  temporarilyUnavailable,
  sessionExpired,
  sessionRevoked,
  invalidPayload,
  unknown,
}

final class AuthSessionRecord {
  const AuthSessionRecord({required this.userId});

  final String userId;
}

abstract interface class AuthSessionDataSource {
  Stream<AuthSessionDataEvent> get sessionEvents;

  Future<AuthSessionDataResult> restoreSession();

  Future<AuthSessionDataResult> refreshSession();

  Future<AuthSignOutDataResult> signOut();
}

sealed class AuthSessionDataResult {
  const AuthSessionDataResult();
}

final class AuthSessionDataAvailable extends AuthSessionDataResult {
  const AuthSessionDataAvailable(this.record);

  final AuthSessionRecord record;
}

final class AuthSessionDataAbsent extends AuthSessionDataResult {
  const AuthSessionDataAbsent();
}

final class AuthSessionDataFailed extends AuthSessionDataResult {
  const AuthSessionDataFailed(this.kind);

  final AuthSessionDataFailureKind kind;
}

sealed class AuthSignOutDataResult {
  const AuthSignOutDataResult();
}

final class AuthSignOutDataCompleted extends AuthSignOutDataResult {
  const AuthSignOutDataCompleted();
}

final class AuthSignOutDataFailed extends AuthSignOutDataResult {
  const AuthSignOutDataFailed(this.kind);

  final AuthSessionDataFailureKind kind;
}

enum AuthSessionDataTerminationReason { signedOut, expired, revoked }

sealed class AuthSessionDataEvent {
  const AuthSessionDataEvent();
}

final class AuthSessionDataEstablished extends AuthSessionDataEvent {
  const AuthSessionDataEstablished(this.record);

  final AuthSessionRecord record;
}

final class AuthSessionDataTerminated extends AuthSessionDataEvent {
  const AuthSessionDataTerminated(this.reason);

  final AuthSessionDataTerminationReason reason;
}

final class AuthSessionDataEventFailed extends AuthSessionDataEvent {
  const AuthSessionDataEventFailed(this.kind);

  final AuthSessionDataFailureKind kind;
}
