final RegExp _inviteUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final RegExp _inviteTokenPattern = RegExp(r'^[A-Za-z0-9_-]{20,512}$');
final RegExp _inviteShortCodePattern = RegExp(
  r'^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{8}$',
);

final class InviteId {
  const InviteId._(this.value);

  final String value;

  static InviteId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _inviteUuidPattern.hasMatch(normalized)
        ? InviteId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) => other is InviteId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class InviteCommandId {
  const InviteCommandId._(this.value);

  final String value;

  static InviteCommandId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _inviteUuidPattern.hasMatch(normalized)
        ? InviteCommandId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is InviteCommandId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class InviteToken {
  const InviteToken._(this.value);

  final String value;

  static InviteToken? tryParse(String value) {
    return _inviteTokenPattern.hasMatch(value) ? InviteToken._(value) : null;
  }

  @override
  bool operator ==(Object other) {
    return other is InviteToken && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'InviteToken(redacted)';
}

final class InviteShortCode {
  const InviteShortCode._(this.value);

  final String value;

  String get formatted => '${value.substring(0, 4)}-${value.substring(4)}';

  static InviteShortCode? tryParse(String value) {
    final String normalized = value.trim().toUpperCase().replaceAll(
      RegExp(r'[ -]'),
      '',
    );
    return _inviteShortCodePattern.hasMatch(normalized)
        ? InviteShortCode._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is InviteShortCode && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'InviteShortCode(redacted)';
}
