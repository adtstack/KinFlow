final class FoundationSampleId {
  const FoundationSampleId._(this.value);

  final String value;

  static FoundationSampleId? tryParse(String rawValue) {
    if (rawValue.isEmpty || rawValue.length > 64) {
      return null;
    }

    if (!_validCharacters.hasMatch(rawValue)) {
      return null;
    }

    return FoundationSampleId._(rawValue);
  }

  static final RegExp _validCharacters = RegExp(r'^[a-z0-9][a-z0-9_-]*$');

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FoundationSampleId && other.value == value;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
