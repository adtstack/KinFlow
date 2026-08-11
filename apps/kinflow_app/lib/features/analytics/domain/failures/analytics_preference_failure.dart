enum AnalyticsPreferenceFailureKind { temporarilyUnavailable, internal }

final class AnalyticsPreferenceFailure {
  const AnalyticsPreferenceFailure(this.kind);

  final AnalyticsPreferenceFailureKind kind;

  String get stableCode => switch (kind) {
    AnalyticsPreferenceFailureKind.temporarilyUnavailable =>
      'ANALYTICS_PREFERENCE_UNAVAILABLE',
    AnalyticsPreferenceFailureKind.internal => 'ANALYTICS_PREFERENCE_INTERNAL',
  };
}
