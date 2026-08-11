import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';

sealed class HouseholdPrivacyState {
  const HouseholdPrivacyState();
}

final class HouseholdPrivacyInitial extends HouseholdPrivacyState {
  const HouseholdPrivacyInitial();
}

final class HouseholdPrivacyLoading extends HouseholdPrivacyState {
  const HouseholdPrivacyLoading();
}

final class HouseholdPrivacyLoadFailed extends HouseholdPrivacyState {
  const HouseholdPrivacyLoadFailed(this.failure);

  final HouseholdPrivacyFailure failure;
}

final class HouseholdPrivacyReady extends HouseholdPrivacyState {
  const HouseholdPrivacyReady({
    required this.preflight,
    required this.latestRequest,
    this.isSubmitting = false,
    this.isRefreshing = false,
    this.failure,
    this.lastOpenedFormat,
  });

  final HouseholdPrivacyPreflight preflight;
  final HouseholdPrivacyRequest? latestRequest;
  final bool isSubmitting;
  final bool isRefreshing;
  final HouseholdPrivacyFailure? failure;
  final HouseholdExportFormat? lastOpenedFormat;

  bool get busy => isSubmitting || isRefreshing;
}
