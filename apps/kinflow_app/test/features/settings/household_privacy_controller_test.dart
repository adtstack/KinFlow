import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/application/household_privacy_controller.dart';
import 'package:kinflow_app/features/settings/application/household_privacy_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';

import '../../support/fakes/fake_data_export_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';
import '../../support/fakes/fake_household_privacy_dependencies.dart';

void main() {
  test('loads Owner preflight for the active household', () async {
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository();
    final HouseholdPrivacyController controller = _controller(repository);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, isA<HouseholdPrivacyReady>());
    expect(
      repository.preflightHouseholdIds.single.value,
      householdPrivacyHouseholdUuid,
    );
  });

  test('recent-authenticated request queues a household export', () async {
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository();
    final FakeRecentAuthenticationService recent =
        FakeRecentAuthenticationService();
    final FakeHouseholdCommandIdGenerator generator =
        FakeHouseholdCommandIdGenerator();
    final HouseholdPrivacyController controller = HouseholdPrivacyController(
      repository,
      generator,
      recent,
      FakeDataExportDownloadLauncher(),
      householdPrivacyHouseholdFixture().id,
      () async {},
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.requestExport();

    final HouseholdPrivacyReady state =
        controller.state as HouseholdPrivacyReady;
    expect(repository.exportCalls, hasLength(1));
    expect(recent.authenticateCount, 1);
    expect(generator.generateCount, 1);
    expect(state.latestRequest?.kind, HouseholdPrivacyRequestKind.export);
    expect(state.preflight.pendingRequest, isNotNull);
  });

  test('cancelled recent authentication sends no export request', () async {
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository();
    final HouseholdPrivacyController controller = HouseholdPrivacyController(
      repository,
      FakeHouseholdCommandIdGenerator(),
      FakeRecentAuthenticationService(
        results: const <RecentAuthenticationResult>[
          RecentAuthenticationFailed(RecentAuthenticationFailureKind.cancelled),
        ],
      ),
      FakeDataExportDownloadLauncher(),
      householdPrivacyHouseholdFixture().id,
      () async {},
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.requestExport();

    expect(repository.exportCalls, isEmpty);
    expect(
      (controller.state as HouseholdPrivacyReady).failure?.kind,
      HouseholdPrivacyFailureKind.recentAuthenticationCancelled,
    );
  });

  test(
    'deletion validates exact name and all active-subscription impacts',
    () async {
      final FakeHouseholdPrivacyRepository repository =
          FakeHouseholdPrivacyRepository(
            preflightResult:
                HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>(
                  householdPrivacyPreflightFixture(activeSubscription: true),
                ),
          );
      final FakeRecentAuthenticationService recent =
          FakeRecentAuthenticationService();
      final HouseholdPrivacyController controller = HouseholdPrivacyController(
        repository,
        FakeHouseholdCommandIdGenerator(),
        recent,
        FakeDataExportDownloadLauncher(),
        householdPrivacyHouseholdFixture().id,
        () async {},
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.requestDeletion(
        confirmationName: 'Wrong family',
        acknowledgeMemberAccessLoss: true,
        acknowledgeSharedDataRedaction: true,
        acknowledgeSubscriptionNotCancelled: true,
      );
      expect(repository.deletionCalls, isEmpty);
      expect(recent.authenticateCount, 0);
      expect(
        (controller.state as HouseholdPrivacyReady).failure?.kind,
        HouseholdPrivacyFailureKind.confirmationMismatch,
      );

      await controller.requestDeletion(
        confirmationName: 'Kim family',
        acknowledgeMemberAccessLoss: true,
        acknowledgeSharedDataRedaction: true,
        acknowledgeSubscriptionNotCancelled: false,
      );
      expect(repository.deletionCalls, isEmpty);
      expect(
        (controller.state as HouseholdPrivacyReady).failure?.kind,
        HouseholdPrivacyFailureKind.subscriptionAcknowledgmentRequired,
      );

      await controller.requestDeletion(
        confirmationName: 'Kim family',
        acknowledgeMemberAccessLoss: true,
        acknowledgeSharedDataRedaction: true,
        acknowledgeSubscriptionNotCancelled: true,
      );
      expect(repository.deletionCalls, hasLength(1));
      expect(repository.deletionCalls.single.expectedHouseholdVersion, 4);
      expect(
        repository.deletionCalls.single.acknowledgeSubscriptionNotCancelled,
        isTrue,
      );
      expect(recent.authenticateCount, 1);
    },
  );

  test('cancels a queued deletion with kind and expected version', () async {
    final HouseholdPrivacyRequest pending = householdPrivacyRequestFixture(
      kind: HouseholdPrivacyRequestKind.deletion,
    );
    final HouseholdPrivacyRequest cancelled = householdPrivacyRequestFixture(
      kind: HouseholdPrivacyRequestKind.deletion,
      status: HouseholdPrivacyRequestStatus.cancelled,
      version: 2,
    );
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository(
          preflightResult: HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>(
            householdPrivacyPreflightFixture(pendingRequest: pending),
          ),
          cancelResults: <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
            HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(cancelled),
          ],
        );
    final HouseholdPrivacyController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.cancel();

    expect(
      repository.cancelCalls.single.kind,
      HouseholdPrivacyRequestKind.deletion,
    );
    expect(repository.cancelCalls.single.expectedVersion, pending.version);
    final HouseholdPrivacyReady state =
        controller.state as HouseholdPrivacyReady;
    expect(
      state.latestRequest?.status,
      HouseholdPrivacyRequestStatus.cancelled,
    );
    expect(state.preflight.canExport, isTrue);
    expect(state.preflight.canDelete, isTrue);
  });

  test('opens one-time household download without retaining its URL', () async {
    final HouseholdPrivacyRequest completed = householdPrivacyRequestFixture(
      status: HouseholdPrivacyRequestStatus.completed,
      artifactAvailable: true,
      version: 3,
    );
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository(
          exportResults: <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
            HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(completed),
          ],
        );
    final FakeDataExportDownloadLauncher launcher =
        FakeDataExportDownloadLauncher();
    final HouseholdPrivacyController controller = HouseholdPrivacyController(
      repository,
      FakeHouseholdCommandIdGenerator(),
      FakeRecentAuthenticationService(),
      launcher,
      householdPrivacyHouseholdFixture().id,
      () async {},
    );
    addTearDown(controller.dispose);
    await controller.load();
    await controller.requestExport();

    await controller.download(HouseholdExportFormat.json);

    expect(repository.downloadCalls.single.requestId, completed.id);
    expect(launcher.launchedUris, hasLength(1));
    final HouseholdPrivacyReady state =
        controller.state as HouseholdPrivacyReady;
    expect(state.lastOpenedFormat, HouseholdExportFormat.json);
    expect(state.toString(), isNot(contains(householdPrivacyDownloadToken)));
  });

  test('completed deletion refreshes active household resolution', () async {
    final HouseholdPrivacyRequest pending = householdPrivacyRequestFixture(
      kind: HouseholdPrivacyRequestKind.deletion,
    );
    final HouseholdPrivacyRequest completed = householdPrivacyRequestFixture(
      kind: HouseholdPrivacyRequestKind.deletion,
      status: HouseholdPrivacyRequestStatus.completed,
      version: 4,
    );
    final FakeHouseholdPrivacyRepository repository =
        FakeHouseholdPrivacyRepository(
          preflightResult: HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>(
            householdPrivacyPreflightFixture(pendingRequest: pending),
          ),
          statusResults: <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
            HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(completed),
          ],
        );
    var refreshCount = 0;
    final HouseholdPrivacyController controller = HouseholdPrivacyController(
      repository,
      FakeHouseholdCommandIdGenerator(),
      FakeRecentAuthenticationService(),
      FakeDataExportDownloadLauncher(),
      householdPrivacyHouseholdFixture().id,
      () async => refreshCount += 1,
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.load(preserveContent: true);

    expect(repository.statusRequestIds.single, pending.id);
    expect(refreshCount, 1);
    expect(
      (controller.state as HouseholdPrivacyReady).latestRequest?.status,
      HouseholdPrivacyRequestStatus.completed,
    );
  });

  test(
    'retry reuses the same idempotency key for an unchanged action',
    () async {
      final FakeHouseholdPrivacyRepository repository =
          FakeHouseholdPrivacyRepository(
            exportResults: <HouseholdPrivacyResult<HouseholdPrivacyRequest>>[
              const HouseholdPrivacyFailed<HouseholdPrivacyRequest>(
                HouseholdPrivacyFailure(
                  HouseholdPrivacyFailureKind.temporarilyUnavailable,
                ),
              ),
              HouseholdPrivacySucceeded<HouseholdPrivacyRequest>(
                householdPrivacyRequestFixture(),
              ),
            ],
          );
      final FakeHouseholdCommandIdGenerator generator =
          FakeHouseholdCommandIdGenerator();
      final HouseholdPrivacyController controller = HouseholdPrivacyController(
        repository,
        generator,
        FakeRecentAuthenticationService(),
        FakeDataExportDownloadLauncher(),
        householdPrivacyHouseholdFixture().id,
        () async {},
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.requestExport();
      await controller.requestExport();

      expect(repository.exportCalls, hasLength(2));
      expect(
        repository.exportCalls.first.commandId,
        repository.exportCalls.last.commandId,
      );
      expect(generator.generateCount, 1);
    },
  );
}

HouseholdPrivacyController _controller(
  FakeHouseholdPrivacyRepository repository,
) {
  return HouseholdPrivacyController(
    repository,
    FakeHouseholdCommandIdGenerator(),
    FakeRecentAuthenticationService(),
    FakeDataExportDownloadLauncher(),
    householdPrivacyHouseholdFixture().id,
    () async {},
  );
}
