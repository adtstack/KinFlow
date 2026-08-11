final RegExp _dataExportUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

final class DataExportRequestId {
  const DataExportRequestId._(this.value);

  final String value;

  static DataExportRequestId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _dataExportUuidPattern.hasMatch(normalized)
        ? DataExportRequestId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is DataExportRequestId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class DataExportArtifactId {
  const DataExportArtifactId._(this.value);

  final String value;

  static DataExportArtifactId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _dataExportUuidPattern.hasMatch(normalized)
        ? DataExportArtifactId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is DataExportArtifactId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

final class DataExportCommandId {
  const DataExportCommandId._(this.value);

  final String value;

  static DataExportCommandId? tryParse(String value) {
    final String normalized = value.trim().toLowerCase();
    return _dataExportUuidPattern.hasMatch(normalized)
        ? DataExportCommandId._(normalized)
        : null;
  }

  @override
  bool operator ==(Object other) =>
      other is DataExportCommandId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}
