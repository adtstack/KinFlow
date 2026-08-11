import 'package:kinflow_app/features/auth/data/datasources/auth_email_otp_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef SupabaseEmailOtpRequest =
    Future<void> Function({
      required String email,
      required bool shouldCreateUser,
    });

typedef SupabaseEmailOtpVerify =
    Future<SupabaseEmailOtpVerificationRecord> Function({
      required String email,
      required String code,
    });

final class SupabaseEmailOtpVerificationRecord {
  const SupabaseEmailOtpVerificationRecord({
    required this.sessionUserId,
    required this.responseUserId,
  });

  final String? sessionUserId;
  final String? responseUserId;
}

final class SupabaseAuthEmailOtpDataSource implements AuthEmailOtpDataSource {
  factory SupabaseAuthEmailOtpDataSource(SupabaseClient client) {
    return SupabaseAuthEmailOtpDataSource.withOperations(
      request: ({required String email, required bool shouldCreateUser}) {
        return client.auth.signInWithOtp(
          email: email,
          shouldCreateUser: shouldCreateUser,
        );
      },
      verify: ({required String email, required String code}) async {
        final AuthResponse response = await client.auth.verifyOTP(
          email: email,
          token: code,
          type: OtpType.email,
        );
        return SupabaseEmailOtpVerificationRecord(
          sessionUserId: response.session?.user.id,
          responseUserId: response.user?.id,
        );
      },
    );
  }

  const SupabaseAuthEmailOtpDataSource.withOperations({
    required SupabaseEmailOtpRequest request,
    required SupabaseEmailOtpVerify verify,
  }) : this._(request, verify);

  const SupabaseAuthEmailOtpDataSource._(this._request, this._verify);

  final SupabaseEmailOtpRequest _request;
  final SupabaseEmailOtpVerify _verify;

  @override
  bool get isAvailable => true;

  @override
  Future<AuthEmailOtpRequestDataResult> requestCode({
    required String email,
  }) async {
    try {
      await _request(email: email, shouldCreateUser: true);
      return const AuthEmailOtpRequestDataAccepted();
    } on AuthException catch (error) {
      if (_isIdentityConflict(error.code)) {
        return const AuthEmailOtpRequestDataAccepted();
      }
      return AuthEmailOtpRequestDataFailed(_requestFailure(error));
    } on Object {
      return const AuthEmailOtpRequestDataFailed(
        AuthEmailOtpDataFailureKind.unknown,
      );
    }
  }

  @override
  Future<AuthEmailOtpVerificationDataResult> verifyCode({
    required String email,
    required String code,
  }) async {
    try {
      final SupabaseEmailOtpVerificationRecord record = await _verify(
        email: email,
        code: code,
      );
      return AuthEmailOtpVerificationDataCompleted(
        sessionUserId: record.sessionUserId,
        responseUserId: record.responseUserId,
      );
    } on AuthException catch (error) {
      return AuthEmailOtpVerificationDataFailed(_verificationFailure(error));
    } on Object {
      return const AuthEmailOtpVerificationDataFailed(
        AuthEmailOtpDataFailureKind.unknown,
      );
    }
  }

  AuthEmailOtpDataFailureKind _requestFailure(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return AuthEmailOtpDataFailureKind.temporarilyUnavailable;
    }
    return switch (error.code) {
      'over_email_send_rate_limit' ||
      'over_request_rate_limit' => AuthEmailOtpDataFailureKind.rateLimited,
      'email_provider_disabled' ||
      'otp_disabled' ||
      'signup_disabled' ||
      'provider_disabled' => AuthEmailOtpDataFailureKind.providerUnavailable,
      'validation_failed' => AuthEmailOtpDataFailureKind.invalidInput,
      _ => AuthEmailOtpDataFailureKind.unknown,
    };
  }

  AuthEmailOtpDataFailureKind _verificationFailure(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return AuthEmailOtpDataFailureKind.temporarilyUnavailable;
    }
    return switch (error.code) {
      'otp_expired' ||
      'validation_failed' => AuthEmailOtpDataFailureKind.invalidCode,
      'over_request_rate_limit' => AuthEmailOtpDataFailureKind.rateLimited,
      'email_provider_disabled' ||
      'otp_disabled' ||
      'signup_disabled' ||
      'provider_disabled' => AuthEmailOtpDataFailureKind.providerUnavailable,
      _ => AuthEmailOtpDataFailureKind.unknown,
    };
  }

  bool _isIdentityConflict(String? code) {
    return code == 'email_exists' ||
        code == 'identity_already_exists' ||
        code == 'user_already_exists';
  }
}
