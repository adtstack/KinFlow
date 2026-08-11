import 'dart:async';

import 'package:kinflow_app/features/auth/application/auth_email_otp_state.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_email_otp_challenge.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_otp_code.dart';

typedef AuthEmailOtpClock = DateTime Function();

final class AuthEmailOtpController {
  factory AuthEmailOtpController({
    required AuthEmailOtpService service,
    AuthEmailOtpClock clock = DateTime.now,
  }) {
    return AuthEmailOtpController._(service, clock);
  }

  AuthEmailOtpController._(this._service, this._clock);

  final AuthEmailOtpService _service;
  final AuthEmailOtpClock _clock;
  final StreamController<AuthEmailOtpState> _states =
      StreamController<AuthEmailOtpState>.broadcast(sync: true);

  AuthEmailOtpState _state = const AuthEmailOtpEntry();
  Future<void>? _pending;
  var _generation = 0;
  var _scopeVersion = 0;
  var _disposed = false;

  AuthEmailOtpState get state => _state;

  Stream<AuthEmailOtpState> get states => _states.stream;

  bool get isAvailable => _service.isAvailable;

  Future<void> requestCode(String rawEmail) {
    if (_disposed) return Future<void>.value();
    final Future<void>? pending = _pending;
    if (pending != null) return pending;
    if (_state is! AuthEmailOtpEntry) return Future<void>.value();

    final AuthEmailAddress? email = AuthEmailAddress.tryCreate(rawEmail);
    if (email == null) {
      _emit(
        const AuthEmailOtpEntry(
          failure: AuthEmailOtpFailure(AuthEmailOtpFailureKind.invalidEmail),
        ),
      );
      return Future<void>.value();
    }
    if (!_service.isAvailable) {
      _emit(
        const AuthEmailOtpEntry(
          failure: AuthEmailOtpFailure(
            AuthEmailOtpFailureKind.providerUnavailable,
          ),
        ),
      );
      return Future<void>.value();
    }

    final int scopeVersion = ++_scopeVersion;
    _emit(AuthEmailOtpRequesting(email));
    return _track(
      _request(email: email, scopeVersion: scopeVersion, replacing: null),
    );
  }

  Future<void> resendCode() {
    if (_disposed) return Future<void>.value();
    final Future<void>? pending = _pending;
    if (pending != null) return pending;
    final AuthEmailOtpCodeSent? current = _state is AuthEmailOtpCodeSent
        ? _state as AuthEmailOtpCodeSent
        : null;
    if (current == null) return Future<void>.value();
    final AuthEmailOtpChallenge challenge = current.challenge;
    if (!challenge.canResendAt(_clock())) {
      _emit(
        AuthEmailOtpCodeSent(
          challenge: challenge,
          failure: const AuthEmailOtpFailure(
            AuthEmailOtpFailureKind.rateLimited,
          ),
        ),
      );
      return Future<void>.value();
    }

    final int scopeVersion = ++_scopeVersion;
    _emit(
      AuthEmailOtpCodeSent(
        challenge: challenge,
        actionInFlight: true,
        resending: true,
      ),
    );
    return _track(
      _request(
        email: challenge.email,
        scopeVersion: scopeVersion,
        replacing: challenge,
      ),
    );
  }

