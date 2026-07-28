enum AuthFailureKind {
  providerUnavailable,
  temporarilyUnavailable,
  sessionExpired,
  sessionRevoked,
  invalidSession,
  localPurgeFailed,
  internal,
}

final class AuthFailure {
  const AuthFailure(this.kind);

  final AuthFailureKind kind;

  String get code => switch (kind) {
    AuthFailureKind.providerUnavailable => 'PROVIDER_UNAVAILABLE',
    AuthFailureKind.temporarilyUnavailable => 'TEMPORARILY_UNAVAILABLE',
    AuthFailureKind.sessionExpired => 'SESSION_EXPIRED',
    AuthFailureKind.sessionRevoked => 'SESSION_EXPIRED',
    AuthFailureKind.invalidSession => 'AUTH_REQUIRED',
    AuthFailureKind.localPurgeFailed => 'auth.local_purge_failed',
    AuthFailureKind.internal => 'INTERNAL_ERROR',
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) || other is AuthFailure && other.kind == kind;
  }

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'AuthFailure(code: $code)';
}
