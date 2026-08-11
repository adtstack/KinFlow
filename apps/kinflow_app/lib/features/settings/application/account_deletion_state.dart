import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';

sealed class AccountDeletionState {
  const AccountDeletionState();
}

final class AccountDeletionInitial extends AccountDeletionState {
  const AccountDeletionInitial();
}

final class AccountDeletionLoading extends AccountDeletionState {
  const AccountDeletionLoading();
}

final class AccountDeletionLoadFailed extends AccountDeletionState {
  const AccountDeletionLoadFailed(this.failure);

  final AccountDeletionFailure failure;
}

final class AccountDeletionReady extends AccountDeletionState {
  const AccountDeletionReady({
    required this.preflight,
    required this.latestRequest,
    this.isSubmitting = false,
    this.isRefreshing = false,
    this.failure,
    this.logoutRequested = false,
  });

  final AccountDeletionPreflight preflight;
  final AccountDeletionRequest? latestRequest;
  final bool isSubmitting;
  final bool isRefreshing;
  final AccountDeletionFailure? failure;
  final bool logoutRequested;

  bool get busy => isSubmitting || isRefreshing;
}
