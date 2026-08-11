enum DiagnosticReportFailureKind {
  unavailable,
  invalidMetadata,
  clipboardUnavailable,
  internal,
}

final class DiagnosticReportFailure {
  const DiagnosticReportFailure(this.kind);

  final DiagnosticReportFailureKind kind;
}
