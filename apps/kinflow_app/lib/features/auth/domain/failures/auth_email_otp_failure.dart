enum AuthEmailOtpFailureKind {
  invalidEmail,
  invalidCode,
  expired,
  alreadyUsed,
  rateLimited,
  temporarilyUnavailable,
  providerUnavailable,
  invalidPayload,
  internal,
}

final class AuthEmailOtpFailure {
  const AuthEmailOtpFailure(this.kind);

  final AuthEmailOtpFailureKind kind;

  String get code => switch (kind) {
    AuthEmailOtpFailureKind.invalidEmail => 'INVALID_EMAIL',
    AuthEmailOtpFailureKind.invalidCode => 'INVALID_OTP_CODE',
    AuthEmailOtpFailureKind.expired => 'OTP_EXPIRED',
    AuthEmailOtpFailureKind.alreadyUsed => 'OTP_ALREADY_USED',
    AuthEmailOtpFailureKind.rateLimited => 'OTP_RATE_LIMITED',
    AuthEmailOtpFailureKind.temporarilyUnavailable =>
      'OTP_TEMPORARILY_UNAVAILABLE',
    AuthEmailOtpFailureKind.providerUnavailable => 'OTP_PROVIDER_UNAVAILABLE',
    AuthEmailOtpFailureKind.invalidPayload => 'OTP_INVALID_PAYLOAD',
    AuthEmailOtpFailureKind.internal => 'OTP_INTERNAL',
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthEmailOtpFailure && other.kind == kind;
  }

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'AuthEmailOtpFailure($code)';
}
