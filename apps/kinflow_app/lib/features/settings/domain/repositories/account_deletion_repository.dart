import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

abstract interface class AccountDeletionRepository {
  Future<AccountDeletionResult<AccountDeletionPreflight>> loadPreflight();

  Future<AccountDeletionResult<AccountDeletionRequest?>> loadLatest({
    AccountDeletionRequestId? requestId,
  });

  Future<AccountDeletionResult<AccountDeletionRequest>> requestDeletion({
    required bool subscriptionAcknowledged,
    required RecentAuthenticationProof recentAuthenticationProof,
    required AccountDeletionCommandId commandId,
  });

  Future<AccountDeletionResult<AccountDeletionRequest>> cancel({
    required AccountDeletionRequestId requestId,
    required int expectedVersion,
    required AccountDeletionCommandId commandId,
  });
}

sealed class AccountDeletionResult<T> {
  const AccountDeletionResult();
}

final class AccountDeletionSucceeded<T> extends AccountDeletionResult<T> {
  const AccountDeletionSucceeded(this.value);

  final T value;
}

final class AccountDeletionFailed<T> extends AccountDeletionResult<T> {
  const AccountDeletionFailed(this.failure);

  final AccountDeletionFailure failure;
}
