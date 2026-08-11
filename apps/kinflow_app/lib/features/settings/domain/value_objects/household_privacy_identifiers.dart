final RegExp _householdPrivacyUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class HouseholdPrivacyRequestId {
  const HouseholdPrivacyRequestId._(this.value);

  final String value;

  static HouseholdPrivacyRequestId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _householdPrivacyUuidPattern.hasMatch(normalized)
        ? HouseholdPrivacyRequestId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is HouseholdPrivacyRequestId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class HouseholdExportArtifactId {
  const HouseholdExportArtifactId._(this.value);

  final String value;

  static HouseholdExportArtifactId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _householdPrivacyUuidPattern.hasMatch(normalized)
        ? HouseholdExportArtifactId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is HouseholdExportArtifactId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
