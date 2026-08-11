import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/application/account_deletion_controller.dart';
import 'package:kinflow_app/features/settings/application/account_deletion_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';

import '../../support/fakes/fake_account_deletion_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';

void main() {
  test('loads preflight then resolves its pending request by ID', () async {
    final AccountDeletionRequest pending = accountDeletionRequestFixture();
    final FakeAccountDeletionRepository repository =
        FakeAccountDeletionRepository(
          preflightResult: AccountDeletionSucceeded<AccountDeletionPreflight>(
            accountDeletionPreflightFixture(pendingRequest: pending),
          ),
          latestResult: AccountDeletionSucceeded<AccountDeletionRequest?>(
            pending,
          ),
        );
    final AccountDeletionController controller = _controller(repository);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, isA<AccountDeletionReady>());
    expect(repository.statusRequestIds.single, pending.id);
  });

  test(
    'recent-authenticated request acknowledges subscription and requests logout',
    () async {
      final AccountDeletionRequest accepted = accountDeletionRequestFixture(
        activeSubscriptionAtRequest: true,
      );
      final FakeAccountDeletionRepository repository =
          FakeAccountDeletionRepository(
            preflightResult: AccountDeletionSucceeded<AccountDeletionPreflight>(
              accountDeletionPreflightFixture(hasActiveSubscription: true),
            ),
            requestResults: <AccountDeletionResult<AccountDeletionRequest>>[
              AccountDeletionSucceeded<AccountDeletionRequest>(accepted),
            ],
          );
      final FakeRecentAuthenticationService recent =
          FakeRecentAuthenticationService();
      final FakeAccountDeletionCommandIdGenerator generator =
          FakeAccountDeletionCommandIdGenerator();
      final AccountDeletionController controller = AccountDeletionController(
        repository,
        generator,
        recent,
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.requestDeletion(subscriptionAcknowledged: true);

      final AccountDeletionReady state =
          controller.state as AccountDeletionReady;
      expect(repository.requestCalls, hasLength(1));
      expect(repository.requestCalls.single.subscriptionAcknowledged, isTrue);
      expect(
        repository.requestCalls.single.recentAuthenticationProof.toString(),
        contains('redacted'),
      );
      expect(recent.authenticateCount, 1);
      expect(generator.generateCount, 1);
      expect(state.logoutRequested, isTrue);
      expect(state.latestRequest?.id, accepted.id);

      controller.acknowledgeLogoutRequest();
      expect(
        (controller.state as AccountDeletionReady).logoutRequested,
        isFalse,
      );
    },
  );

  test('cancelled recent authentication sends no deletion request', () async {
    final FakeAccountDeletionRepository repository =
        FakeAccountDeletionRepository();
    final AccountDeletionController controller = AccountDeletionController(
      repository,
      FakeAccountDeletionCommandIdGenerator(),
      FakeRecentAuthenticationService(
        results: const <RecentAuthenticationResult>[
          RecentAuthenticationFailed(RecentAuthenticationFailureKind.cancelled),
        ],
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.requestDeletion(subscriptionAcknowledged: false);

    expect(repository.requestCalls, isEmpty);
    expect(
      (controller.state as AccountDeletionReady).failure?.kind,
      AccountDeletionFailureKind.recentAuthenticationCancelled,
    );
  });

  test('cancels a queued request with expected version', () async {
    final AccountDeletionRequest pending = accountDeletionRequestFixture();
    final FakeAccountDeletionRepository repository =
        FakeAccountDeletionRepository(
          preflightResult: AccountDeletionSucceeded<AccountDeletionPreflight>(
            accountDeletionPreflightFixture(pendingRequest: pending),
          ),
          latestResult: AccountDeletionSucceeded<AccountDeletionRequest?>(
            pending,
          ),
        );
    final AccountDeletionController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.cancel();

    expect(repository.cancelCalls.single.requestId, pending.id);
    expect(repository.cancelCalls.single.expectedVersion, pending.version);
    final AccountDeletionReady state = controller.state as AccountDeletionReady;
    expect(state.latestRequest?.status, AccountDeletionRequestStatus.cancelled);
    expect(state.preflight.canRequest, isTrue);
  });

  test('retry reuses the same idempotency command ID', () async {
    final FakeAccountDeletionRepository repository =
        FakeAccountDeletionRepository(
          requestResults: <AccountDeletionResult<AccountDeletionRequest>>[
            const AccountDeletionFailed<AccountDeletionRequest>(
              AccountDeletionFailure(
                AccountDeletionFailureKind.temporarilyUnavailable,
              ),
            ),
            AccountDeletionSucceeded<AccountDeletionRequest>(
              accountDeletionRequestFixture(),
            ),
          ],
        );
    final FakeAccountDeletionCommandIdGenerator generator =
        FakeAccountDeletionCommandIdGenerator();
    final AccountDeletionController controller = AccountDeletionController(
      repository,
      generator,
      FakeRecentAuthenticationService(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.requestDeletion(subscriptionAcknowledged: false);
    await controller.requestDeletion(subscriptionAcknowledged: false);

    expect(repository.requestCalls, hasLength(2));
    expect(
      repository.requestCalls.first.commandId,
      repository.requestCalls.last.commandId,
    );
    expect(generator.generateCount, 1);
  });
}

AccountDeletionController _controller(
  FakeAccountDeletionRepository repository,
) {
  return AccountDeletionController(
    repository,
    FakeAccountDeletionCommandIdGenerator(),
    FakeRecentAuthenticationService(),
  );
}
