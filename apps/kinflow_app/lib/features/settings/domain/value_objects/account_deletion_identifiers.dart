final RegExp _accountDeletionUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class AccountDeletionRequestId {
  const AccountDeletionRequestId._(this.value);

  final String value;

  static AccountDeletionRequestId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _accountDeletionUuidPattern.hasMatch(normalized)
        ? AccountDeletionRequestId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is AccountDeletionRequestId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class AccountDeletionCommandId {
  const AccountDeletionCommandId._(this.value);

  final String value;

  static AccountDeletionCommandId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _accountDeletionUuidPattern.hasMatch(normalized)
        ? AccountDeletionCommandId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is AccountDeletionCommandId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
