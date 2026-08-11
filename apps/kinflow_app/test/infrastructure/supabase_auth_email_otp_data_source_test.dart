import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/data/datasources/auth_email_otp_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_auth_email_otp_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseAuthEmailOtpDataSource request', () {
    test(
      'uses sign-up-capable email OTP without exposing provider details',
      () async {
        String? requestedEmail;
        bool? recordedShouldCreateUser;
        final SupabaseAuthEmailOtpDataSource dataSource =
            SupabaseAuthEmailOtpDataSource.withOperations(
              request:
                  ({
                    required String email,
                    required bool shouldCreateUser,
                  }) async {
                    requestedEmail = email;
                    recordedShouldCreateUser = shouldCreateUser;
                  },
              verify: _unusedVerify,
            );

        final AuthEmailOtpRequestDataResult result = await dataSource
            .requestCode(email: 'adult@example.com');

        expect(result, isA<AuthEmailOtpRequestDataAccepted>());
        expect(requestedEmail, 'adult@example.com');
        expect(recordedShouldCreateUser, isTrue);
      },
    );

    for (final String code in <String>[
      'email_exists',
      'identity_already_exists',
      'user_already_exists',
    ]) {
      test('collapses exact $code to generic accepted', () async {
        final SupabaseAuthEmailOtpDataSource dataSource = _requestThrowing(
          AuthException('raw email detail', code: code),
        );

        expect(
          await dataSource.requestCode(email: 'adult@example.com'),
          isA<AuthEmailOtpRequestDataAccepted>(),
        );
      });
    }

    for (final String code in <String>[
      'over_email_send_rate_limit',
      'over_request_rate_limit',
    ]) {
      test('maps exact $code to rate limited', () async {
        final AuthEmailOtpRequestDataResult result = await _requestThrowing(
          AuthException('raw', code: code),
        ).requestCode(email: 'adult@example.com');

        expect(
          (result as AuthEmailOtpRequestDataFailed).kind,
          AuthEmailOtpDataFailureKind.rateLimited,
        );
      });
    }

    for (final String code in <String>[
      'email_provider_disabled',
      'otp_disabled',
      'signup_disabled',
      'provider_disabled',
    ]) {
      test('maps exact $code to provider unavailable', () async {
        final AuthEmailOtpRequestDataResult result = await _requestThrowing(
          AuthException('raw', code: code),
        ).requestCode(email: 'adult@example.com');

        expect(
          (result as AuthEmailOtpRequestDataFailed).kind,
          AuthEmailOtpDataFailureKind.providerUnavailable,
        );
      });
    }

    test(
      'maps retryable transport failures without message inspection',
      () async {
        final AuthEmailOtpRequestDataResult result = await _requestThrowing(
          AuthRetryableFetchException(message: 'adult@example.com'),
        ).requestCode(email: 'adult@example.com');

        expect(
          (result as AuthEmailOtpRequestDataFailed).kind,
          AuthEmailOtpDataFailureKind.temporarilyUnavailable,
        );
      },
    );

    test('does not infer conflict or rate limit from raw messages', () async {
      final AuthEmailOtpRequestDataResult result = await _requestThrowing(
        const AuthException(
          'email_exists over_email_send_rate_limit adult@example.com',
          code: 'unexpected_failure',
        ),
      ).requestCode(email: 'adult@example.com');

      expect(
        (result as AuthEmailOtpRequestDataFailed).kind,
        AuthEmailOtpDataFailureKind.unknown,
      );
    });
  });

  group('SupabaseAuthEmailOtpDataSource verification', () {
    test('uses email OTP and preserves both response identities', () async {
      String? verifiedEmail;
      String? verifiedCode;
      final SupabaseAuthEmailOtpDataSource dataSource =
          SupabaseAuthEmailOtpDataSource.withOperations(
            request: _unusedRequest,
            verify: ({required String email, required String code}) async {
              verifiedEmail = email;
              verifiedCode = code;
              return const SupabaseEmailOtpVerificationRecord(
                sessionUserId: '11111111-1111-4111-8111-111111111111',
                responseUserId: '11111111-1111-4111-8111-111111111111',
              );
            },
          );

      final AuthEmailOtpVerificationDataResult result = await dataSource
          .verifyCode(email: 'adult@example.com', code: '123456');

      expect(result, isA<AuthEmailOtpVerificationDataCompleted>());
      expect(verifiedEmail, 'adult@example.com');
      expect(verifiedCode, '123456');
      final AuthEmailOtpVerificationDataCompleted completed =
          result as AuthEmailOtpVerificationDataCompleted;
      expect(completed.sessionUserId, completed.responseUserId);
    });

    test('maps otp_expired to invalid code inside the local window', () async {
      final AuthEmailOtpVerificationDataResult result = await _verifyThrowing(
        const AuthException('invalid or expired raw', code: 'otp_expired'),
      ).verifyCode(email: 'adult@example.com', code: '123456');

      expect(
        (result as AuthEmailOtpVerificationDataFailed).kind,
        AuthEmailOtpDataFailureKind.invalidCode,
      );
    });

    test('maps exact verification rate limit', () async {
      final AuthEmailOtpVerificationDataResult result = await _verifyThrowing(
        const AuthException('raw', code: 'over_request_rate_limit'),
      ).verifyCode(email: 'adult@example.com', code: '123456');

      expect(
        (result as AuthEmailOtpVerificationDataFailed).kind,
        AuthEmailOtpDataFailureKind.rateLimited,
      );
    });

    test('maps retryable verification transport failure', () async {
      final AuthEmailOtpVerificationDataResult result = await _verifyThrowing(
        AuthRetryableFetchException(message: 'raw-code-123456'),
      ).verifyCode(email: 'adult@example.com', code: '123456');

      expect(
        (result as AuthEmailOtpVerificationDataFailed).kind,
        AuthEmailOtpDataFailureKind.temporarilyUnavailable,
      );
    });

    test('maps arbitrary thrown values to unknown', () async {
      final AuthEmailOtpVerificationDataResult result = await _verifyThrowing(
        StateError('raw-code-123456'),
      ).verifyCode(email: 'adult@example.com', code: '123456');

      expect(
        (result as AuthEmailOtpVerificationDataFailed).kind,
        AuthEmailOtpDataFailureKind.unknown,
      );
    });
  });
}

SupabaseAuthEmailOtpDataSource _requestThrowing(Object error) {
  return SupabaseAuthEmailOtpDataSource.withOperations(
    request: ({required String email, required bool shouldCreateUser}) async {
      _throwSupported(error);
    },
    verify: _unusedVerify,
  );
}

SupabaseAuthEmailOtpDataSource _verifyThrowing(Object error) {
  return SupabaseAuthEmailOtpDataSource.withOperations(
    request: _unusedRequest,
    verify: ({required String email, required String code}) async {
      _throwSupported(error);
    },
  );
}

Never _throwSupported(Object error) {
  if (error case final Exception exception) throw exception;
  if (error case final Error dartError) throw dartError;
  throw StateError('Test requires an Exception or Error.');
}

Future<void> _unusedRequest({
  required String email,
  required bool shouldCreateUser,
}) async {}

Future<SupabaseEmailOtpVerificationRecord> _unusedVerify({
  required String email,
  required String code,
}) async {
  throw StateError('Unused verification operation.');
}
