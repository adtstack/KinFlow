import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/account_deletion_command_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

const String accountDeletionRequestUuid =
    '71000000-0000-4000-8000-000000000001';

AccountDeletionPreflight accountDeletionPreflightFixture({
  int ownerHouseholdCount = 0,
  bool hasActiveSubscription = false,
  bool requestsEnabled = true,
  AccountDeletionRequest? pendingRequest,
}) {
  return AccountDeletionPreflight.tryCreate(
    canRequest:
        requestsEnabled && ownerHouseholdCount == 0 && pendingRequest == null,
    ownerHouseholdCount: ownerHouseholdCount,
    hasActiveSubscription: hasActiveSubscription,
    pendingRequestId: pendingRequest?.id,
    pendingStatus: pendingRequest?.status,
    pendingRequestVersion: pendingRequest?.version,
    requestsEnabled: requestsEnabled,
    cancellationWindow: const Duration(hours: 24),
    evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
  )!;
}

AccountDeletionRequest accountDeletionRequestFixture({
  AccountDeletionRequestStatus status = AccountDeletionRequestStatus.queued,
  bool activeSubscriptionAtRequest = false,
  int version = 1,
}) {
  final DateTime requestedAt = DateTime.parse('2026-08-08T01:00:00Z');
  final DateTime processingAt = DateTime.parse('2026-08-09T01:00:00Z');
  final bool processingStarted = switch (status) {
    AccountDeletionRequestStatus.processing ||
    AccountDeletionRequestStatus.completed ||
    AccountDeletionRequestStatus.failed => true,
    _ => false,
  };
  return AccountDeletionRequest.tryCreate(
    id: AccountDeletionRequestId.tryParse(accountDeletionRequestUuid)!,
    status: status,
    requestedAt: requestedAt,
    scheduledFor: DateTime.parse('2026-08-09T01:00:00Z'),
    processingStartedAt: processingStarted ? processingAt : null,
    completedAt: status == AccountDeletionRequestStatus.completed
        ? DateTime.parse('2026-08-09T01:05:00Z')
        : null,
    failedAt: status == AccountDeletionRequestStatus.failed
        ? DateTime.parse('2026-08-09T01:05:00Z')
        : null,
    cancelledAt: status == AccountDeletionRequestStatus.cancelled
        ? DateTime.parse('2026-08-08T02:00:00Z')
        : null,
    failureCode: status == AccountDeletionRequestStatus.failed
        ? 'AUTH_DELETE_ATTEMPTS_EXHAUSTED'
        : null,
    activeSubscriptionAtRequest: activeSubscriptionAtRequest,
    subscriptionAcknowledged: activeSubscriptionAtRequest,
    cancellable:
        status == AccountDeletionRequestStatus.queued ||
        status == AccountDeletionRequestStatus.verifying,
    version: version,
  )!;
}

final class FakeAccountDeletionRepository implements AccountDeletionRepository {
  FakeAccountDeletionRepository({
    AccountDeletionResult<AccountDeletionPreflight>? preflightResult,
    AccountDeletionResult<AccountDeletionRequest?>? latestResult,
    List<AccountDeletionResult<AccountDeletionRequest>>? requestResults,
    List<AccountDeletionResult<AccountDeletionRequest>>? cancelResults,
  }) : preflightResult =
           preflightResult ??
           AccountDeletionSucceeded<AccountDeletionPreflight>(
             accountDeletionPreflightFixture(),
           ),
       latestResult =
           latestResult ??
           const AccountDeletionSucceeded<AccountDeletionRequest?>(null),
       requestResults = List<AccountDeletionResult<AccountDeletionRequest>>.of(
         requestResults ??
             <AccountDeletionResult<AccountDeletionRequest>>[
               AccountDeletionSucceeded<AccountDeletionRequest>(
                 accountDeletionRequestFixture(),
               ),
             ],
       ),
       cancelResults = List<AccountDeletionResult<AccountDeletionRequest>>.of(
         cancelResults ??
             <AccountDeletionResult<AccountDeletionRequest>>[
               AccountDeletionSucceeded<AccountDeletionRequest>(
                 accountDeletionRequestFixture(
                   status: AccountDeletionRequestStatus.cancelled,
                   version: 2,
                 ),
               ),
             ],
       );

  AccountDeletionResult<AccountDeletionPreflight> preflightResult;
  AccountDeletionResult<AccountDeletionRequest?> latestResult;
  final List<AccountDeletionResult<AccountDeletionRequest>> requestResults;
  final List<AccountDeletionResult<AccountDeletionRequest>> cancelResults;
  final List<AccountDeletionRequestCall> requestCalls =
      <AccountDeletionRequestCall>[];
  final List<AccountDeletionCancelCall> cancelCalls =
      <AccountDeletionCancelCall>[];
  final List<AccountDeletionRequestId?> statusRequestIds =
      <AccountDeletionRequestId?>[];
  int preflightCount = 0;

  @override
  Future<AccountDeletionResult<AccountDeletionPreflight>>
  loadPreflight() async {
    preflightCount += 1;
    return preflightResult;
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest?>> loadLatest({
    AccountDeletionRequestId? requestId,
  }) async {
    statusRequestIds.add(requestId);
    return latestResult;
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest>> requestDeletion({
    required bool subscriptionAcknowledged,
    required RecentAuthenticationProof recentAuthenticationProof,
    required AccountDeletionCommandId commandId,
  }) async {
    requestCalls.add(
      AccountDeletionRequestCall(
        subscriptionAcknowledged: subscriptionAcknowledged,
        recentAuthenticationProof: recentAuthenticationProof,
        commandId: commandId,
      ),
    );
    return requestResults.removeAt(0);
  }

  @override
  Future<AccountDeletionResult<AccountDeletionRequest>> cancel({
    required AccountDeletionRequestId requestId,
    required int expectedVersion,
    required AccountDeletionCommandId commandId,
  }) async {
    cancelCalls.add(
      AccountDeletionCancelCall(
        requestId: requestId,
        expectedVersion: expectedVersion,
        commandId: commandId,
      ),
    );
    return cancelResults.removeAt(0);
  }
}

final class AccountDeletionRequestCall {
  const AccountDeletionRequestCall({
    required this.subscriptionAcknowledged,
    required this.recentAuthenticationProof,
    required this.commandId,
  });

  final bool subscriptionAcknowledged;
  final RecentAuthenticationProof recentAuthenticationProof;
  final AccountDeletionCommandId commandId;
}

final class AccountDeletionCancelCall {
  const AccountDeletionCancelCall({
    required this.requestId,
    required this.expectedVersion,
    required this.commandId,
  });

  final AccountDeletionRequestId requestId;
  final int expectedVersion;
  final AccountDeletionCommandId commandId;
}

final class FakeAccountDeletionCommandIdGenerator
    implements AccountDeletionCommandIdGenerator {
  int generateCount = 0;

  @override
  AccountDeletionCommandId generate() {
    generateCount += 1;
    return AccountDeletionCommandId.tryParse(
      '72000000-0000-4000-8000-${generateCount.toString().padLeft(12, '0')}',
    )!;
  }
}
