import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_controller.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_template.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

import '../../support/fakes/fake_chore_dependencies.dart';
import '../../support/fakes/fake_household_dependencies.dart';

void main() {
  test(
    'loads server household date and creates three chores in catalog order',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository();
      final FakeChoreCommandIdGenerator generator =
          FakeChoreCommandIdGenerator();
      final GuidedChoreSetupController controller = _controller(
        repository,
        generator,
      );
      addTearDown(controller.dispose);

      await _load(controller);
      expect(controller.state, isA<GuidedChoreSetupReady>());
      await controller.submit(_validInputs().reversed.toList());

      expect(
        (controller.state as GuidedChoreSetupSucceeded).createdCount,
        GuidedChoreSetupDraft.requiredEntryCount,
      );
      expect(repository.loadedHouseholds, <HouseholdId>[
        activeHouseholdFixture().householdId,
      ]);
      expect(repository.recurringRequests, hasLength(3));
      expect(
        repository.recurringRequests.map((request) => request.title),
        <String>['Dishes', 'Kitchen reset', 'Laundry'],
      );
      expect(
        repository.recurringRequests.map(
          (request) => request.startLocalDate.value,
        ),
        everyElement('2026-08-06'),
      );
      expect(
        repository.recurringRequests.map((request) => request.assigneeMemberId),
        everyElement(activeHouseholdFixture().memberId),
      );
      expect(
        repository.recurringRequests.map((request) => request.description),
        everyElement(isNull),
      );
      expect(
        repository.recurringRequests.map((request) => request.dueLocalTime),
        everyElement(isNull),
      );
      expect(
        repository.recurringRequests
            .map((request) => request.idempotencyKey)
            .toSet(),
        hasLength(3),
      );
      expect(generator.generateCount, 3);
    },
  );

  test(
    'partial retry skips success and reuses the failed command ID',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository(
        recurringResults: <CreateRecurringChoreResult>[
          RecurringChoreCreated(_snapshot()),
          const CreateRecurringChoreFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
          RecurringChoreCreated(_snapshot()),
          RecurringChoreCreated(_snapshot()),
        ],
      );
      final GuidedChoreSetupController controller = _controller(
        repository,
        FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await _load(controller);

      await controller.submit(_validInputs());
      final GuidedChoreSetupSubmissionFailed failed =
          controller.state as GuidedChoreSetupSubmissionFailed;
      expect(failed.completedCount, 1);
      expect(failed.draftFrozen, isTrue);
      expect(repository.recurringRequests, hasLength(2));

      await controller.submit(_validInputs());
      expect(controller.state, isA<GuidedChoreSetupSucceeded>());
      expect(repository.recurringRequests, hasLength(4));
      expect(
        repository.recurringRequests[1].idempotencyKey,
        repository.recurringRequests[2].idempotencyKey,
      );
      expect(
        repository.recurringRequests.first.idempotencyKey,
        isNot(repository.recurringRequests[2].idempotencyKey),
      );
    },
  );

  test(
    'rejects a changed full recurrence after an ambiguous failure',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository(
        recurringResults: const <CreateRecurringChoreResult>[
          CreateRecurringChoreFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final GuidedChoreSetupController controller = _controller(
        repository,
        FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await _load(controller);
      await controller.submit(_validInputs());

      final List<GuidedChoreSetupInput> changed =
          List<GuidedChoreSetupInput>.of(_validInputs());
      changed[0] = GuidedChoreSetupInput.withRecurrence(
        template: ChoreTemplatePreset.dishes,
        title: 'Dishes',
        recurrenceRule: ChoreRecurrenceRule.tryAnchored(
          frequency: ChoreRecurrenceFrequency.daily,
          startLocalDate: ChoreLocalDate.tryParse('2026-08-06')!,
          interval: 2,
          end: const ChoreRecurrenceNeverEnds(),
        )!,
      );
      await controller.submit(changed);

      final GuidedChoreSetupSubmissionFailed failed =
          controller.state as GuidedChoreSetupSubmissionFailed;
      expect(failed.failure.kind, ChoreFailureKind.invalidTransition);
      expect(failed.draftFrozen, isTrue);
      expect(repository.recurringRequests, hasLength(1));
    },
  );

  test(
    'coalesces duplicate submission while the first request is pending',
    () async {
      final Completer<CreateRecurringChoreResult> firstResponse =
          Completer<CreateRecurringChoreResult>();
      var requestIndex = 0;
      final FakeChoreRepository repository = FakeChoreRepository(
        recurringCallback: (_) {
          requestIndex += 1;
          return requestIndex == 1
              ? firstResponse.future
              : Future<CreateRecurringChoreResult>.value(
                  RecurringChoreCreated(_snapshot()),
                );
        },
      );
      final GuidedChoreSetupController controller = _controller(
        repository,
        FakeChoreCommandIdGenerator(),
      );
      addTearDown(controller.dispose);
      await _load(controller);

      final Future<void> first = controller.submit(_validInputs());
      final Future<void> duplicate = controller.submit(_validInputs());
      expect(identical(first, duplicate), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(repository.recurringRequests, hasLength(1));

      firstResponse.complete(RecurringChoreCreated(_snapshot()));
      await first;
      expect(repository.recurringRequests, hasLength(3));
      expect(controller.state, isA<GuidedChoreSetupSucceeded>());
    },
  );

  test('rejects cached or cross-household Today authority', () async {
    final ReadCacheMetadata metadata = ReadCacheMetadata(
      validatedAt: DateTime.parse('2026-08-06T00:00:00Z'),
      expiresAt: DateTime.parse('2026-08-06T01:00:00Z'),
    );
    final FakeChoreRepository cachedRepository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(todayChoresFixture(), cacheMetadata: metadata),
      ],
    );
    final GuidedChoreSetupController cached = _controller(
      cachedRepository,
      FakeChoreCommandIdGenerator(),
    );
    addTearDown(cached.dispose);
    await _load(cached);
    expect(
      (cached.state as GuidedChoreSetupLoadFailed).failure.kind,
      ChoreFailureKind.offlineReadOnly,
    );

    final FakeChoreRepository mismatchedRepository = FakeChoreRepository(
      loadResults: <LoadTodayChoresResult>[
        TodayChoresLoaded(
          TodayChores(
            householdId: HouseholdId.tryParse(
              '99999999-9999-4999-8999-999999999999',
            )!,
            householdTimezone: 'Asia/Seoul',
            localDate: ChoreLocalDate.tryParse('2026-08-06')!,
            occurrences: const <ChoreOccurrence>[],
          ),
        ),
      ],
    );
    final GuidedChoreSetupController mismatched = _controller(
      mismatchedRepository,
      FakeChoreCommandIdGenerator(),
    );
    addTearDown(mismatched.dispose);
    await _load(mismatched);
    expect(
      (mismatched.state as GuidedChoreSetupLoadFailed).failure.kind,
      ChoreFailureKind.invalidPayload,
    );
  });

  test('sends no server request when the initial durable save fails', () async {
    final FakeChoreRepository repository = FakeChoreRepository();
    final FakeGuidedChoreSetupResumeStore store =
        FakeGuidedChoreSetupResumeStore(writeResults: <bool>[false]);
    final GuidedChoreSetupController controller = _controller(
      repository,
      FakeChoreCommandIdGenerator(),
      store: store,
    );
    addTearDown(controller.dispose);
    await _load(controller);

    await controller.submit(_validInputs());

    final GuidedChoreSetupSubmissionFailed failed =
        controller.state as GuidedChoreSetupSubmissionFailed;
    expect(failed.failure.kind, ChoreFailureKind.internal);
    expect(failed.draftFrozen, isFalse);
    expect(repository.recurringRequests, isEmpty);
    expect(store.writes, hasLength(1));
    expect(store.plan, isNull);
  });

  test(
    'contains a throwing resume provider without exposing its error',
    () async {
      final FakeChoreRepository repository = FakeChoreRepository();
      final FakeGuidedChoreSetupResumeStore store =
          FakeGuidedChoreSetupResumeStore(throwOnWrite: true);
      final GuidedChoreSetupController controller = _controller(
        repository,
        FakeChoreCommandIdGenerator(),
        store: store,
      );
      addTearDown(controller.dispose);
      await _load(controller);

      await controller.submit(_validInputs());

      expect(repository.recurringRequests, isEmpty);
      expect(
        (controller.state as GuidedChoreSetupSubmissionFailed).failure.kind,
        ChoreFailureKind.internal,
      );
    },
  );

  test(
    'new controller resumes only remaining entries with stored IDs',
    () async {
      final FakeGuidedChoreSetupResumeStore store =
          FakeGuidedChoreSetupResumeStore();
      final FakeChoreRepository firstRepository = FakeChoreRepository(
        recurringResults: <CreateRecurringChoreResult>[
          RecurringChoreCreated(_snapshot()),
          const CreateRecurringChoreFailed(
            ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
          ),
        ],
      );
      final GuidedChoreSetupController first = _controller(
        firstRepository,
        FakeChoreCommandIdGenerator(),
        store: store,
      );
      await _load(first);
      await first.submit(_validInputs());
      expect(store.plan!.completedCount, 1);
      final ChoreCommandId failedCommand =
          firstRepository.recurringRequests[1].idempotencyKey;
      await first.dispose();

      final FakeChoreRepository resumedRepository = FakeChoreRepository(
        recurringResults: <CreateRecurringChoreResult>[
          RecurringChoreCreated(_snapshot()),
          RecurringChoreCreated(_snapshot()),
        ],
      );
      final FakeChoreCommandIdGenerator resumedGenerator =
          FakeChoreCommandIdGenerator();
      final GuidedChoreSetupController resumed = _controller(
        resumedRepository,
        resumedGenerator,
        store: store,
      );
      addTearDown(resumed.dispose);

      await _load(resumed);

      expect(resumed.state, isA<GuidedChoreSetupSucceeded>());
      expect(
        resumedRepository.recurringRequests.map((request) => request.title),
        <String>['Kitchen reset', 'Laundry'],
      );
      expect(
        resumedRepository.recurringRequests.first.idempotencyKey,
        failedCommand,
      );
      expect(resumedGenerator.generateCount, 0);
      expect(store.plan, isNull);
    },
  );

  test(
    'checkpoint loss replays the same payload and command after recreation',
    () async {
      final FakeGuidedChoreSetupResumeStore store =
          FakeGuidedChoreSetupResumeStore(writeResults: <bool>[true, false]);
      final FakeChoreRepository firstRepository = FakeChoreRepository(
        recurringResults: <CreateRecurringChoreResult>[
          RecurringChoreCreated(_snapshot()),
        ],
      );
      final GuidedChoreSetupController first = _controller(
        firstRepository,
        FakeChoreCommandIdGenerator(),
        store: store,
      );
      await _load(first);
      await first.submit(_validInputs());
      final ChoreCommandId ambiguousCommand =
          firstRepository.recurringRequests.single.idempotencyKey;
      expect(store.plan!.completedCount, 0);
      expect(
        (first.state as GuidedChoreSetupSubmissionFailed).completedCount,
        0,
      );
      await first.dispose();

      final FakeChoreRepository resumedRepository = FakeChoreRepository();
      final GuidedChoreSetupController resumed = _controller(
        resumedRepository,
        FakeChoreCommandIdGenerator(),
        store: store,
      );
      addTearDown(resumed.dispose);
      await _load(resumed);

      expect(resumed.state, isA<GuidedChoreSetupSucceeded>());
      expect(resumedRepository.recurringRequests, hasLength(3));
      expect(
        resumedRepository.recurringRequests.first.idempotencyKey,
        ambiguousCommand,
      );
      expect(resumedRepository.recurringRequests.first.title, 'Dishes');
    },
  );

  test(
    'completed checkpoint retries only secure cleanup after clear failure',
    () async {
      final FakeGuidedChoreSetupResumeStore store =
          FakeGuidedChoreSetupResumeStore(clearResults: <bool>[false, true]);
      final FakeChoreRepository repository = FakeChoreRepository();
      final GuidedChoreSetupController controller = _controller(
        repository,
        FakeChoreCommandIdGenerator(),
        store: store,
      );
      addTearDown(controller.dispose);
      await _load(controller);

      await controller.submit(_validInputs());
      final GuidedChoreSetupSubmissionFailed failed =
          controller.state as GuidedChoreSetupSubmissionFailed;
      expect(failed.completedCount, 3);
      expect(repository.recurringRequests, hasLength(3));
      expect(store.plan!.completedCount, 3);

      await controller.submit(_validInputs());
      expect(controller.state, isA<GuidedChoreSetupSucceeded>());
      expect(repository.recurringRequests, hasLength(3));
      expect(store.clearCount, 2);
    },
  );
}

