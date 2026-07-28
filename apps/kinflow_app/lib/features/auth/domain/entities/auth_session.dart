import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';

final class AuthSession {
  const AuthSession({required this.userId});

  final AuthUserId userId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthSession && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'AuthSession(userId: <redacted>)';
}