  Future<void> verifyCode(String rawCode) {
    if (_disposed) return Future<void>.value();
    final Future<void>? pending = _pending;
    if (pending != null) return pending;

    if (_state case final AuthEmailOtpVerifiedState verified) {
      _emit(
        AuthEmailOtpVerifiedState(
          challenge: verified.challenge,
          session: verified.session,
          failure: const AuthEmailOtpFailure(
            AuthEmailOtpFailureKind.alreadyUsed,
          ),
        ),
      );
      return Future<void>.value();
    }

    final AuthEmailOtpCodeSent? current = _state is AuthEmailOtpCodeSent
        ? _state as AuthEmailOtpCodeSent
        : null;
    if (current == null) return Future<void>.value();
    final AuthEmailOtpChallenge challenge = current.challenge;
    if (challenge.isExpiredAt(_clock())) {
      _emit(
        AuthEmailOtpCodeSent(
          challenge: challenge,
          failure: const AuthEmailOtpFailure(AuthEmailOtpFailureKind.expired),
        ),
      );
      return Future<void>.value();
    }
    final AuthEmailOtpCode? code = AuthEmailOtpCode.tryCreate(rawCode);
    if (code == null) {
      _emit(
        AuthEmailOtpCodeSent(
          challenge: challenge,
          failure: const AuthEmailOtpFailure(
            AuthEmailOtpFailureKind.invalidCode,
          ),
        ),
      );
      return Future<void>.value();
    }

    final int scopeVersion = ++_scopeVersion;
    _emit(AuthEmailOtpCodeSent(challenge: challenge, actionInFlight: true));
    return _track(
      _verify(challenge: challenge, code: code, scopeVersion: scopeVersion),
    );
  }

  void changeEmail() {
    if (_disposed || _pending != null || _state is AuthEmailOtpVerifiedState) {
      return;
    }
    _scopeVersion += 1;
    _emit(const AuthEmailOtpEntry());
  }

  Future<void> _request({
    required AuthEmailAddress email,
    required int scopeVersion,
    required AuthEmailOtpChallenge? replacing,
  }) async {
    final AuthEmailOtpRequestResult result;
    try {
      result = await _service.requestCode(email);
    } on Object {
      if (_isCurrent(scopeVersion)) {
        _emitRequestFailure(
          replacing,
          const AuthEmailOtpFailure(AuthEmailOtpFailureKind.internal),
        );
      }
      return;
    }
    if (!_isCurrent(scopeVersion)) return;

    switch (result) {
      case AuthEmailOtpRequestAccepted():
        _generation += 1;
        _emit(
          AuthEmailOtpCodeSent(
            challenge: AuthEmailOtpChallenge.started(
              email: email,
              now: _clock(),
              generation: _generation,
            ),
          ),
        );
      case AuthEmailOtpRequestFailed(:final failure):
        _emitRequestFailure(replacing, failure);
    }
  }

  Future<void> _verify({
    required AuthEmailOtpChallenge challenge,
    required AuthEmailOtpCode code,
    required int scopeVersion,
  }) async {
    final AuthEmailOtpVerificationResult result;
    try {
      result = await _service.verifyCode(email: challenge.email, code: code);
    } on Object {
      if (_isCurrent(scopeVersion)) {
        _emit(
          AuthEmailOtpCodeSent(
            challenge: challenge,
            failure: const AuthEmailOtpFailure(
              AuthEmailOtpFailureKind.internal,
            ),
          ),
        );
      }
      return;
    }
    if (!_isCurrent(scopeVersion)) return;

    switch (result) {
      case AuthEmailOtpVerified(:final session):
        _emit(
          AuthEmailOtpVerifiedState(challenge: challenge, session: session),
        );
      case AuthEmailOtpVerificationFailed(:final failure):
        _emit(AuthEmailOtpCodeSent(challenge: challenge, failure: failure));
    }
  }

  Future<void> _track(Future<void> operation) {
    _pending = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_pending, operation)) _pending = null;
      }),
    );
    return operation;
  }

  void _emitRequestFailure(
    AuthEmailOtpChallenge? challenge,
    AuthEmailOtpFailure failure,
  ) {
    _emit(
      challenge == null
          ? AuthEmailOtpEntry(failure: failure)
          : AuthEmailOtpCodeSent(challenge: challenge, failure: failure),
    );
  }

  bool _isCurrent(int scopeVersion) =>
      !_disposed && _scopeVersion == scopeVersion;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _scopeVersion += 1;
    await _states.close();
  }

  void _emit(AuthEmailOtpState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }
}
