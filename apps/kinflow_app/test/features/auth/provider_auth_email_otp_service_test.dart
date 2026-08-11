import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/data/datasources/auth_email_otp_data_source.dart';
import 'package:kinflow_app/features/auth/data/services/provider_auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_otp_code.dart';

void main() {
  final AuthEmailAddress email = AuthEmailAddress.tryCreate(
    'adult@example.com',
  )!;
  final AuthEmailOtpCode code = AuthEmailOtpCode.tryCreate('123456')!;

  test('maps request acceptance and normalized value', () async {
    final _FakeAuthEmailOtpDataSource dataSource =
        _FakeAuthEmailOtpDataSource();
    final ProviderAuthEmailOtpService service = ProviderAuthEmailOtpService(
      dataSource,
    );

    expect(
      await service.requestCode(email),
      isA<AuthEmailOtpRequestAccepted>(),
    );
    expect(dataSource.requestedEmails, <String>['adult@example.com']);
  });

  for (final AuthEmailOtpDataFailureKind dataKind
      in AuthEmailOtpDataFailureKind.values) {
    test('maps request $dataKind to a stable domain failure', () async {
      final ProviderAuthEmailOtpService service = ProviderAuthEmailOtpService(
        _FakeAuthEmailOtpDataSource(
          requestResult: AuthEmailOtpRequestDataFailed(dataKind),
        ),
      );

      final AuthEmailOtpRequestFailed result =
          await service.requestCode(email) as AuthEmailOtpRequestFailed;

      expect(result.failure.kind, _expectedFailure(dataKind));
      expect(result.failure.toString(), isNot(contains('adult@example.com')));
    });
  }

  test('accepts only matching valid session and response UUIDs', () async {
    final ProviderAuthEmailOtpService service = ProviderAuthEmailOtpService(
      _FakeAuthEmailOtpDataSource(
        verificationResult: const AuthEmailOtpVerificationDataCompleted(
          sessionUserId: '11111111-1111-4111-8111-111111111111',
          responseUserId: '11111111-1111-4111-8111-111111111111',
        ),
      ),
    );

    final AuthEmailOtpVerificationResult result = await service.verifyCode(
      email: email,
      code: code,
    );

    expect(result, isA<AuthEmailOtpVerified>());
    expect(
      (result as AuthEmailOtpVerified).session.toString(),
      isNot(contains('11111111')),
    );
  });

  for (final ({String? sessionId, String? responseId}) scenario
      in <({String? sessionId, String? responseId})>[
        (sessionId: null, responseId: '11111111-1111-4111-8111-111111111111'),
        (sessionId: '11111111-1111-4111-8111-111111111111', responseId: null),
        (sessionId: 'not-a-uuid', responseId: 'not-a-uuid'),
        (
          sessionId: '11111111-1111-4111-8111-111111111111',
          responseId: '22222222-2222-4222-8222-222222222222',
        ),
      ]) {
    test('rejects invalid verification identity pair $scenario', () async {
      final ProviderAuthEmailOtpService service = ProviderAuthEmailOtpService(
        _FakeAuthEmailOtpDataSource(
          verificationResult: AuthEmailOtpVerificationDataCompleted(
            sessionUserId: scenario.sessionId,
            responseUserId: scenario.responseId,
          ),
        ),
      );

      final AuthEmailOtpVerificationFailed result =
          await service.verifyCode(email: email, code: code)
              as AuthEmailOtpVerificationFailed;

      expect(result.failure.kind, AuthEmailOtpFailureKind.invalidPayload);
    });
  }

  for (final AuthEmailOtpDataFailureKind dataKind
      in AuthEmailOtpDataFailureKind.values) {
    test('maps verification $dataKind to a stable domain failure', () async {
      final ProviderAuthEmailOtpService service = ProviderAuthEmailOtpService(
        _FakeAuthEmailOtpDataSource(
          verificationResult: AuthEmailOtpVerificationDataFailed(dataKind),
        ),
      );

      final AuthEmailOtpVerificationFailed result =
          await service.verifyCode(email: email, code: code)
              as AuthEmailOtpVerificationFailed;

      expect(result.failure.kind, _expectedFailure(dataKind));
    });
  }
}

AuthEmailOtpFailureKind _expectedFailure(AuthEmailOtpDataFailureKind kind) {
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

final class _FakeAuthEmailOtpDataSource implements AuthEmailOtpDataSource {
  _FakeAuthEmailOtpDataSource({
    this.requestResult = const AuthEmailOtpRequestDataAccepted(),
    this.verificationResult = const AuthEmailOtpVerificationDataCompleted(
      sessionUserId: '11111111-1111-4111-8111-111111111111',
      responseUserId: '11111111-1111-4111-8111-111111111111',
    ),
  });

  final AuthEmailOtpRequestDataResult requestResult;
  final AuthEmailOtpVerificationDataResult verificationResult;
  final List<String> requestedEmails = <String>[];

  @override
  bool get isAvailable => true;

  @override
  Future<AuthEmailOtpRequestDataResult> requestCode({
    required String email,
  }) async {
    requestedEmails.add(email);
    return requestResult;
  }

  @override
  Future<AuthEmailOtpVerificationDataResult> verifyCode({
    required String email,
    required String code,
  }) async {
    return verificationResult;
  }
}
