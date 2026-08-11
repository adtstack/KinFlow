import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/chore_occurrence_history_controller.dart';
import 'package:kinflow_app/features/chores/application/chore_occurrence_history_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';

void main() {
  test('coalesces initial history load and emits a ready page', () async {
    final Completer<LoadChoreOccurrenceHistoryResult> response =
        Completer<LoadChoreOccurrenceHistoryResult>();
    final FakeChoreRepository repository = FakeChoreRepository(
      historyCallback: (_) => response.future,
    );
    final ChoreOccurrenceHistoryController controller =
        ChoreOccurrenceHistoryController(repository: repository);

    final Future<void> first = controller.load(
      householdId: _householdId,
      occurrenceId: _occurrenceId,
    );
    final Future<void> duplicate = controller.load(
      householdId: _householdId,
      occurrenceId: _occurrenceId,
    );

    expect(identical(first, duplicate), isTrue);
    expect(repository.historyRequests, hasLength(1));
    expect(controller.state, isA<ChoreOccurrenceHistoryLoading>());

    response.complete(
      ChoreOccurrenceHistoryLoaded(
        _page(events: <ChoreOccurrenceHistoryEvent>[_event('702', hour: 2)]),
      ),
    );
    await first;

    final ChoreOccurrenceHistoryReady ready =
        controller.state as ChoreOccurrenceHistoryReady;
    expect(ready.events.single.id.value, contains('702'));
    expect(ready.hasMore, isFalse);
    await controller.dispose();
  });

  test(
    'retries an initial typed failure without changing the target',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository(
        historyResults: <LoadChoreOccurrenceHistoryResult>[
          const LoadChoreOccurrenceHistoryFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
          ChoreOccurrenceHistoryLoaded(_page()),
        ],
      );
      final ChoreOccurrenceHistoryController controller =
          ChoreOccurrenceHistoryController(repository: repository);

      await controller.load(
        householdId: _householdId,
        occurrenceId: _occurrenceId,
      );
      expect(controller.state, isA<ChoreOccurrenceHistoryLoadFailed>());

      await controller.retry();

      expect(controller.state, isA<ChoreOccurrenceHistoryReady>());
      expect(repository.historyRequests, hasLength(2));
      expect(repository.historyRequests.last.householdId, _householdId);
      expect(repository.historyRequests.last.cursor, isNull);
      await controller.dispose();
    },
  );

  test('coalesces load-more and advances with the last event cursor', () async {
    final Completer<LoadChoreOccurrenceHistoryResult> nextResponse =
        Completer<LoadChoreOccurrenceHistoryResult>();
    var calls = 0;
    final FakeChoreRepository repository = FakeChoreRepository(
      historyCallback: (_) {
        calls += 1;
        return calls == 1
            ? Future<LoadChoreOccurrenceHistoryResult>.value(
                ChoreOccurrenceHistoryLoaded(
                  _page(
                    events: <ChoreOccurrenceHistoryEvent>[
                      _event('702', hour: 2),
                    ],
                    hasMore: true,
                  ),
                ),
              )
            : nextResponse.future;
      },
    );
    final ChoreOccurrenceHistoryController controller =
        ChoreOccurrenceHistoryController(repository: repository);
    await controller.load(
      householdId: _householdId,
      occurrenceId: _occurrenceId,
      limit: 1,
    );

    final Future<void> first = controller.loadMore();
    final Future<void> duplicate = controller.loadMore();

    expect(identical(first, duplicate), isTrue);
    expect(repository.historyRequests, hasLength(2));
    expect(
      repository.historyRequests.last.cursor?.entryId.value,
      contains('702'),
    );
    expect(
      (controller.state as ChoreOccurrenceHistoryReady).loadingMore,
      isTrue,
    );

    nextResponse.complete(
      ChoreOccurrenceHistoryLoaded(
        _page(events: <ChoreOccurrenceHistoryEvent>[_event('701', hour: 1)]),
      ),
    );
    await first;

    final ChoreOccurrenceHistoryReady ready =
        controller.state as ChoreOccurrenceHistoryReady;
    expect(ready.events.map((event) => event.id.value), <String>[
      'completion:61000000-0000-4000-8000-000000000702',
      'completion:61000000-0000-4000-8000-000000000701',
    ]);
    expect(ready.hasMore, isFalse);
    await controller.dispose();
  });

  test('preserves loaded history while retrying a page failure', () async {
    final FakeChoreRepository repository = FakeChoreRepository(
      historyResults: <LoadChoreOccurrenceHistoryResult>[
        ChoreOccurrenceHistoryLoaded(
          _page(
            events: <ChoreOccurrenceHistoryEvent>[_event('702', hour: 2)],
            hasMore: true,
          ),
        ),
        const LoadChoreOccurrenceHistoryFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        ChoreOccurrenceHistoryLoaded(
          _page(events: <ChoreOccurrenceHistoryEvent>[_event('701', hour: 1)]),
        ),
      ],
    );
    final ChoreOccurrenceHistoryController controller =
        ChoreOccurrenceHistoryController(repository: repository);
    await controller.load(
      householdId: _householdId,
      occurrenceId: _occurrenceId,
      limit: 1,
    );

    await controller.loadMore();

    ChoreOccurrenceHistoryReady ready =
        controller.state as ChoreOccurrenceHistoryReady;
    expect(ready.events, hasLength(1));
    expect(
      ready.loadMoreFailure?.kind,
      ChoreFailureKind.temporarilyUnavailable,
    );

    await controller.retry();

    ready = controller.state as ChoreOccurrenceHistoryReady;
    expect(ready.events, hasLength(2));
    expect(ready.loadMoreFailure, isNull);
    expect(repository.historyRequests, hasLength(3));
    await controller.dispose();
  });

  test(
    'fails a duplicate continuation without losing existing history',
    () async {
      final ChoreOccurrenceHistoryEvent event = _event('701', hour: 1);
      final FakeChoreRepository repository = FakeChoreRepository(
        historyResults: <LoadChoreOccurrenceHistoryResult>[
          ChoreOccurrenceHistoryLoaded(
            _page(events: <ChoreOccurrenceHistoryEvent>[event], hasMore: true),
          ),
          ChoreOccurrenceHistoryLoaded(
            _page(events: <ChoreOccurrenceHistoryEvent>[event]),
          ),
        ],
      );
      final ChoreOccurrenceHistoryController controller =
          ChoreOccurrenceHistoryController(repository: repository);
      await controller.load(
        householdId: _householdId,
        occurrenceId: _occurrenceId,
      );

      await controller.loadMore();

      final ChoreOccurrenceHistoryReady ready =
          controller.state as ChoreOccurrenceHistoryReady;
      expect(ready.events, hasLength(1));
      expect(ready.loadMoreFailure?.kind, ChoreFailureKind.invalidPayload);
      await controller.dispose();
    },
  );
}

