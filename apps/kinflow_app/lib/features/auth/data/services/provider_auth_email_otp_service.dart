import 'package:kinflow_app/features/auth/data/datasources/auth_email_otp_data_source.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_otp_code.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';

final class ProviderAuthEmailOtpService implements AuthEmailOtpService {
  const ProviderAuthEmailOtpService(this._dataSource);

  final AuthEmailOtpDataSource _dataSource;

  @override
  bool get isAvailable => _dataSource.isAvailable;

  @override
  Future<AuthEmailOtpRequestResult> requestCode(AuthEmailAddress email) async {
    final AuthEmailOtpRequestDataResult result = await _dataSource.requestCode(
      email: email.value,
    );
    return switch (result) {
      AuthEmailOtpRequestDataAccepted() => const AuthEmailOtpRequestAccepted(),
      AuthEmailOtpRequestDataFailed(:final kind) => AuthEmailOtpRequestFailed(
        AuthEmailOtpFailure(_failureKind(kind)),
      ),
    };
  }

  @override
  Future<AuthEmailOtpVerificationResult> verifyCode({
    required AuthEmailAddress email,
    required AuthEmailOtpCode code,
  }) async {
    final AuthEmailOtpVerificationDataResult result = await _dataSource
        .verifyCode(email: email.value, code: code.value);
    return switch (result) {
      AuthEmailOtpVerificationDataCompleted(
        :final sessionUserId,
        :final responseUserId,
      ) =>
        _verified(sessionUserId, responseUserId),
      AuthEmailOtpVerificationDataFailed(:final kind) =>
        AuthEmailOtpVerificationFailed(AuthEmailOtpFailure(_failureKind(kind))),
    };
  }

  AuthEmailOtpVerificationResult _verified(
    String? sessionUserId,
    String? responseUserId,
  ) {
    final AuthUserId? sessionId = sessionUserId == null
        ? null
        : AuthUserId.tryParse(sessionUserId);
    final AuthUserId? responseId = responseUserId == null
        ? null
        : AuthUserId.tryParse(responseUserId);
    if (sessionId == null || responseId == null || sessionId != responseId) {
      return const AuthEmailOtpVerificationFailed(
        AuthEmailOtpFailure(AuthEmailOtpFailureKind.invalidPayload),
      );
    }
    return AuthEmailOtpVerified(AuthSession(userId: sessionId));
  }

  AuthEmailOtpFailureKind _failureKind(AuthEmailOtpDataFailureKind kind) {
    return switch (kind) {
      AuthEmailOtpDataFailureKind.invalidInput =>
        AuthEmailOtpFailureKind.invalidEmail,
      AuthEmailOtpDataFailureKind.invalidCode =>
        AuthEmailOtpFailureKind.invalidCode,
      AuthEmailOtpDataFailureKind.rateLimited =>
        AuthEmailOtpFailureKind.rateLimited,
      AuthEmailOtpDataFailureKind.temporarilyUnavailable =>
        AuthEmailOtpFailureKind.temporarilyUnavailable,
      AuthEmailOtpDataFailureKind.providerUnavailable =>
        AuthEmailOtpFailureKind.providerUnavailable,
      AuthEmailOtpDataFailureKind.invalidPayload =>
        AuthEmailOtpFailureKind.invalidPayload,
      AuthEmailOtpDataFailureKind.unknown => AuthEmailOtpFailureKind.internal,
    };
  }
}
