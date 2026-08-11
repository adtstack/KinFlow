import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/chore_occurrence_target_controller.dart';
import 'package:kinflow_app/features/chores/application/chore_occurrence_target_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';

void main() {
  test(
    'coalesces an exact target load and emits authoritative detail',
    () async {
      final Completer<LoadChoreOccurrenceTargetResult> response =
          Completer<LoadChoreOccurrenceTargetResult>();
      final ChoreOccurrence occurrence = choreOccurrenceFixture();
      final FakeChoreRepository repository = FakeChoreRepository(
        occurrenceTargetCallback: (_, _) => response.future,
      );
      final ChoreOccurrenceTargetController controller =
          ChoreOccurrenceTargetController(
            repository: repository,
            idGenerator: FakeChoreCommandIdGenerator(),
          );

      final Future<void> first = controller.load(
        householdId: _householdId,
        occurrenceId: occurrence.id,
      );
      final Future<void> duplicate = controller.load(
        householdId: _householdId,
        occurrenceId: occurrence.id,
      );

      expect(identical(first, duplicate), isTrue);
      expect(repository.occurrenceTargetRequests, hasLength(1));
      expect(controller.state, isA<ChoreOccurrenceTargetLoading>());

      response.complete(ChoreOccurrenceTargetLoaded(occurrence));
      await first;

      final ChoreOccurrenceTargetReady ready =
          controller.state as ChoreOccurrenceTargetReady;
      expect(ready.householdId, _householdId);
      expect(ready.occurrence, same(occurrence));
      await controller.dispose();
    },
  );

  test('retries a typed target failure with the same authority pair', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        const LoadChoreOccurrenceTargetFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
        ChoreOccurrenceTargetLoaded(occurrence),
      ],
    );
    final ChoreOccurrenceTargetController controller =
        ChoreOccurrenceTargetController(
          repository: repository,
          idGenerator: FakeChoreCommandIdGenerator(),
        );

    await controller.load(
      householdId: _householdId,
      occurrenceId: occurrence.id,
    );
    expect(controller.state, isA<ChoreOccurrenceTargetLoadFailed>());

    await controller.retry();

    expect(controller.state, isA<ChoreOccurrenceTargetReady>());
    expect(repository.occurrenceTargetRequests, hasLength(2));
    expect(repository.occurrenceTargetRequests.last.householdId, _householdId);
    expect(
      repository.occurrenceTargetRequests.last.occurrenceId,
      occurrence.id,
    );
    await controller.dispose();
  });

  test('ignores a late response after the active household changes', () async {
    final HouseholdId otherHouseholdId = HouseholdId.tryParse(
      '22222222-2222-4222-8222-222222222223',
    )!;
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final Completer<LoadChoreOccurrenceTargetResult> first =
        Completer<LoadChoreOccurrenceTargetResult>();
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetCallback: (householdId, _) => householdId == _householdId
          ? first.future
          : Future<LoadChoreOccurrenceTargetResult>.value(
              ChoreOccurrenceTargetLoaded(occurrence),
            ),
    );
    final ChoreOccurrenceTargetController controller =
        ChoreOccurrenceTargetController(
          repository: repository,
          idGenerator: FakeChoreCommandIdGenerator(),
        );

    final Future<void> oldLoad = controller.load(
      householdId: _householdId,
      occurrenceId: occurrence.id,
    );
    await controller.load(
      householdId: otherHouseholdId,
      occurrenceId: occurrence.id,
    );
    first.complete(
      const LoadChoreOccurrenceTargetFailed(
        ChoreFailure(ChoreFailureKind.notFoundOrForbidden),
      ),
    );
    await oldLoad;

    final ChoreOccurrenceTargetReady ready =
        controller.state as ChoreOccurrenceTargetReady;
    expect(ready.householdId, otherHouseholdId);
    await controller.dispose();
  });

  test('normalizes an unexpected repository exception', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture();
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetCallback: (_, _) => throw StateError('provider detail'),
    );
    final ChoreOccurrenceTargetController controller =
        ChoreOccurrenceTargetController(
          repository: repository,
          idGenerator: FakeChoreCommandIdGenerator(),
        );

    await controller.load(
      householdId: _householdId,
      occurrenceId: occurrence.id,
    );

    final ChoreOccurrenceTargetLoadFailed failed =
        controller.state as ChoreOccurrenceTargetLoadFailed;
    expect(failed.failure.kind, ChoreFailureKind.internal);
    await controller.dispose();
  });

  test(
    'completes an actionable target and refetches authoritative detail',
    () async {
      final ChoreOccurrence scheduled = choreOccurrenceFixture(
        version: 3,
        canSetCompletion: true,
      );
      final ChoreOccurrence completed = choreOccurrenceFixture(
        status: ChoreOccurrenceStatus.completed,
        version: 4,
        canSetCompletion: true,
      );
      final FakeChoreCommandIdGenerator idGenerator =
          FakeChoreCommandIdGenerator();
      final FakeChoreRepository repository = FakeChoreRepository(
        occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
          ChoreOccurrenceTargetLoaded(scheduled),
          ChoreOccurrenceTargetLoaded(completed),
        ],
      );
      final ChoreOccurrenceTargetController controller =
          ChoreOccurrenceTargetController(
            repository: repository,
            idGenerator: idGenerator,
          );

      await controller.load(
        householdId: _householdId,
        occurrenceId: scheduled.id,
      );
      await controller.setCompleted(completed: true);

      expect(repository.completionRequests, hasLength(1));
      expect(repository.completionRequests.single.expectedVersion, 3);
      expect(repository.completionRequests.single.completed, isTrue);
      expect(repository.occurrenceTargetRequests, hasLength(2));
      expect(idGenerator.generateCount, 1);
      final ChoreOccurrenceTargetReady ready =
          controller.state as ChoreOccurrenceTargetReady;
      expect(ready.occurrence.status, ChoreOccurrenceStatus.completed);
      expect(ready.occurrence.version, 4);
      expect(ready.actionInFlight, isFalse);
      expect(ready.actionFailure, isNull);
      expect(ready.refreshFailure, isNull);
      await controller.dispose();
    },
  );

  test('reopens a completed actionable target', () async {
    final ChoreOccurrence completed = choreOccurrenceFixture(
      status: ChoreOccurrenceStatus.completed,
      version: 5,
      canSetCompletion: true,
    );
    final ChoreOccurrence reopened = choreOccurrenceFixture(
      status: ChoreOccurrenceStatus.scheduled,
      version: 6,
      canSetCompletion: true,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(completed),
        ChoreOccurrenceTargetLoaded(reopened),
      ],
    );
    final ChoreOccurrenceTargetController controller =
        ChoreOccurrenceTargetController(
          repository: repository,
          idGenerator: FakeChoreCommandIdGenerator(),
        );

    await controller.load(
      householdId: _householdId,
      occurrenceId: completed.id,
    );
    await controller.setCompleted(completed: false);

    expect(repository.completionRequests.single.completed, isFalse);
    expect(
      (controller.state as ChoreOccurrenceTargetReady).occurrence.status,
      ChoreOccurrenceStatus.scheduled,
    );
    await controller.dispose();
  });

  test(
    'household change supersedes a pending action without blocking the new scope',
    () async {
      final HouseholdId otherHouseholdId = HouseholdId.tryParse(
        '22222222-2222-4222-8222-222222222223',
      )!;
      final ChoreOccurrence scheduled = choreOccurrenceFixture(
        title: 'Original household chore',
        canSetCompletion: true,
      );
      final ChoreOccurrence otherHouseholdOccurrence = choreOccurrenceFixture(
        title: 'Other household chore',
        canSetCompletion: true,
      );
      final ChoreOccurrence otherHouseholdCompleted = choreOccurrenceFixture(
        title: 'Other household chore',
        status: ChoreOccurrenceStatus.completed,
        version: 2,
        canSetCompletion: true,
      );
      final Completer<SetChoreCompletionResult> response =
          Completer<SetChoreCompletionResult>();
      var completionCallCount = 0;
      final FakeChoreRepository repository = FakeChoreRepository(
        occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
          ChoreOccurrenceTargetLoaded(scheduled),
          ChoreOccurrenceTargetLoaded(otherHouseholdOccurrence),
          ChoreOccurrenceTargetLoaded(otherHouseholdCompleted),
        ],
        completionCallback: (request) {
          completionCallCount += 1;
          return completionCallCount == 1
              ? response.future
              : Future<SetChoreCompletionResult>.value(
                  ChoreCompletionSet(_completionSnapshot(request)),
                );
        },
      );
      final ChoreOccurrenceTargetController controller =
          ChoreOccurrenceTargetController(
            repository: repository,
            idGenerator: FakeChoreCommandIdGenerator(),
          );
      await controller.load(
        householdId: _householdId,
        occurrenceId: scheduled.id,
      );

      final Future<void> oldAction = controller.setCompleted(completed: true);
      await controller.load(
        householdId: otherHouseholdId,
        occurrenceId: scheduled.id,
      );
      await controller.setCompleted(completed: true);

      expect(repository.completionRequests, hasLength(2));
      expect(repository.completionRequests.last.householdId, otherHouseholdId);
      expect(
        repository.completionRequests.first.idempotencyKey,
        isNot(repository.completionRequests.last.idempotencyKey),
      );
      response.complete(
        ChoreCompletionSet(
          _completionSnapshot(repository.completionRequests.first),
        ),
      );
      await oldAction;

      final ChoreOccurrenceTargetReady ready =
          controller.state as ChoreOccurrenceTargetReady;
      expect(ready.householdId, otherHouseholdId);
      expect(ready.occurrence.title, 'Other household chore');
      expect(ready.occurrence.status, ChoreOccurrenceStatus.completed);
      expect(repository.occurrenceTargetRequests, hasLength(3));
      await controller.dispose();
    },
  );

  test(
    'coalesces duplicate taps and reuses the key after response loss',
    () async {
      final ChoreOccurrence scheduled = choreOccurrenceFixture(
        canSetCompletion: true,
      );
      final ChoreOccurrence completed = choreOccurrenceFixture(
        status: ChoreOccurrenceStatus.completed,
        version: 2,
        canSetCompletion: true,
      );
      final Completer<SetChoreCompletionResult> firstResponse =
          Completer<SetChoreCompletionResult>();
      var callCount = 0;
      final FakeChoreCommandIdGenerator idGenerator =
          FakeChoreCommandIdGenerator();
      final FakeChoreRepository repository = FakeChoreRepository(
        occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
          ChoreOccurrenceTargetLoaded(scheduled),
          ChoreOccurrenceTargetLoaded(completed),
        ],
        completionCallback: (request) {
          callCount += 1;
          return callCount == 1
              ? firstResponse.future
              : Future<SetChoreCompletionResult>.value(
                  ChoreCompletionSet(_completionSnapshot(request)),
                );
        },
      );
      final ChoreOccurrenceTargetController controller =
          ChoreOccurrenceTargetController(
            repository: repository,
            idGenerator: idGenerator,
          );
      await controller.load(
        householdId: _householdId,
        occurrenceId: scheduled.id,
      );

      final Future<void> first = controller.setCompleted(completed: true);
      final Future<void> duplicate = controller.setCompleted(completed: true);
      expect(identical(first, duplicate), isTrue);
      expect(repository.completionRequests, hasLength(1));
      firstResponse.complete(
        const SetChoreCompletionFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      );
      await first;

      await controller.setCompleted(completed: true);

      expect(repository.completionRequests, hasLength(2));
      expect(
        repository.completionRequests.first.idempotencyKey,
        repository.completionRequests.last.idempotencyKey,
      );
      expect(idGenerator.generateCount, 1);
      expect(
        (controller.state as ChoreOccurrenceTargetReady).occurrence.status,
        ChoreOccurrenceStatus.completed,
      );
      await controller.dispose();
    },
  );

  test(
    'stale completion failure reconciles without automatic replay',
    () async {
      final ChoreOccurrence scheduled = choreOccurrenceFixture(
        canSetCompletion: true,
      );
      final ChoreOccurrence completed = choreOccurrenceFixture(
        status: ChoreOccurrenceStatus.completed,
        version: 2,
        canSetCompletion: true,
      );
      final FakeChoreRepository repository = FakeChoreRepository(
        occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
          ChoreOccurrenceTargetLoaded(scheduled),
          ChoreOccurrenceTargetLoaded(completed),
        ],
        completionResults: const <SetChoreCompletionResult>[
          SetChoreCompletionFailed(ChoreFailure(ChoreFailureKind.staleVersion)),
        ],
      );
      final ChoreOccurrenceTargetController controller =
          ChoreOccurrenceTargetController(
            repository: repository,
            idGenerator: FakeChoreCommandIdGenerator(),
          );
      await controller.load(
        householdId: _householdId,
        occurrenceId: scheduled.id,
      );

      await controller.setCompleted(completed: true);

      expect(repository.completionRequests, hasLength(1));
      final ChoreOccurrenceTargetReady ready =
          controller.state as ChoreOccurrenceTargetReady;
      expect(ready.occurrence.status, ChoreOccurrenceStatus.completed);
      expect(ready.actionFailure?.kind, ChoreFailureKind.staleVersion);
      await controller.dispose();
    },
  );

  test('post-commit refresh failure preserves the reconciled result', () async {
    final ChoreOccurrence scheduled = choreOccurrenceFixture(
      version: 7,
      canSetCompletion: true,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(scheduled),
        const LoadChoreOccurrenceTargetFailed(
          ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
        ),
      ],
    );
    final ChoreOccurrenceTargetController controller =
        ChoreOccurrenceTargetController(
          repository: repository,
          idGenerator: FakeChoreCommandIdGenerator(),
        );
    await controller.load(
      householdId: _householdId,
      occurrenceId: scheduled.id,
    );

    await controller.setCompleted(completed: true);

    final ChoreOccurrenceTargetReady ready =
        controller.state as ChoreOccurrenceTargetReady;
    expect(ready.occurrence.status, ChoreOccurrenceStatus.completed);
    expect(ready.occurrence.version, 8);
    expect(ready.refreshFailure?.kind, ChoreFailureKind.temporarilyUnavailable);
    await controller.dispose();
  });

  test('non-actionable target never calls the mutation repository', () async {
    final ChoreOccurrence occurrence = choreOccurrenceFixture(
      canSetCompletion: false,
    );
    final FakeChoreRepository repository = FakeChoreRepository(
      occurrenceTargetResults: <LoadChoreOccurrenceTargetResult>[
        ChoreOccurrenceTargetLoaded(occurrence),
      ],
    );
    final ChoreOccurrenceTargetController controller =
        ChoreOccurrenceTargetController(
          repository: repository,
          idGenerator: FakeChoreCommandIdGenerator(),
        );
    await controller.load(
      householdId: _householdId,
      occurrenceId: occurrence.id,
    );

    await controller.setCompleted(completed: true);

    expect(repository.completionRequests, isEmpty);
    await controller.dispose();
  });
}

ChoreCompletionSnapshot _completionSnapshot(SetChoreCompletionRequest request) {
  return ChoreCompletionSnapshot(
    householdId: request.householdId,
    occurrenceId: request.occurrenceId,
    status: request.completed
        ? ChoreOccurrenceStatus.completed
        : ChoreOccurrenceStatus.scheduled,
    version: request.expectedVersion + 1,
    completedByMemberId: request.completed
        ? HouseholdMemberId.tryParse('33333333-3333-4333-8333-333333333333')
        : null,
    completedAt: request.completed
        ? DateTime.parse('2026-08-09T12:00:00Z')
        : null,
    changed: true,
  );
}

final HouseholdId _householdId = HouseholdId.tryParse(
  '22222222-2222-4222-8222-222222222222',
)!;
