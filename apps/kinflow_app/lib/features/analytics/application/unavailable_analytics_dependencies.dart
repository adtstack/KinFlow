import 'package:kinflow_app/features/analytics/application/ports/analytics_sink.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/failures/analytics_preference_failure.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';

final class UnavailableAnalyticsPreferenceRepository
    implements AnalyticsPreferenceRepository {
  const UnavailableAnalyticsPreferenceRepository();

  static const AnalyticsPreferenceResult _failure = AnalyticsPreferenceFailed(
    AnalyticsPreferenceFailure(
      AnalyticsPreferenceFailureKind.temporarilyUnavailable,
    ),
  );

  @override
  Future<AnalyticsPreferenceResult> load() async => _failure;

  @override
  Future<AnalyticsPreferenceResult> save(
    AnalyticsUsagePreference preference,
  ) async => _failure;
}

final class UnavailableAnalyticsSink implements AnalyticsSink {
  const UnavailableAnalyticsSink();

  @override
  AnalyticsSinkAvailability get availability =>
      AnalyticsSinkAvailability.unavailable;

  @override
  Future<void> emit(AnalyticsEnvelope envelope) async {}
}
