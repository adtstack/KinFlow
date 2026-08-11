import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

final class UnavailableAccountDeletionRepository
    implements AccountDeletionRepository {
  const UnavailableAccountDeletionRepository();

  static const AccountDeletionFailure _failure = AccountDeletionFailure(
    AccountDeletionFailureKind.temporarilyUnavailable,
  );

  @override
  Future<AccountDeletionResult<AccountDeletionPreflight>>
  loadPreflight() async {
    return const AccountDeletionFailed<AccountDeletionPreflight>(_failure);
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest?>> loadLatest({
    AccountDeletionRequestId? requestId,
  }) async {
    return const AccountDeletionFailed<AccountDeletionRequest?>(_failure);
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest>> requestDeletion({
    required bool subscriptionAcknowledged,
    required RecentAuthenticationProof recentAuthenticationProof,
    required AccountDeletionCommandId commandId,
  }) async {
    return const AccountDeletionFailed<AccountDeletionRequest>(_failure);
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest>> cancel({
    required AccountDeletionRequestId requestId,
    required int expectedVersion,
    required AccountDeletionCommandId commandId,
  }) async {
    return const AccountDeletionFailed<AccountDeletionRequest>(_failure);
  }
}
