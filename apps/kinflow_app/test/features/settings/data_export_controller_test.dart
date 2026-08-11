import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/application/data_export_controller.dart';
import 'package:kinflow_app/features/settings/application/data_export_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';

import '../../support/fakes/fake_data_export_dependencies.dart';
import '../../support/fakes/fake_household_member_dependencies.dart';

void main() {
  test('loads preflight then resolves its pending request by ID', () async {
    final DataExportRequest pending = dataExportRequestFixture();
    final FakeDataExportRepository repository = FakeDataExportRepository(
      preflightResult: DataExportSucceeded<DataExportPreflight>(
        dataExportPreflightFixture(pendingRequest: pending),
      ),
      latestResult: DataExportSucceeded<DataExportRequest?>(pending),
    );
    final DataExportController controller = _controller(repository);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, isA<DataExportReady>());
    expect(repository.statusRequestIds.single, pending.id);
  });

  test('recent-authenticated request queues an export', () async {
    final DataExportRequest accepted = dataExportRequestFixture();
    final FakeDataExportRepository repository = FakeDataExportRepository(
      requestResults: <DataExportResult<DataExportRequest>>[
        DataExportSucceeded<DataExportRequest>(accepted),
      ],
    );
    final FakeRecentAuthenticationService recent =
        FakeRecentAuthenticationService();
    final FakeDataExportCommandIdGenerator generator =
        FakeDataExportCommandIdGenerator();
    final DataExportController controller = DataExportController(
      repository,
      generator,
      recent,
      FakeDataExportDownloadLauncher(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.requestExport();

    final DataExportReady state = controller.state as DataExportReady;
    expect(repository.requestCalls, hasLength(1));
    expect(
      repository.requestCalls.single.recentAuthenticationProof.toString(),
      contains('redacted'),
    );
    expect(recent.authenticateCount, 1);
    expect(generator.generateCount, 1);
    expect(state.latestRequest?.id, accepted.id);
    expect(state.preflight.hasPendingRequest, isTrue);
  });

  test('cancelled recent authentication sends no export request', () async {
    final FakeDataExportRepository repository = FakeDataExportRepository();
    final DataExportController controller = DataExportController(
      repository,
      FakeDataExportCommandIdGenerator(),
      FakeRecentAuthenticationService(
        results: const <RecentAuthenticationResult>[
          RecentAuthenticationFailed(RecentAuthenticationFailureKind.cancelled),
        ],
      ),
      FakeDataExportDownloadLauncher(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.requestExport();

    expect(repository.requestCalls, isEmpty);
    expect(
      (controller.state as DataExportReady).failure?.kind,
      DataExportFailureKind.recentAuthenticationCancelled,
    );
  });

  test('cancels a queued request with expected version', () async {
    final DataExportRequest pending = dataExportRequestFixture();
    final FakeDataExportRepository repository = FakeDataExportRepository(
      preflightResult: DataExportSucceeded<DataExportPreflight>(
        dataExportPreflightFixture(pendingRequest: pending),
      ),
      latestResult: DataExportSucceeded<DataExportRequest?>(pending),
    );
    final DataExportController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.cancel();

    expect(repository.cancelCalls.single.requestId, pending.id);
    expect(repository.cancelCalls.single.expectedVersion, pending.version);
    final DataExportReady state = controller.state as DataExportReady;
    expect(state.latestRequest?.status, DataExportRequestStatus.cancelled);
    expect(state.preflight.canRequest, isTrue);
  });

  test(
    'opens a one-time download without retaining its URL in state',
    () async {
      final DataExportRequest completed = dataExportRequestFixture(
        status: DataExportRequestStatus.completed,
        version: 3,
        artifactAvailable: true,
      );
      final FakeDataExportRepository repository = FakeDataExportRepository(
        latestResult: DataExportSucceeded<DataExportRequest?>(completed),
      );
      final FakeDataExportDownloadLauncher launcher =
          FakeDataExportDownloadLauncher();
      final DataExportController controller = DataExportController(
        repository,
        FakeDataExportCommandIdGenerator(),
        FakeRecentAuthenticationService(),
        launcher,
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.download(DataExportFormat.json);

      expect(repository.downloadCalls.single.requestId, completed.id);
      expect(repository.downloadCalls.single.format, DataExportFormat.json);
      expect(launcher.launchedUris.single.queryParameters['token'], isNotEmpty);
      final DataExportReady state = controller.state as DataExportReady;
      expect(state.lastOpenedFormat, DataExportFormat.json);
      expect(state.toString(), isNot(contains(dataExportDownloadToken)));
    },
  );

  test(
    'download launch failure is surfaced without a success marker',
    () async {
      final DataExportRequest completed = dataExportRequestFixture(
        status: DataExportRequestStatus.completed,
        artifactAvailable: true,
      );
      final FakeDataExportRepository repository = FakeDataExportRepository(
        latestResult: DataExportSucceeded<DataExportRequest?>(completed),
      );
      final DataExportController controller = DataExportController(
        repository,
        FakeDataExportCommandIdGenerator(),
        FakeRecentAuthenticationService(),
        FakeDataExportDownloadLauncher(results: <bool>[false]),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.download(DataExportFormat.json);

      final DataExportReady state = controller.state as DataExportReady;
      expect(state.lastOpenedFormat, isNull);
      expect(state.failure?.kind, DataExportFailureKind.launchFailed);
    },
  );

  test('revokes a completed artifact using its expected version', () async {
    final DataExportRequest completed = dataExportRequestFixture(
      status: DataExportRequestStatus.completed,
      version: 3,
      artifactAvailable: true,
    );
    final FakeDataExportRepository repository = FakeDataExportRepository(
      latestResult: DataExportSucceeded<DataExportRequest?>(completed),
    );
    final DataExportController controller = _controller(repository);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.revoke();

    expect(repository.revokeCalls.single.requestId, completed.id);
    expect(
      repository.revokeCalls.single.expectedArtifactVersion,
      completed.artifact.version,
    );
    final DataExportReady state = controller.state as DataExportReady;
    expect(state.latestRequest?.artifact.revokedAt, isNotNull);
    expect(state.latestRequest?.artifact.available, isFalse);
  });

  test('retry reuses the same request idempotency command ID', () async {
    final FakeDataExportRepository repository = FakeDataExportRepository(
      requestResults: <DataExportResult<DataExportRequest>>[
        const DataExportFailed<DataExportRequest>(
          DataExportFailure(DataExportFailureKind.temporarilyUnavailable),
        ),
        DataExportSucceeded<DataExportRequest>(dataExportRequestFixture()),
      ],
    );
    final FakeDataExportCommandIdGenerator generator =
        FakeDataExportCommandIdGenerator();
    final DataExportController controller = DataExportController(
      repository,
      generator,
      FakeRecentAuthenticationService(),
      FakeDataExportDownloadLauncher(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.requestExport();
    await controller.requestExport();

    expect(repository.requestCalls, hasLength(2));
    expect(
      repository.requestCalls.first.commandId,
      repository.requestCalls.last.commandId,
    );
    expect(generator.generateCount, 1);
  });
}

DataExportController _controller(FakeDataExportRepository repository) {
  return DataExportController(
    repository,
    FakeDataExportCommandIdGenerator(),
    FakeRecentAuthenticationService(),
    FakeDataExportDownloadLauncher(),
  );
}