GuidedChoreSetupController _controller(
  FakeChoreRepository repository,
  FakeChoreCommandIdGenerator generator, {
  FakeGuidedChoreSetupResumeStore? store,
}) {
  return GuidedChoreSetupController(
    repository: repository,
    idGenerator: generator,
    resumeStore: store ?? FakeGuidedChoreSetupResumeStore(),
  );
}

Future<void> _load(GuidedChoreSetupController controller) {
  final active = activeHouseholdFixture();
  return controller.load(
    householdId: active.householdId,
    assigneeMemberId: active.memberId,
  );
}

List<GuidedChoreSetupInput> _validInputs() {
  return const <GuidedChoreSetupInput>[
    GuidedChoreSetupInput(
      template: ChoreTemplatePreset.dishes,
      title: 'Dishes',
      frequency: ChoreRecurrenceFrequency.daily,
    ),
    GuidedChoreSetupInput(
      template: ChoreTemplatePreset.kitchenReset,
      title: 'Kitchen reset',
      frequency: ChoreRecurrenceFrequency.daily,
    ),
    GuidedChoreSetupInput(
      template: ChoreTemplatePreset.laundry,
      title: 'Laundry',
      frequency: ChoreRecurrenceFrequency.weekly,
    ),
  ];
}

RecurringChoreSnapshot _snapshot() {
  final start = ChoreLocalDate.tryParse('2026-08-06')!;
  return RecurringChoreSnapshot(
    householdId: activeHouseholdFixture().householdId,
    seriesId: ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!,
    firstOccurrenceId: ChoreOccurrenceId.tryParse(
      '55555555-5555-4555-8555-555555555555',
    )!,
    recurrenceRule: ChoreRecurrenceRule.anchored(
      frequency: ChoreRecurrenceFrequency.daily,
      startLocalDate: start,
    ),
    materializedThrough: start,
    materializedCount: 1,
    created: true,
  );
}
