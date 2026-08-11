import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/today_chores_controller.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_chore_sync_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test(
    'connected and newer generations replace the current first page',
    () async {
      var loadCount = 0;
      final FakeChoreRepository choreRepository = FakeChoreRepository(
        listCallback: (ChoreListRequest request) async {
          loadCount += 1;
          return TodayChoresLoaded(_loadedFor(request, loadCount));
        },
      );
      final FakeChoreSyncRepository syncRepository = FakeChoreSyncRepository();
      final TodayChoresController controller = TodayChoresController(
        repository: choreRepository,
        idGenerator: FakeChoreCommandIdGenerator(),
        syncRepository: syncRepository,
      );
      addTearDown(() async {
        await controller.dispose();
        await syncRepository.dispose();
      });
      final HouseholdId householdId = activeHouseholdFixture().householdId;

      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: householdId,
          view: ChoreListView.upcoming,
        )!,
      );
      expect(syncRepository.watchCount, 1);
      expect(
        (controller.state as TodayChoresReady).syncStatus,
        ChoreSyncConnectionStatus.connecting,
      );

      syncRepository.latest.add(const ChoreSyncConnected());
      await _flush();
      expect(choreRepository.listRequests, hasLength(2));
      expect(
        (controller.state as TodayChoresReady).today.occurrences.single.title,
        'Remote revision 2',
      );
      expect(
        (controller.state as TodayChoresReady).syncStatus,
        ChoreSyncConnectionStatus.live,
      );

      syncRepository.latest
        ..add(const ChoreSyncChanged(5))
        ..add(const ChoreSyncChanged(5))
        ..add(const ChoreSyncChanged(4));
      await _flush();
      expect(choreRepository.listRequests, hasLength(3));
      expect(
        (controller.state as TodayChoresReady).today.occurrences.single.title,
        'Remote revision 3',
      );
    },
  );

  test('disconnect and transport failure retain the last Chore page', () async {
    var loadCount = 0;
    final FakeChoreRepository choreRepository = FakeChoreRepository(
      listCallback: (ChoreListRequest request) async {
        loadCount += 1;
        return loadCount == 1
            ? TodayChoresLoaded(_loadedFor(request, loadCount))
            : const LoadTodayChoresFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              );
      },
    );
    final FakeChoreSyncRepository syncRepository = FakeChoreSyncRepository();
    final TodayChoresController controller = TodayChoresController(
      repository: choreRepository,
      idGenerator: FakeChoreCommandIdGenerator(),
      syncRepository: syncRepository,
    );
    addTearDown(() async {
      await controller.dispose();
      await syncRepository.dispose();
    });

    await controller.loadQuery(
      ChoreListRequest.tryCreate(
        householdId: activeHouseholdFixture().householdId,
        view: ChoreListView.upcoming,
      )!,
    );
    syncRepository.latest.add(const ChoreSyncConnected());
    await _flush();

    final TodayChoresReady stale = controller.state as TodayChoresReady;
    expect(stale.today.occurrences.single.title, 'Remote revision 1');
    expect(stale.refreshFailure?.kind, ChoreFailureKind.temporarilyUnavailable);
    syncRepository.latest.add(const ChoreSyncDisconnected());
    final TodayChoresReady disconnected = controller.state as TodayChoresReady;
    expect(disconnected.syncStatus, ChoreSyncConnectionStatus.disconnected);
    expect(disconnected.today.occurrences.single.title, 'Remote revision 1');
  });

  test(
    'authorization failure discards retained content and stops the channel',
    () async {
      var loadCount = 0;
      final FakeChoreRepository choreRepository = FakeChoreRepository(
        listCallback: (ChoreListRequest request) async {
          loadCount += 1;
          return loadCount == 1
              ? TodayChoresLoaded(_loadedFor(request, loadCount))
              : const LoadTodayChoresFailed(
                  ChoreFailure(ChoreFailureKind.notFoundOrForbidden),
                );
        },
      );
      final FakeChoreSyncRepository syncRepository = FakeChoreSyncRepository();
      final TodayChoresController controller = TodayChoresController(
        repository: choreRepository,
        idGenerator: FakeChoreCommandIdGenerator(),
        syncRepository: syncRepository,
      );
      addTearDown(() async {
        await controller.dispose();
        await syncRepository.dispose();
      });

      await controller.loadQuery(
        ChoreListRequest.tryCreate(
          householdId: activeHouseholdFixture().householdId,
        )!,
      );
      syncRepository.latest.add(const ChoreSyncChanged(1));
      await _flush();

      final TodayChoresLoadFailed failed =
          controller.state as TodayChoresLoadFailed;
      expect(failed.failure.kind, ChoreFailureKind.notFoundOrForbidden);
      expect(syncRepository.hasListenerAt(0), isFalse);
    },
  );

  test(
    'household switch removes the old channel before exposing new content',
    () async {
      final FakeChoreRepository choreRepository = FakeChoreRepository(
        listCallback: (ChoreListRequest request) async =>
            TodayChoresLoaded(_loadedFor(request, 1)),
      );
      final FakeChoreSyncRepository syncRepository = FakeChoreSyncRepository();
      final TodayChoresController controller = TodayChoresController(
        repository: choreRepository,
        idGenerator: FakeChoreCommandIdGenerator(),
        syncRepository: syncRepository,
      );
      addTearDown(() async {
        await controller.dispose();
        await syncRepository.dispose();
      });
      final HouseholdId first = activeHouseholdFixture().householdId;
      final HouseholdId second = activeHouseholdFixture(
        householdId: '22222222-2222-4222-8222-222222222223',
      ).householdId;

      await controller.loadQuery(
        ChoreListRequest.tryCreate(householdId: first)!,
      );
      final Future<void> switching = controller.loadQuery(
        ChoreListRequest.tryCreate(householdId: second)!,
      );
      expect(controller.state, isA<TodayChoresLoading>());
      await switching;

      expect(syncRepository.hasListenerAt(0), isFalse);
      expect(syncRepository.watchedHouseholds, <Object>[first, second]);
      expect((controller.state as TodayChoresReady).today.householdId, second);
      syncRepository.addAt(0, const ChoreSyncChanged(100));
      await _flush();
      expect(choreRepository.listRequests, hasLength(2));
    },
  );
}

TodayChores _loadedFor(ChoreListRequest request, int revision) {
  return TodayChores(
    householdId: request.householdId,
    householdTimezone: 'Asia/Seoul',
    localDate: ChoreLocalDate.tryParse('2026-08-10')!,
    occurrences: <ChoreOccurrence>[
      choreOccurrenceFixture(
        occurrenceId:
            '55555555-5555-4555-8555-${revision.toString().padLeft(12, '0')}',
        title: 'Remote revision $revision',
        dueLocalDate: ChoreLocalDate.tryParse('2026-08-11')!,
      ),
    ],
    view: request.view,
    assigneeFilterMemberId: request.assigneeMemberId,
    generatedAt: DateTime.utc(2026, 8, 10, 1, revision),
    pageLimit: request.limit,
    hasMore: false,
  );
}

Future<void> _flush() async {
  for (var index = 0; index < 5; index += 1) {
    await Future<void>.delayed(Duration.zero);
  }
}
