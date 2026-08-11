import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/datasources/account_deletion_data_source.dart';
import 'package:kinflow_app/features/settings/data/repositories/provider_account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';

void main() {
  test('maps preflight and pending status into domain invariants', () async {
    final _FakeAccountDeletionDataSource dataSource =
        _FakeAccountDeletionDataSource(
          preflightResult:
              AccountDeletionDataSucceeded<AccountDeletionPreflightDataRecord>(
                _preflightRecord(pending: true),
              ),
          statusResult:
              AccountDeletionDataSucceeded<AccountDeletionRequestDataRecord?>(
                _requestRecord(),
              ),
        );
    final ProviderAccountDeletionRepository repository =
        ProviderAccountDeletionRepository(dataSource);

    final AccountDeletionResult<AccountDeletionPreflight> preflightResult =
        await repository.loadPreflight();
    final AccountDeletionResult<AccountDeletionRequest?> requestResult =
        await repository.loadLatest();

    expect(
      (preflightResult as AccountDeletionSucceeded<AccountDeletionPreflight>)
          .value
          .pendingStatus,
      AccountDeletionRequestStatus.queued,
    );
    expect(
      (requestResult as AccountDeletionSucceeded<AccountDeletionRequest?>)
          .value
          ?.cancellable,
      isTrue,
    );
  });

  test('rejects a non-UTC optional timestamp instead of erasing it', () async {
    final _FakeAccountDeletionDataSource dataSource =
        _FakeAccountDeletionDataSource(
          statusResult:
              AccountDeletionDataSucceeded<AccountDeletionRequestDataRecord?>(
                AccountDeletionRequestDataRecord(
                  id: _requestId,
                  type: 'deleteAccount',
                  status: 'processing',
                  requestedAt: '2026-08-08T01:00:00Z',
                  scheduledFor: '2026-08-09T01:00:00Z',
                  processingStartedAt: '2026-08-09 10:00:00',
                  completedAt: null,
                  failedAt: null,
                  cancelledAt: null,
                  failureCode: null,
                  activeSubscriptionAtRequest: false,
                  subscriptionAcknowledged: false,
                  cancellable: false,
                  version: 2,
                ),
              ),
        );
    final AccountDeletionResult<AccountDeletionRequest?> result =
        await ProviderAccountDeletionRepository(dataSource).loadLatest();

    expect(
      (result as AccountDeletionFailed<AccountDeletionRequest?>).failure.kind,
      AccountDeletionFailureKind.invalidPayload,
    );
  });

  test('maps stable data failures without leaking provider details', () async {
    final _FakeAccountDeletionDataSource
    dataSource = _FakeAccountDeletionDataSource(
      preflightResult:
          const AccountDeletionDataFailed<AccountDeletionPreflightDataRecord>(
            AccountDeletionDataFailureKind.requestsPaused,
          ),
    );

    final AccountDeletionResult<AccountDeletionPreflight> result =
        await ProviderAccountDeletionRepository(dataSource).loadPreflight();

    expect(
      (result as AccountDeletionFailed<AccountDeletionPreflight>).failure.kind,
      AccountDeletionFailureKind.requestsPaused,
    );
  });
}

const String _requestId = '71000000-0000-4000-8000-000000000001';

AccountDeletionPreflightDataRecord _preflightRecord({bool pending = false}) {
  return AccountDeletionPreflightDataRecord(
    canRequest: !pending,
    ownerHouseholdCount: 0,
    hasActiveSubscription: false,
    pendingRequestId: pending ? _requestId : null,
    pendingStatus: pending ? 'queued' : null,
    pendingRequestVersion: pending ? 1 : null,
    requestsEnabled: true,
    cancellationWindowSeconds: 86400,
    evaluatedAt: '2026-08-08T01:00:00Z',
  );
}

AccountDeletionRequestDataRecord _requestRecord() {
  return const AccountDeletionRequestDataRecord(
    id: _requestId,
    type: 'deleteAccount',
    status: 'queued',
    requestedAt: '2026-08-08T01:00:00Z',
    scheduledFor: '2026-08-09T01:00:00Z',
    processingStartedAt: null,
    completedAt: null,
    failedAt: null,
    cancelledAt: null,
    failureCode: null,
    activeSubscriptionAtRequest: false,
    subscriptionAcknowledged: false,
    cancellable: true,
    version: 1,
  );
}

final class _FakeAccountDeletionDataSource
    implements AccountDeletionDataSource {
  _FakeAccountDeletionDataSource({
    AccountDeletionDataResult<AccountDeletionPreflightDataRecord>?
    preflightResult,
    AccountDeletionDataResult<AccountDeletionRequestDataRecord?>? statusResult,
  }) : preflightResult =
           preflightResult ??
           AccountDeletionDataSucceeded<AccountDeletionPreflightDataRecord>(
             _preflightRecord(),
           ),
       statusResult =
           statusResult ??
           const AccountDeletionDataSucceeded<
             AccountDeletionRequestDataRecord?
           >(null);

  final AccountDeletionDataResult<AccountDeletionPreflightDataRecord>
  preflightResult;
  final AccountDeletionDataResult<AccountDeletionRequestDataRecord?>
  statusResult;

  @override
  Future<AccountDeletionDataResult<AccountDeletionPreflightDataRecord>>
  preflight() async => preflightResult;

  @override
  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord?>> status({
    String? requestId,
  }) async => statusResult;

  @override
  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord>> request({
    required bool subscriptionAcknowledged,
    required String recentAuthenticationProof,
    required String idempotencyKey,
  }) async => AccountDeletionDataSucceeded<AccountDeletionRequestDataRecord>(
    _requestRecord(),
  );

  @override
  Future<AccountDeletionDataResult<AccountDeletionRequestDataRecord>> cancel({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async => AccountDeletionDataSucceeded<AccountDeletionRequestDataRecord>(
    _requestRecord(),
  );
}
