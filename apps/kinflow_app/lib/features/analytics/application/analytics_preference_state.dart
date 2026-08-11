import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/failures/analytics_preference_failure.dart';

sealed class AnalyticsPreferenceState {
  const AnalyticsPreferenceState();
}

final class AnalyticsPreferenceInitial extends AnalyticsPreferenceState {
  const AnalyticsPreferenceInitial();
}

final class AnalyticsPreferenceLoading extends AnalyticsPreferenceState {
  const AnalyticsPreferenceLoading();
}

final class AnalyticsPreferenceLoadFailed extends AnalyticsPreferenceState {
  const AnalyticsPreferenceLoadFailed(this.failure);

  final AnalyticsPreferenceFailure failure;
}

final class AnalyticsPreferenceReady extends AnalyticsPreferenceState {
  const AnalyticsPreferenceReady({
    required this.preference,
    this.isRefreshing = false,
    this.isSaving = false,
    this.failure,
    this.saveCount = 0,
  });

  final AnalyticsUsagePreference preference;
  final bool isRefreshing;
  final bool isSaving;
  final AnalyticsPreferenceFailure? failure;
  final int saveCount;

  bool get busy => isRefreshing || isSaving;
}
