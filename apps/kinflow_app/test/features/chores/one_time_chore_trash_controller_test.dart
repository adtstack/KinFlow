import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_trash_controller.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_trash_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';

void main() {
  test('coalesces initial load and emits a strict ready page', () async {
    final Completer<LoadDeletedOneTimeChoresResult> response =
        Completer<LoadDeletedOneTimeChoresResult>();
    final FakeChoreRepository repository = FakeChoreRepository(
      deletedOneTimeChoresCallback: (_) => response.future,
    );
    final OneTimeChoreTrashController controller = OneTimeChoreTrashController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );

    final Future<void> first = controller.load(_request());
    final Future<void> duplicate = controller.load(_request());

    expect(identical(first, duplicate), isTrue);
    expect(repository.deletedOneTimeChoresRequests, hasLength(1));
    expect(controller.state, isA<OneTimeChoreTrashLoading>());

    response.complete(
      DeletedOneTimeChoresLoaded(_page(items: <DeletedOneTimeChore>[_item()])),
    );
    await first;

    final OneTimeChoreTrashReady ready =
        controller.state as OneTimeChoreTrashReady;
    expect(ready.items.single.title, 'Take out recycling');
    expect(ready.hasMore, isFalse);
    await controller.dispose();
  });

  test('loads a bounded continuation and preserves strict ordering', () async {
    final FakeChoreRepository repository = FakeChoreRepository(
      deletedOneTimeChoresResults: <LoadDeletedOneTimeChoresResult>[
        DeletedOneTimeChoresLoaded(
          _page(
            limit: 1,
            items: <DeletedOneTimeChore>[
              _item(deletedAt: DateTime.parse('2026-08-09T11:00:00Z')),
            ],
            hasMore: true,
            nextCursor: DeletedOneTimeChoreCursor.tryParse('7b7d'),
          ),
        ),
        DeletedOneTimeChoresLoaded(
          _page(
            limit: 1,
            items: <DeletedOneTimeChore>[
              _item(
                seriesId: '44444444-4444-4444-8444-444444444443',
                occurrenceId: '55555555-5555-4555-8555-555555555553',
                deletedAt: DateTime.parse('2026-08-09T10:00:00Z'),
              ),
            ],
          ),
        ),
      ],
    );
    final OneTimeChoreTrashController controller = OneTimeChoreTrashController(
      repository: repository,
      idGenerator: FakeChoreCommandIdGenerator(),
    );
    await controller.load(_request(limit: 1));

    await controller.loadMore();

    final OneTimeChoreTrashReady ready =
        controller.state as OneTimeChoreTrashReady;
    expect(ready.items, hasLength(2));
    expect(
      ready.items.first.deletedAt.isAfter(ready.items.last.deletedAt),
      true,
    );
    expect(ready.hasMore, isFalse);
    expect(repository.deletedOneTimeChoresRequests.last.cursor?.value, '7b7d');
    await controller.dispose();
  });

  test('restores, reloads authority, and emits the restored receipt', () async {
    final DeletedOneTimeChore item = _item();
    final FakeChoreRepository repository = FakeChoreRepository(
      deletedOneTimeChoresResults: <LoadDeletedOneTimeChoresResult>[
        DeletedOneTimeChoresLoaded(_page(items: <DeletedOneTimeChore>[item])),
        DeletedOneTimeChoresLoaded(_page()),
      ],
    );
    final FakeChoreCommandIdGenerator idGenerator =
        FakeChoreCommandIdGenerator();
    final OneTimeChoreTrashController controller = OneTimeChoreTrashController(
      repository: repository,
      idGenerator: idGenerator,
    );
    await controller.load(_request());

    await controller.restore(
      householdId: _householdId,
      occurrenceId: item.occurrenceId,
    );

    final OneTimeChoreTrashReady ready =
        controller.state as OneTimeChoreTrashReady;
    expect(ready.items, isEmpty);
    expect(ready.restoredOccurrenceId, item.occurrenceId);
    expect(repository.oneTimeRestoreRequests, hasLength(1));
    expect(repository.oneTimeRestoreRequests.single.expectedSeriesVersion, 2);
    expect(idGenerator.generateCount, 1);
    await controller.dispose();
  });

  test('reuses one restore key after a transient typed failure', () async {
    final DeletedOneTimeChore item = _item();
    final FakeChoreRepository repository = FakeChoreRepository(
      deletedOneTimeChoresResults: <LoadDeletedOneTimeChoresResult>[
        DeletedOneTimeChoresLoaded(_page(items: <DeletedOneTimeChore>[item])),
        DeletedOneTimeChoresLoaded(_page()),
      ],
      oneTimeRestoreResults: <RestoreOneTimeChoreResult>[
        const RestoreOneTimeChoreFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        OneTimeChoreRestored(
          OneTimeChoreRestoreSnapshot(
            householdId: _householdId,
            seriesId: item.seriesId,
            occurrenceId: item.occurrenceId,
            seriesVersion: 3,
            occurrenceVersion: 3,
            changed: true,
          ),
        ),
      ],
    );
    final FakeChoreCommandIdGenerator idGenerator =
        FakeChoreCommandIdGenerator();
    final OneTimeChoreTrashController controller = OneTimeChoreTrashController(
      repository: repository,
      idGenerator: idGenerator,
    );
    await controller.load(_request());

    await controller.restore(
      householdId: _householdId,
      occurrenceId: item.occurrenceId,
    );
    expect(
      (controller.state as OneTimeChoreTrashReady).actionFailure?.kind,
      ChoreFailureKind.temporarilyUnavailable,
    );
    await controller.restore(
      householdId: _householdId,
      occurrenceId: item.occurrenceId,
    );

    expect(repository.oneTimeRestoreRequests, hasLength(2));
    expect(
      repository.oneTimeRestoreRequests.first.idempotencyKey,
      repository.oneTimeRestoreRequests.last.idempotencyKey,
    );
    expect(idGenerator.generateCount, 1);
    expect(
      (controller.state as OneTimeChoreTrashReady).restoredOccurrenceId,
      item.occurrenceId,
    );
    await controller.dispose();
  });
}

