import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/chore_sync_session.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';

import '../../support/fakes/fake_chore_sync_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test(
    'coalesces duplicate, out-of-order, and in-flight invalidations',
    () async {
      final FakeChoreSyncRepository repository = FakeChoreSyncRepository();
      final List<Completer<void>> refreshes = <Completer<void>>[];
      final List<ChoreSyncConnectionStatus> statuses =
          <ChoreSyncConnectionStatus>[];
      final ChoreSyncSession session = ChoreSyncSession(repository, () {
        final Completer<void> completer = Completer<void>();
        refreshes.add(completer);
        return completer.future;
      }, statuses.add);
      addTearDown(() async {
        for (final Completer<void> refresh in refreshes) {
          if (!refresh.isCompleted) {
            refresh.complete();
          }
        }
        await session.dispose();
        await repository.dispose();
      });

      await session.start(activeHouseholdFixture().householdId);
      repository.latest.add(const ChoreSyncConnected());
      await _flush();
      expect(refreshes, hasLength(1));
      expect(statuses.last, ChoreSyncConnectionStatus.live);

      repository.latest
        ..add(const ChoreSyncChanged(8))
        ..add(const ChoreSyncChanged(8))
        ..add(const ChoreSyncChanged(7));
      await _flush();
      expect(refreshes, hasLength(1));

      refreshes.first.complete();
      await _flush();
      expect(refreshes, hasLength(2));
      refreshes.last.complete();
      await _flush();
      expect(refreshes, hasLength(2));
    },
  );

  test('retains disconnected status and full-refetches on reconnect', () async {
    final FakeChoreSyncRepository repository = FakeChoreSyncRepository();
    final List<ChoreSyncConnectionStatus> statuses =
        <ChoreSyncConnectionStatus>[];
    var refreshCount = 0;
    final ChoreSyncSession session = ChoreSyncSession(
      repository,
      () async => refreshCount += 1,
      statuses.add,
    );
    addTearDown(() async {
      await session.dispose();
      await repository.dispose();
    });

    await session.start(activeHouseholdFixture().householdId);
    repository.latest.add(const ChoreSyncConnected());
    await _flush();
    expect(refreshCount, 1);

    repository.latest.add(const ChoreSyncDisconnected());
    expect(statuses.last, ChoreSyncConnectionStatus.disconnected);

    await session.reconnect();
    expect(repository.watchCount, 2);
    expect(statuses.last, ChoreSyncConnectionStatus.connecting);
    expect(refreshCount, 2);

    repository.latest.add(const ChoreSyncConnected());
    await _flush();
    expect(statuses.last, ChoreSyncConnectionStatus.live);
    expect(refreshCount, 3);
  });

  test(
    'stop cancels the old household and resets generation ordering',
    () async {
      final FakeChoreSyncRepository repository = FakeChoreSyncRepository();
      final List<ChoreSyncConnectionStatus> statuses =
          <ChoreSyncConnectionStatus>[];
      var refreshCount = 0;
      final ChoreSyncSession session = ChoreSyncSession(
        repository,
        () async => refreshCount += 1,
        statuses.add,
      );
      addTearDown(() async {
        await session.dispose();
        await repository.dispose();
      });
      final first = activeHouseholdFixture().householdId;
      final second = activeHouseholdFixture(
        householdId: '22222222-2222-4222-8222-222222222223',
      ).householdId;

      await session.start(first);
      repository.addAt(0, const ChoreSyncChanged(9));
      await _flush();
      expect(refreshCount, 1);

      await session.stop();
      expect(repository.hasListenerAt(0), isFalse);
      expect(statuses.last, ChoreSyncConnectionStatus.disabled);
      repository.addAt(0, const ChoreSyncChanged(10));
      await _flush();
      expect(refreshCount, 1);

      await session.start(second);
      repository.latest.add(const ChoreSyncChanged(1));
      await _flush();
      expect(refreshCount, 2);
      expect(repository.watchedHouseholds, <Object>[first, second]);
    },
  );

  test('disabled session still performs a resume refetch', () async {
    var refreshCount = 0;
    final ChoreSyncSession session = ChoreSyncSession(
      null,
      () async => refreshCount += 1,
      (_) {},
    );
    addTearDown(session.dispose);

    await session.start(activeHouseholdFixture().householdId);
    await session.resume();

    expect(refreshCount, 1);
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
