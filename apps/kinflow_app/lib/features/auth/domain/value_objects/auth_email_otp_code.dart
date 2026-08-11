final RegExp _authEmailOtpCodePattern = RegExp(r'^\d{6}$');

final class AuthEmailOtpCode {
  const AuthEmailOtpCode._(this.value);

  final String value;

  static AuthEmailOtpCode? tryCreate(String rawValue) {
    final String normalized = rawValue.trim();
    return _authEmailOtpCodePattern.hasMatch(normalized)
        ? AuthEmailOtpCode._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthEmailOtpCode && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AuthEmailOtpCode(<redacted>)';
}
