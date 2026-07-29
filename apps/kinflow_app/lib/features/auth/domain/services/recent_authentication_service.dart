enum RecentAuthenticationFailureKind {
  unauthenticated,
  cancelled,
  providerUnavailable,
  temporarilyUnavailable,
  accountChanged,
  invalidProof,
  internal,
}

final class RecentAuthenticationProof {
  const RecentAuthenticationProof._(this.value);

  final String value;

  static RecentAuthenticationProof? tryParse(String value) {
    final String normalized = value.trim();
    return normalized.length >= 16 && normalized.length <= 2048
        ? RecentAuthenticationProof._(normalized)
        : null;
  }

  @override
  String toString() => 'RecentAuthenticationProof(redacted)';
}

abstract interface class RecentAuthenticationService {
  bool get isAvailable;

  Future<RecentAuthenticationResult> authenticate();
}

sealed class RecentAuthenticationResult {
  const RecentAuthenticationResult();
}

final class RecentAuthenticationCompleted extends RecentAuthenticationResult {
  const RecentAuthenticationCompleted(this.proof);

  final RecentAuthenticationProof proof;
}

final class RecentAuthenticationFailed extends RecentAuthenticationResult {
  const RecentAuthenticationFailed(this.kind);

  final RecentAuthenticationFailureKind kind;
}
