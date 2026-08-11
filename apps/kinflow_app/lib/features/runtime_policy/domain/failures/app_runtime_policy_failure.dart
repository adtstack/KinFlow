enum AppRuntimePolicyFailureKind {
  unavailable,
  invalidMetadata,
  invalidPayload,
}

final class AppRuntimePolicyFailure {
  const AppRuntimePolicyFailure(this.kind);

  final AppRuntimePolicyFailureKind kind;
}
