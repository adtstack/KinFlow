import 'package:kinflow_app/features/analytics/application/ports/analytics_sink.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';

enum AnalyticsDispatchResult {
  sent,
  blockedChildMode,
  blockedPreference,
  unavailable,
  failed,
}

final class AnalyticsDispatcher {
  const AnalyticsDispatcher(
    this._preferenceRepository,
    this._sink,
    this._metadata,
  );

  final AnalyticsPreferenceRepository _preferenceRepository;
  final AnalyticsSink _sink;
  final AnalyticsDispatchMetadata _metadata;

  Future<AnalyticsDispatchResult> track(
    AnalyticsEventName event, {
    AnalyticsActorMode actorMode = AnalyticsActorMode.adult,
  }) async {
    if (actorMode == AnalyticsActorMode.managedChild) {
      return AnalyticsDispatchResult.blockedChildMode;
    }

    final AnalyticsPreferenceResult preferenceResult;
    try {
      preferenceResult = await _preferenceRepository.load();
    } on Object {
      return AnalyticsDispatchResult.blockedPreference;
    }
    if (preferenceResult case AnalyticsPreferenceFailed()) {
      return AnalyticsDispatchResult.blockedPreference;
    }
    final AnalyticsUsagePreference preference =
        (preferenceResult as AnalyticsPreferenceSucceeded).preference;
    if (preference != AnalyticsUsagePreference.granted) {
      return AnalyticsDispatchResult.blockedPreference;
    }

    try {
      if (_sink.availability != AnalyticsSinkAvailability.available) {
        return AnalyticsDispatchResult.unavailable;
      }
      await _sink.emit(AnalyticsEnvelope(event: event, metadata: _metadata));
      return AnalyticsDispatchResult.sent;
    } on Object {
      return AnalyticsDispatchResult.failed;
    }
  }
}
