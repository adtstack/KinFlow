import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/household_privacy_identifiers.dart';

final class UnavailableHouseholdPrivacyRepository
    implements HouseholdPrivacyRepository {
  const UnavailableHouseholdPrivacyRepository();

  static const HouseholdPrivacyFailure _failure = HouseholdPrivacyFailure(
    HouseholdPrivacyFailureKind.temporarilyUnavailable,
  );

  HouseholdPrivacyResult<T> _failed<T>() => HouseholdPrivacyFailed<T>(_failure);

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyPreflight>> loadPreflight(
    HouseholdId householdId,
  ) async => _failed();

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> loadStatus(
    HouseholdPrivacyRequestId requestId,
  ) async => _failed();

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> requestExport({
    required HouseholdId householdId,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  }) async => _failed();

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> requestDeletion({
    required HouseholdId householdId,
    required int expectedHouseholdVersion,
    required String confirmationName,
    required bool acknowledgeMemberAccessLoss,
    required bool acknowledgeSharedDataRedaction,
    required bool acknowledgeSubscriptionNotCancelled,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  }) async => _failed();

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> cancel({
    required HouseholdPrivacyRequestId requestId,
    required HouseholdPrivacyRequestKind kind,
    required int expectedVersion,
    required HouseholdCommandId commandId,
  }) async => _failed();

  @override
  Future<HouseholdPrivacyResult<HouseholdPrivacyRequest>> revokeExport({
    required HouseholdPrivacyRequestId requestId,
    required int expectedArtifactVersion,
    required RecentAuthenticationProof recentAuthenticationProof,
    required HouseholdCommandId commandId,
  }) async => _failed();

  @override
  Future<HouseholdPrivacyResult<HouseholdExportDownload>> createDownload({
    required HouseholdPrivacyRequestId requestId,
    required HouseholdExportFormat format,
    required RecentAuthenticationProof recentAuthenticationProof,
  }) async => _failed();
}
