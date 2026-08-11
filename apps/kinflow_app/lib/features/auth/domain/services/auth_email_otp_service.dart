import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_otp_code.dart';

abstract interface class AuthEmailOtpService {
  bool get isAvailable;

  Future<AuthEmailOtpRequestResult> requestCode(AuthEmailAddress email);

  Future<AuthEmailOtpVerificationResult> verifyCode({
    required AuthEmailAddress email,
    required AuthEmailOtpCode code,
  });
}

sealed class AuthEmailOtpRequestResult {
  const AuthEmailOtpRequestResult();
}

final class AuthEmailOtpRequestAccepted extends AuthEmailOtpRequestResult {
  const AuthEmailOtpRequestAccepted();
}

final class AuthEmailOtpRequestFailed extends AuthEmailOtpRequestResult {
  const AuthEmailOtpRequestFailed(this.failure);

  final AuthEmailOtpFailure failure;
}

sealed class AuthEmailOtpVerificationResult {
  const AuthEmailOtpVerificationResult();
}

final class AuthEmailOtpVerified extends AuthEmailOtpVerificationResult {
  const AuthEmailOtpVerified(this.session);

  final AuthSession session;
}

final class AuthEmailOtpVerificationFailed
    extends AuthEmailOtpVerificationResult {
  const AuthEmailOtpVerificationFailed(this.failure);

  final AuthEmailOtpFailure failure;
}
