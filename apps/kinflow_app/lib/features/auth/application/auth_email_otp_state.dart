import 'package:kinflow_app/features/auth/domain/entities/auth_email_otp_challenge.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';

sealed class AuthEmailOtpState {
  const AuthEmailOtpState();

  AuthEmailOtpFailure? get failure => switch (this) {
    AuthEmailOtpEntry(:final failure) => failure,
    AuthEmailOtpCodeSent(:final failure) => failure,
    AuthEmailOtpVerifiedState(:final failure) => failure,
    _ => null,
  };

  bool get isBusy =>
      this is AuthEmailOtpRequesting ||
      (this is AuthEmailOtpCodeSent &&
          (this as AuthEmailOtpCodeSent).actionInFlight);
}

final class AuthEmailOtpEntry extends AuthEmailOtpState {
  const AuthEmailOtpEntry({this.failure});

  @override
  final AuthEmailOtpFailure? failure;
}

final class AuthEmailOtpRequesting extends AuthEmailOtpState {
  const AuthEmailOtpRequesting(this.email);

  final AuthEmailAddress email;
}

final class AuthEmailOtpCodeSent extends AuthEmailOtpState {
  const AuthEmailOtpCodeSent({
    required this.challenge,
    this.actionInFlight = false,
    this.resending = false,
    this.failure,
  });

  final AuthEmailOtpChallenge challenge;
  final bool actionInFlight;
  final bool resending;

  @override
  final AuthEmailOtpFailure? failure;
}

final class AuthEmailOtpVerifiedState extends AuthEmailOtpState {
  const AuthEmailOtpVerifiedState({
    required this.challenge,
    required this.session,
    this.failure,
  });

  final AuthEmailOtpChallenge challenge;
  final AuthSession session;

  @override
  final AuthEmailOtpFailure? failure;
}
