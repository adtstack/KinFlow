import 'package:kinflow_app/features/auth/domain/value_objects/auth_email_address.dart';

final class AuthEmailOtpChallenge {
  const AuthEmailOtpChallenge({
    required this.email,
    required this.requestedAt,
    required this.resendAvailableAt,
    required this.expiresAt,
    required this.generation,
  });

  factory AuthEmailOtpChallenge.started({
    required AuthEmailAddress email,
    required DateTime now,
    required int generation,
  }) {
    final DateTime requestedAt = now.toUtc();
    return AuthEmailOtpChallenge(
      email: email,
      requestedAt: requestedAt,
      resendAvailableAt: requestedAt.add(const Duration(seconds: 60)),
      expiresAt: requestedAt.add(const Duration(minutes: 10)),
      generation: generation,
    );
  }

  final AuthEmailAddress email;
  final DateTime requestedAt;
  final DateTime resendAvailableAt;
  final DateTime expiresAt;
  final int generation;

  bool canResendAt(DateTime now) => !now.toUtc().isBefore(resendAvailableAt);

  bool isExpiredAt(DateTime now) => !now.toUtc().isBefore(expiresAt);

  @override
  String toString() =>
      'AuthEmailOtpChallenge(email: <redacted>, generation: $generation)';
}
