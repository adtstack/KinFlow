import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_chore_sync_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test('keeps Today and overdue query/action state independent', () async {
    final ChoreOccurrence dueToday = choreOccurrenceFixture(
      occurrenceId: '55555555-5555-4555-8555-555555555581',
      seriesId: '44444444-4444-4444-8444-444444444481',
      title: 'Due today',
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-07')!,
    );
    final ChoreOccurrence overdue = choreOccurrenceFixture(
      occurrenceId: '55555555-5555-4555-8555-555555555582',
      seriesId: '44444444-4444-4444-8444-444444444482',
      title: 'Overdue',
      dueLocalDate: ChoreLocalDate.tryParse('2026-08-06')!,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      today: todayChoresFixture(
        localDate: '2026-08-07',
        occurrences: <ChoreOccurrence>[overdue, dueToday],
      ),
    );
    final ProviderContainer container = ProviderContainer(
      overrides: [
        choreRepositoryProvider.overrideWithValue(repository),
        choreCommandIdGeneratorProvider.overrideWithValue(
          FakeChoreCommandIdGenerator(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final primarySubscription = container.listen<TodayChoresState>(
      todayChoresProvider,
      (_, _) {},
      fireImmediately: true,
    );
    final overdueSubscription = container.listen<TodayChoresState>(
      todayOverdueChoresProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(primarySubscription.close);
    addTearDown(overdueSubscription.close);
    final householdId = activeHouseholdFixture().householdId;

    await Future.wait<void>(<Future<void>>[
      container
          .read(todayChoresProvider.notifier)
          .loadQuery(
            ChoreListRequest.tryCreate(
              householdId: householdId,
              view: ChoreListView.today,
            )!,
          ),
      container
          .read(todayOverdueChoresProvider.notifier)
          .loadQuery(
            ChoreListRequest.tryCreate(
              householdId: householdId,
              view: ChoreListView.overdue,
            )!,
          ),
    ]);

    final TodayChoresReady primary =
        container.read(todayChoresProvider) as TodayChoresReady;
    final TodayChoresReady overdueReady =
        container.read(todayOverdueChoresProvider) as TodayChoresReady;
    expect(primary.today.view, ChoreListView.today);
    expect(primary.today.occurrences.single.id, dueToday.id);
    expect(overdueReady.today.view, ChoreListView.overdue);
    expect(overdueReady.today.occurrences.single.id, overdue.id);

    await container
        .read(todayOverdueChoresProvider.notifier)
        .setCompleted(
          householdId: householdId,
          occurrenceId: overdue.id,
          completed: true,
        );

    expect(
      (container.read(todayOverdueChoresProvider) as TodayChoresReady)
          .today
          .occurrences,
      isEmpty,
    );
    expect(
      (container.read(todayChoresProvider) as TodayChoresReady)
          .today
          .occurrences
          .single
          .id,
      dueToday.id,
    );
    expect(
      repository.listRequests.map((ChoreListRequest request) => request.view),
      <ChoreListView>[ChoreListView.today, ChoreListView.overdue],
    );
    expect(repository.completionRequests.single.occurrenceId, overdue.id);
  });

  test(
    'bounds Today to independent primary and overdue sync channels',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository();
      final FakeChoreSyncRepository syncRepository = FakeChoreSyncRepository();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          choreRepositoryProvider.overrideWithValue(repository),
          choreSyncRepositoryProvider.overrideWithValue(syncRepository),
          choreCommandIdGeneratorProvider.overrideWithValue(
            FakeChoreCommandIdGenerator(),
          ),
        ],
      );
      final primarySubscription = container.listen<TodayChoresState>(
        todayChoresProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final overdueSubscription = container.listen<TodayChoresState>(
        todayOverdueChoresProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(() async {
        primarySubscription.close();
        overdueSubscription.close();
        container.dispose();
        await syncRepository.dispose();
      });
      final householdId = activeHouseholdFixture().householdId;

      await Future.wait<void>(<Future<void>>[
        container
            .read(todayChoresProvider.notifier)
            .loadQuery(ChoreListRequest.tryCreate(householdId: householdId)!),
        container
            .read(todayOverdueChoresProvider.notifier)
            .loadQuery(
              ChoreListRequest.tryCreate(
                householdId: householdId,
                view: ChoreListView.overdue,
              )!,
            ),
      ]);
      expect(syncRepository.watchCount, 2);

      syncRepository.addToAll(const ChoreSyncDisconnected());
      expect(
        (container.read(todayChoresProvider) as TodayChoresReady).syncStatus,
        ChoreSyncConnectionStatus.disconnected,
      );
      expect(
        (container.read(todayOverdueChoresProvider) as TodayChoresReady)
            .syncStatus,
        ChoreSyncConnectionStatus.disconnected,
      );

      await Future.wait<void>(<Future<void>>[
        container.read(todayChoresProvider.notifier).reconnect(),
        container.read(todayOverdueChoresProvider.notifier).reconnect(),
      ]);
      expect(syncRepository.watchCount, 4);
    },
  );
}
