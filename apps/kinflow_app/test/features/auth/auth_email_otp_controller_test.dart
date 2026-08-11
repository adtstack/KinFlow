import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/application/auth_email_otp_controller.dart';
import 'package:kinflow_app/features/auth/application/auth_email_otp_state.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_otp_code.dart';

import '../../support/fakes/fake_auth_dependencies.dart';

void main() {
  group('auth email OTP value objects', () {
    test('normalizes and redacts a valid email', () {
      final AuthEmailAddress email = AuthEmailAddress.tryCreate(
        '  Adult.User@Example.COM  ',
      )!;

      expect(email.value, 'adult.user@example.com');
      expect(email.maskedForDisplay, 'a•••@example.com');
      expect(email.toString(), isNot(contains('adult.user')));
    });

    for (final String invalid in <String>[
      '',
      'missing-at.example.com',
      '@example.com',
      'adult@',
      'two@@example.com',
      'adult user@example.com',
      '${List<String>.filled(250, 'a').join()}@example.com',
    ]) {
      test('rejects invalid email shape without throwing', () {
        expect(AuthEmailAddress.tryCreate(invalid), isNull);
      });
    }

    test('accepts exactly six ASCII digits and redacts them', () {
      final AuthEmailOtpCode code = AuthEmailOtpCode.tryCreate(' 012345 ')!;

      expect(code.value, '012345');
      expect(code.toString(), isNot(contains('012345')));
      for (final String invalid in <String>[
        '12345',
        '1234567',
        '123 456',
        'abcdef',
        '１２３４５６',
      ]) {
        expect(AuthEmailOtpCode.tryCreate(invalid), isNull);
      }
    });
  });

  group('AuthEmailOtpController request', () {
    test('rejects invalid email without provider I/O', () async {
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService();
      final AuthEmailOtpController controller = _controller(service);
      addTearDown(controller.dispose);

      await controller.requestCode('invalid');

      expect(service.requestCount, 0);
      expect(
        controller.state.failure?.kind,
        AuthEmailOtpFailureKind.invalidEmail,
      );
    });

    test('fails closed when the adapter is unavailable', () async {
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService(
        isAvailable: false,
      );
      final AuthEmailOtpController controller = _controller(service);
      addTearDown(controller.dispose);

      await controller.requestCode('adult@example.com');

      expect(service.requestCount, 0);
      expect(
        controller.state.failure?.kind,
        AuthEmailOtpFailureKind.providerUnavailable,
      );
    });

    test(
      'normalizes email and creates the exact local challenge window',
      () async {
        final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService();
        final DateTime now = DateTime.utc(2026, 8, 9, 10);
        final AuthEmailOtpController controller = AuthEmailOtpController(
          service: service,
          clock: () => now,
        );
        addTearDown(controller.dispose);

        await controller.requestCode(' Adult@Example.COM ');

        expect(service.requestedEmails.single.value, 'adult@example.com');
        final AuthEmailOtpCodeSent sent =
            controller.state as AuthEmailOtpCodeSent;
        expect(sent.challenge.requestedAt, now);
        expect(
          sent.challenge.resendAvailableAt,
          now.add(const Duration(seconds: 60)),
        );
        expect(sent.challenge.expiresAt, now.add(const Duration(minutes: 10)));
        expect(sent.challenge.generation, 1);
        expect(sent.challenge.toString(), isNot(contains('adult@example.com')));
      },
    );

    test('coalesces duplicate request taps into the same future', () async {
      final Completer<AuthEmailOtpRequestResult> pending =
          Completer<AuthEmailOtpRequestResult>();
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService(
        requestCallback: (_) => pending.future,
      );
      final AuthEmailOtpController controller = _controller(service);
      addTearDown(controller.dispose);

      final Future<void> first = controller.requestCode('adult@example.com');
      final Future<void> duplicate = controller.requestCode(
        'other@example.com',
      );

      expect(identical(first, duplicate), isTrue);
      expect(service.requestCount, 1);
      pending.complete(const AuthEmailOtpRequestAccepted());
      await first;
      expect(
        (controller.state as AuthEmailOtpCodeSent).challenge.email.value,
        'adult@example.com',
      );
    });

    test('maps service failure and thrown values to stable state', () async {
      final _FakeAuthEmailOtpService limited = _FakeAuthEmailOtpService(
        requestCallback: (_) => const AuthEmailOtpRequestFailed(
          AuthEmailOtpFailure(AuthEmailOtpFailureKind.rateLimited),
        ),
      );
      final AuthEmailOtpController limitedController = _controller(limited);
      addTearDown(limitedController.dispose);

      await limitedController.requestCode('adult@example.com');
      expect(
        limitedController.state.failure?.kind,
        AuthEmailOtpFailureKind.rateLimited,
      );

      final _FakeAuthEmailOtpService throwing = _FakeAuthEmailOtpService(
        requestCallback: (_) => throw StateError('raw adult@example.com'),
      );
      final AuthEmailOtpController throwingController = _controller(throwing);
      addTearDown(throwingController.dispose);

      await throwingController.requestCode('adult@example.com');
      expect(
        throwingController.state.failure?.kind,
        AuthEmailOtpFailureKind.internal,
      );
    });
  });

  group('AuthEmailOtpController resend', () {
    test('rejects resend before 60 seconds without provider I/O', () async {
      DateTime now = DateTime.utc(2026, 8, 9, 10);
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService();
      final AuthEmailOtpController controller = AuthEmailOtpController(
        service: service,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.requestCode('adult@example.com');

      now = now.add(const Duration(seconds: 59));
      await controller.resendCode();

      expect(service.requestCount, 1);
      expect(
        controller.state.failure?.kind,
        AuthEmailOtpFailureKind.rateLimited,
      );
    });

    test('replaces the challenge at the exact cooldown boundary', () async {
      DateTime now = DateTime.utc(2026, 8, 9, 10);
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService();
      final AuthEmailOtpController controller = AuthEmailOtpController(
        service: service,
        clock: () => now,
      );
      addTearDown(controller.dispose);
      await controller.requestCode('adult@example.com');

      now = now.add(const Duration(seconds: 60));
      await controller.resendCode();

      expect(service.requestCount, 2);
      final AuthEmailOtpCodeSent sent =
          controller.state as AuthEmailOtpCodeSent;
      expect(sent.challenge.generation, 2);
      expect(sent.challenge.requestedAt, now);
      expect(sent.failure, isNull);
    });

    test(
      'coalesces duplicate resend taps and preserves scope on failure',
      () async {
        DateTime now = DateTime.utc(2026, 8, 9, 10);
        final Completer<AuthEmailOtpRequestResult> resend =
            Completer<AuthEmailOtpRequestResult>();
        var requestIndex = 0;
        final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService(
          requestCallback: (_) {
            requestIndex += 1;
            return requestIndex == 1
                ? const AuthEmailOtpRequestAccepted()
                : resend.future;
          },
        );
        final AuthEmailOtpController controller = AuthEmailOtpController(
          service: service,
          clock: () => now,
        );
        addTearDown(controller.dispose);
        await controller.requestCode('adult@example.com');
        final int originalGeneration =
            (controller.state as AuthEmailOtpCodeSent).challenge.generation;
        now = now.add(const Duration(seconds: 60));

        final Future<void> first = controller.resendCode();
        final Future<void> duplicate = controller.resendCode();
        expect(identical(first, duplicate), isTrue);
        expect(service.requestCount, 2);
        resend.complete(
          const AuthEmailOtpRequestFailed(
            AuthEmailOtpFailure(AuthEmailOtpFailureKind.temporarilyUnavailable),
          ),
        );
        await first;

        final AuthEmailOtpCodeSent state =
            controller.state as AuthEmailOtpCodeSent;
        expect(state.challenge.generation, originalGeneration);
        expect(
          state.failure?.kind,
          AuthEmailOtpFailureKind.temporarilyUnavailable,
        );
      },
    );
  });

  group('AuthEmailOtpController verification', () {
    test('rejects malformed code without provider I/O', () async {
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService();
      final AuthEmailOtpController controller = _controller(service);
      addTearDown(controller.dispose);
      await controller.requestCode('adult@example.com');

      await controller.verifyCode('12345');

      expect(service.verifyCount, 0);
      expect(
        controller.state.failure?.kind,
        AuthEmailOtpFailureKind.invalidCode,
      );
    });

    test(
      'distinguishes local expiry at the exact ten-minute boundary',
      () async {
        DateTime now = DateTime.utc(2026, 8, 9, 10);
        final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService();
        final AuthEmailOtpController controller = AuthEmailOtpController(
          service: service,
          clock: () => now,
        );
        addTearDown(controller.dispose);
        await controller.requestCode('adult@example.com');

        now = now.add(const Duration(minutes: 10));
        await controller.verifyCode('123456');

        expect(service.verifyCount, 0);
        expect(controller.state.failure?.kind, AuthEmailOtpFailureKind.expired);
      },
    );

    test(
      'coalesces duplicate verification and emits a redacted session',
      () async {
        final Completer<AuthEmailOtpVerificationResult> pending =
            Completer<AuthEmailOtpVerificationResult>();
        final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService(
          verificationCallback: ({required email, required code}) =>
              pending.future,
        );
        final AuthEmailOtpController controller = _controller(service);
        addTearDown(controller.dispose);
        await controller.requestCode('adult@example.com');

        final Future<void> first = controller.verifyCode('123456');
        final Future<void> duplicate = controller.verifyCode('654321');

        expect(identical(first, duplicate), isTrue);
        expect(service.verifyCount, 1);
        pending.complete(AuthEmailOtpVerified(authSessionFixture()));
        await first;

        final AuthEmailOtpVerifiedState state =
            controller.state as AuthEmailOtpVerifiedState;
        expect(state.session.toString(), isNot(contains('11111111')));
        expect(service.verifiedCodes.single.value, '123456');
      },
    );

    test('preserves challenge after incorrect code and allows retry', () async {
      var attempt = 0;
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService(
        verificationCallback: ({required email, required code}) {
          attempt += 1;
          return attempt == 1
              ? const AuthEmailOtpVerificationFailed(
                  AuthEmailOtpFailure(AuthEmailOtpFailureKind.invalidCode),
                )
              : AuthEmailOtpVerified(authSessionFixture());
        },
      );
      final AuthEmailOtpController controller = _controller(service);
      addTearDown(controller.dispose);
      await controller.requestCode('adult@example.com');

      await controller.verifyCode('111111');
      final int generation =
          (controller.state as AuthEmailOtpCodeSent).challenge.generation;
      expect(
        controller.state.failure?.kind,
        AuthEmailOtpFailureKind.invalidCode,
      );

      await controller.verifyCode('222222');
      expect(controller.state, isA<AuthEmailOtpVerifiedState>());
      expect(
        (controller.state as AuthEmailOtpVerifiedState).challenge.generation,
        generation,
      );
    });

    test(
      'distinguishes reuse after local success without provider I/O',
      () async {
        final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService();
        final AuthEmailOtpController controller = _controller(service);
        addTearDown(controller.dispose);
        await controller.requestCode('adult@example.com');
        await controller.verifyCode('123456');

        await controller.verifyCode('123456');

        expect(service.verifyCount, 1);
        expect(
          controller.state.failure?.kind,
          AuthEmailOtpFailureKind.alreadyUsed,
        );
      },
    );

    test('maps thrown verification values to safe internal failure', () async {
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService(
        verificationCallback: ({required email, required code}) =>
            throw StateError('raw ${email.value} ${code.value}'),
      );
      final AuthEmailOtpController controller = _controller(service);
      addTearDown(controller.dispose);
      await controller.requestCode('adult@example.com');

      await controller.verifyCode('123456');

      expect(controller.state.failure?.kind, AuthEmailOtpFailureKind.internal);
    });
  });

  group('AuthEmailOtpController scope', () {
    test('change email clears only an idle unconsumed challenge', () async {
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService();
      final AuthEmailOtpController controller = _controller(service);
      addTearDown(controller.dispose);
      await controller.requestCode('adult@example.com');

      controller.changeEmail();

      expect(controller.state, isA<AuthEmailOtpEntry>());
    });

    test('ignores a late provider response after dispose', () async {
      final Completer<AuthEmailOtpRequestResult> pending =
          Completer<AuthEmailOtpRequestResult>();
      final _FakeAuthEmailOtpService service = _FakeAuthEmailOtpService(
        requestCallback: (_) => pending.future,
      );
      final AuthEmailOtpController controller = _controller(service);
      final List<AuthEmailOtpState> states = <AuthEmailOtpState>[];
      final StreamSubscription<AuthEmailOtpState> subscription = controller
          .states
          .listen(states.add);

      final Future<void> request = controller.requestCode('adult@example.com');
      await controller.dispose();
      pending.complete(const AuthEmailOtpRequestAccepted());
      await request;
      await subscription.cancel();

      expect(states, hasLength(1));
      expect(states.single, isA<AuthEmailOtpRequesting>());
    });
  });
}

AuthEmailOtpController _controller(_FakeAuthEmailOtpService service) {
  return AuthEmailOtpController(
    service: service,
    clock: () => DateTime.utc(2026, 8, 9, 10),
  );
}

typedef _RequestCallback =
    FutureOr<AuthEmailOtpRequestResult> Function(AuthEmailAddress email);
typedef _VerificationCallback =
    FutureOr<AuthEmailOtpVerificationResult> Function({
      required AuthEmailAddress email,
      required AuthEmailOtpCode code,
    });

final class _FakeAuthEmailOtpService implements AuthEmailOtpService {
  _FakeAuthEmailOtpService({
    this.isAvailable = true,
    this.requestCallback,
    this.verificationCallback,
  });

  @override
  final bool isAvailable;
  final _RequestCallback? requestCallback;
  final _VerificationCallback? verificationCallback;
  final List<AuthEmailAddress> requestedEmails = <AuthEmailAddress>[];
  final List<AuthEmailOtpCode> verifiedCodes = <AuthEmailOtpCode>[];
  var requestCount = 0;
  var verifyCount = 0;

  @override
  Future<AuthEmailOtpRequestResult> requestCode(AuthEmailAddress email) async {
    requestCount += 1;
    requestedEmails.add(email);
    return await requestCallback?.call(email) ??
        const AuthEmailOtpRequestAccepted();
  }

  @override
  Future<AuthEmailOtpVerificationResult> verifyCode({
    required AuthEmailAddress email,
    required AuthEmailOtpCode code,
  }) async {
    verifyCount += 1;
    verifiedCodes.add(code);
    return await verificationCallback?.call(email: email, code: code) ??
        AuthEmailOtpVerified(authSessionFixture());
  }
}