final HouseholdId _householdId = HouseholdId.tryParse(
  '22222222-2222-4222-8222-222222222222',
)!;
final ChoreOccurrenceId _occurrenceId = ChoreOccurrenceId.tryParse(
  '55555555-5555-4555-8555-555555555555',
)!;

ChoreOccurrenceHistoryPage _page({
  List<ChoreOccurrenceHistoryEvent> events =
      const <ChoreOccurrenceHistoryEvent>[],
  bool hasMore = false,
}) {
  return ChoreOccurrenceHistoryPage.tryCreate(
    householdId: _householdId,
    occurrenceId: _occurrenceId,
    events: events,
    hasMore: hasMore,
  )!;
}

ChoreOccurrenceHistoryEvent _event(String suffix, {required int hour}) {
  return ChoreOccurrenceHistoryEvent.tryCreate(
    id: ChoreHistoryEntryId.tryParse(
      'completion:61000000-0000-4000-8000-000000000$suffix',
    )!,
    type: ChoreOccurrenceHistoryEventType.completed,
    actorMemberId: HouseholdMemberId.tryParse(
      '33333333-3333-4333-8333-333333333333',
    )!,
    actorDisplayName: 'Alex',
    actingMemberId: null,
    actingDisplayName: null,
    occurredAt: DateTime.utc(2026, 8, 7, hour),
    occurrenceVersion: hour,
    previousDueLocalDate: null,
    previousDueLocalTime: null,
    newDueLocalDate: null,
    newDueLocalTime: null,
    previousAssigneeMemberId: null,
    previousAssigneeDisplayName: null,
    newAssigneeMemberId: null,
    newAssigneeDisplayName: null,
  )!;
}
