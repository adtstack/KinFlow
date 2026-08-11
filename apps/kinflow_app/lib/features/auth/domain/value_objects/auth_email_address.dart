final RegExp _authEmailPattern = RegExp(r'^[^\s@]+@[^\s@]+$');

final class AuthEmailAddress {
  const AuthEmailAddress._(this.value);

  final String value;

  static AuthEmailAddress? tryCreate(String rawValue) {
    final String normalized = rawValue.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized.length > 254 ||
        !_authEmailPattern.hasMatch(normalized)) {
      return null;
    }
    return AuthEmailAddress._(normalized);
  }

  String get maskedForDisplay {
    final int separator = value.indexOf('@');
    final String localPart = value.substring(0, separator);
    final String domain = value.substring(separator + 1);
    final String visiblePrefix = localPart.length == 1
        ? '•'
        : '${localPart.substring(0, 1)}•••';
    return '$visiblePrefix@$domain';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthEmailAddress && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AuthEmailAddress(<redacted>)';
}