DeletedOneTimeChoreListRequest _request({int limit = 30}) {
  return DeletedOneTimeChoreListRequest.tryCreate(
    householdId: _householdId,
    limit: limit,
  )!;
}

DeletedOneTimeChorePage _page({
  int limit = 30,
  List<DeletedOneTimeChore> items = const <DeletedOneTimeChore>[],
  bool hasMore = false,
  DeletedOneTimeChoreCursor? nextCursor,
}) {
  return DeletedOneTimeChorePage.tryCreate(
    householdId: _householdId,
    householdTimezone: 'Asia/Seoul',
    generatedAt: DateTime.parse('2026-08-09T10:30:00Z'),
    pageLimit: limit,
    hasMore: hasMore,
    nextCursor: nextCursor,
    items: items,
  )!;
}

DeletedOneTimeChore _item({
  String seriesId = '44444444-4444-4444-8444-444444444444',
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  DateTime? deletedAt,
}) {
  return DeletedOneTimeChore.tryCreate(
    householdId: _householdId,
    seriesId: ChoreSeriesId.tryParse(seriesId)!,
    occurrenceId: ChoreOccurrenceId.tryParse(occurrenceId)!,
    title: 'Take out recycling',
    description: 'Blue bin',
    assigneeMemberId: _memberId,
    assigneeDisplayName: 'Alex',
    dueLocalDate: ChoreLocalDate.tryParse('2026-08-09')!,
    dueLocalTime: ChoreLocalTime.tryParse('19:30'),
    dueAt: DateTime.parse('2026-08-09T10:30:00Z'),
    deletedAt: deletedAt ?? DateTime.parse('2026-08-09T10:00:00Z'),
    seriesVersion: 2,
    occurrenceVersion: 2,
  )!;
}

final HouseholdId _householdId = HouseholdId.tryParse(
  '22222222-2222-4222-8222-222222222222',
)!;
final HouseholdMemberId _memberId = HouseholdMemberId.tryParse(
  '33333333-3333-4333-8333-333333333333',
)!;
