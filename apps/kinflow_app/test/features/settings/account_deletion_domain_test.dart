import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

import '../../support/fakes/fake_account_deletion_dependencies.dart';

void main() {
  test('preflight enforces the server eligibility equation', () {
    final AccountDeletionPreflight eligible = accountDeletionPreflightFixture();
    expect(eligible.canRequest, isTrue);
    expect(eligible.cancellationWindow, const Duration(hours: 24));

    expect(
      AccountDeletionPreflight.tryCreate(
        canRequest: true,
        ownerHouseholdCount: 1,
        hasActiveSubscription: false,
        pendingRequestId: null,
        pendingStatus: null,
        pendingRequestVersion: null,
        requestsEnabled: true,
        cancellationWindow: const Duration(hours: 24),
        evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
      ),
      isNull,
    );
  });

  test('preflight requires complete pending request metadata', () {
    expect(
      AccountDeletionPreflight.tryCreate(
        canRequest: false,
        ownerHouseholdCount: 0,
        hasActiveSubscription: false,
        pendingRequestId: AccountDeletionRequestId.tryParse(
          accountDeletionRequestUuid,
        ),
        pendingStatus: null,
        pendingRequestVersion: 1,
        requestsEnabled: true,
        cancellationWindow: const Duration(hours: 24),
        evaluatedAt: DateTime.parse('2026-08-08T01:00:00Z'),
      ),
      isNull,
    );
  });

  test('request status shapes reject impossible provider payloads', () {
    final AccountDeletionRequest queued = accountDeletionRequestFixture();
    expect(queued.cancellable, isTrue);

    expect(
      AccountDeletionRequest.tryCreate(
        id: queued.id,
        status: AccountDeletionRequestStatus.completed,
        requestedAt: queued.requestedAt,
        scheduledFor: queued.scheduledFor,
        processingStartedAt: null,
        completedAt: DateTime.parse('2026-08-09T01:05:00Z'),
        failedAt: null,
        cancelledAt: null,
        failureCode: null,
        activeSubscriptionAtRequest: false,
        subscriptionAcknowledged: false,
        cancellable: false,
        version: 2,
      ),
      isNull,
    );

    expect(
      accountDeletionRequestFixture(
        status: AccountDeletionRequestStatus.cancelled,
        version: 2,
      ).cancellable,
      isFalse,
    );
  });

  test('active subscription requests require an acknowledgement', () {
    final AccountDeletionRequest queued = accountDeletionRequestFixture();
    expect(
      AccountDeletionRequest.tryCreate(
        id: queued.id,
        status: AccountDeletionRequestStatus.queued,
        requestedAt: queued.requestedAt,
        scheduledFor: queued.scheduledFor,
        processingStartedAt: null,
        completedAt: null,
        failedAt: null,
        cancelledAt: null,
        failureCode: null,
        activeSubscriptionAtRequest: true,
        subscriptionAcknowledged: false,
        cancellable: true,
        version: 1,
      ),
      isNull,
    );
  });
}
