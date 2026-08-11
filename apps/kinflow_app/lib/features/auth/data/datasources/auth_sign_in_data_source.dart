enum AuthSignInDataFailureKind {
  providerUnavailable,
  temporarilyUnavailable,
  identityConflict,
  invalidPayload,
  unknown,
}

abstract interface class AuthSignInDataSource {
  bool get isAvailable;

  Future<AuthSignInDataResult> requestGoogleSignIn();
}

sealed class AuthSignInDataResult {
  const AuthSignInDataResult();
}

final class AuthSignInDataCompleted extends AuthSignInDataResult {
  const AuthSignInDataCompleted();
}

final class AuthSignInDataCancelled extends AuthSignInDataResult {
  const AuthSignInDataCancelled();
}

final class AuthSignInDataFailed extends AuthSignInDataResult {
  const AuthSignInDataFailed(this.kind);

  final AuthSignInDataFailureKind kind;
}
