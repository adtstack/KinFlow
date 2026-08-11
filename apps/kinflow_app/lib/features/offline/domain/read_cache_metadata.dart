final class ReadCacheMetadata {
  ReadCacheMetadata({required this.validatedAt, required this.expiresAt})
    : assert(validatedAt.isUtc),
      assert(expiresAt.isUtc),
      assert(expiresAt.isAfter(validatedAt));

  final DateTime validatedAt;
  final DateTime expiresAt;

  bool isValidAt(DateTime value) {
    final DateTime instant = value.toUtc();
    return !instant.isBefore(validatedAt) && instant.isBefore(expiresAt);
  }

  @override
  bool operator ==(Object other) {
    return other is ReadCacheMetadata &&
        other.validatedAt == validatedAt &&
        other.expiresAt == expiresAt;
  }

  @override
  int get hashCode => Object.hash(validatedAt, expiresAt);
}
