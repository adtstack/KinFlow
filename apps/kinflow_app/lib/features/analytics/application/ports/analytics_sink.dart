import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';

abstract interface class AnalyticsSink {
  AnalyticsSinkAvailability get availability;

  Future<void> emit(AnalyticsEnvelope envelope);
}
