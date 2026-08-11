import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/failures/analytics_preference_failure.dart';

abstract interface class AnalyticsPreferenceRepository {
  Future<AnalyticsPreferenceResult> load();

  Future<AnalyticsPreferenceResult> save(AnalyticsUsagePreference preference);
}

sealed class AnalyticsPreferenceResult {
  const AnalyticsPreferenceResult();
}

final class AnalyticsPreferenceSucceeded extends AnalyticsPreferenceResult {
  const AnalyticsPreferenceSucceeded(this.preference);

  final AnalyticsUsagePreference preference;
}

final class AnalyticsPreferenceFailed extends AnalyticsPreferenceResult {
  const AnalyticsPreferenceFailed(this.failure);

  final AnalyticsPreferenceFailure failure;
}
