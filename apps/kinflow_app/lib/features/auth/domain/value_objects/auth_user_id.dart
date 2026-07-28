final class AuthUserId {
  const AuthUserId._(this.value);

  final String value;

  static AuthUserId? tryParse(String rawValue) {
    if (!_uuidPattern.hasMatch(rawValue)) {
      return null;
    }

    return AuthUserId._(rawValue.toLowerCase());
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthUserId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'AuthUserId(<redacted>)';
}
