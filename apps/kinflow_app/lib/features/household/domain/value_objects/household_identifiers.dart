final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class HouseholdId {
  const HouseholdId._(this.value);

  final String value;

  static HouseholdId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized) ? HouseholdId._(normalized) : null;
  }

  @override
  bool operator ==(Object other) {
    return other is HouseholdId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class HouseholdMemberId {
  const HouseholdMemberId._(this.value);

  final String value;

  static HouseholdMemberId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized)
        ? HouseholdMemberId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is HouseholdMemberId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}

final class HouseholdCreationId {
  const HouseholdCreationId._(this.value);

  final String value;

  static HouseholdCreationId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _uuidPattern.hasMatch(normalized)
        ? HouseholdCreationId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) {
    return other is HouseholdCreationId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;
}
