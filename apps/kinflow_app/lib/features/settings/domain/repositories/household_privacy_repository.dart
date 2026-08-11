import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/household_privacy_identifiers.dart';

abstract interface class HouseholdPrivacyRepository {
  Future<HouseholdPrivacyResult<HouseholdPrivacyPreflight>> loadPreflight(
    HouseholdId householdId,
  );

  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> loadStatus(
    HouseholdPrivacyRequestId requestId,
  );

  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> requestExport({
    required HouseholdId householdId,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  });

  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> requestDeletion({
    required HouseholdId householdId,
    required int expectedHouseholdVersion,
    required String confirmationName,
    required bool acknowledgeMemberAccessLoss,
    required bool acknowledgeSharedDataRedaction,
    required bool acknowledgeSubscriptionNotCancelled,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  });

  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> cancel({
    required HouseholdPrivacyRequestId requestId,
    required HouseholdPrivacyRequestKind kind,
    required int expectedVersion,
    required HouseholdCommandId commandId,
  });

  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> revokeExport({
    required HouseholdPrivacyRequestId requestId,
    required int expectedArtifactVersion,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  });

  Future<HouseholdPrivacyResult<HouseholdExportDownload>> createDownload({
    required HouseholdPrivacyRequestId requestId,
    required HouseholdExportFormat format,
    required RecentAuthenticationProof recentAuthenticationProof,
  });
}

sealed class HouseholdPrivacyResult<T> {
  const HouseholdPrivacyResult();
}

final class HouseholdPrivacySucceeded<T> extends HouseholdPrivacyResult<T> {
  const HouseholdPrivacySucceeded(this.value);

  final T value;
}

final class HouseholdPrivacyFailed<T> extends HouseholdPrivacyResult<T> {
  const HouseholdPrivacyFailed(this.failure);

  final HouseholdPrivacyFailure failure;
}
