enum AuthEmailOtpDataFailureKind {
  invalidInput,
  invalidCode,
  rateLimited,
  temporarilyUnavailable,
  providerUnavailable,
  invalidPayload,
  unknown,
}

abstract interface class AuthEmailOtpDataSource {
  bool get isAvailable;

  Future<AuthEmailOtpRequestDataResult> requestCode({required String email});

  Future<AuthEmailOtpVerificationDataResult> verifyCode({
    required String email,
    required String code,
  });
}

sealed class AuthEmailOtpRequestDataResult {
  const AuthEmailOtpRequestDataResult();
}

final class AuthEmailOtpRequestDataAccepted
    extends AuthEmailOtpRequestDataResult {
  const AuthEmailOtpRequestDataAccepted();
}

final class AuthEmailOtpRequestDataFailed
    extends AuthEmailOtpRequestDataResult {
  const AuthEmailOtpRequestDataFailed(this.kind);

  final AuthEmailOtpDataFailureKind kind;
}

sealed class AuthEmailOtpVerificationDataResult {
  const AuthEmailOtpVerificationDataResult();
}

final class AuthEmailOtpVerificationDataCompleted
    extends AuthEmailOtpVerificationDataResult {
  const AuthEmailOtpVerificationDataCompleted({
    required this.sessionUserId,
    required this.responseUserId,
  });

  final String? sessionUserId;
  final String? responseUserId;
}

final class AuthEmailOtpVerificationDataFailed
    extends AuthEmailOtpVerificationDataResult {
  const AuthEmailOtpVerificationDataFailed(this.kind);

  final AuthEmailOtpDataFailureKind kind;
}
