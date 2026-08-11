import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_otp_code.dart';

final class UnavailableAuthEmailOtpService implements AuthEmailOtpService {
  const UnavailableAuthEmailOtpService();

  @override
  bool get isAvailable => false;

  @override
  Future<AuthEmailOtpRequestResult> requestCode(AuthEmailAddress email) async {
    return const AuthEmailOtpRequestFailed(
      AuthEmailOtpFailure(AuthEmailOtpFailureKind.providerUnavailable),
    );
  }

  @override
  Future<AuthEmailOtpVerificationResult> verifyCode({
    required AuthEmailAddress email,
    required AuthEmailOtpCode code,
  }) async {
    return const AuthEmailOtpVerificationFailed(
      AuthEmailOtpFailure(AuthEmailOtpFailureKind.providerUnavailable),
    );
  }
}
