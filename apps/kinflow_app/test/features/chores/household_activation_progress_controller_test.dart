import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/household_activation_progress_controller.dart';
import 'package:kinflow_app/features/chores/application/household_activation_progress_state.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_chore_dependencies.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    '22222222-2222-4222-8222-222222222222',
  )!;
  final HouseholdId nextHouseholdId = HouseholdId.tryParse(
    '99999999-9999-4999-8999-999999999999',
  )!;

  test('coalesces duplicate load and publishes the aggregate', () async {
    final Completer<LoadHouseholdActivationProgressResult> response =
        Completer<LoadHouseholdActivationProgressResult>();
    final FakeChoreRepository repository = FakeChoreRepository(
      activationProgressCallback: (_) => response.future,
    );
    final HouseholdActivationProgressController controller =
        HouseholdActivationProgressController(repository: repository);
    addTearDown(controller.dispose);

    final Future<void> first = controller.load(householdId);
    final Future<void> duplicate = controller.load(householdId);

    expect(identical(first, duplicate), isTrue);
    expect(repository.activationProgressHouseholds, <HouseholdId>[householdId]);
    expect(controller.state, isA<HouseholdActivationProgressLoading>());

    response.complete(
      HouseholdActivationProgressLoaded(
        householdActivationProgressFixture(
          householdId: householdId,
          adultParticipantProgress: 2,
          choreCreationProgress: 3,
        ),
      ),
    );
    await first;

    final HouseholdActivationProgressReady ready =
        controller.state as HouseholdActivationProgressReady;
    expect(ready.progress.adultParticipantReached, isTrue);
    expect(ready.progress.choreCreationReached, isTrue);
    expect(ready.refreshing, isFalse);
  });

  test(
    'preserves ready content while an explicit refresh is pending',
    () async {
      final Completer<LoadHouseholdActivationProgressResult> refresh =
          Completer<LoadHouseholdActivationProgressResult>();
      var calls = 0;
      final FakeChoreRepository repository = FakeChoreRepository(
        activationProgressCallback: (_) {
          calls += 1;
          return calls == 1
              ? Future<LoadHouseholdActivationProgressResult>.value(
                  HouseholdActivationProgressLoaded(
                    householdActivationProgressFixture(
                      householdId: householdId,
                      choreCreationProgress: 1,
                    ),
                  ),
                )
              : refresh.future;
        },
      );
      final HouseholdActivationProgressController controller =
          HouseholdActivationProgressController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load(householdId);

      final Future<void> pending = controller.load(
        householdId,
        preserveContent: true,
      );
      final HouseholdActivationProgressReady refreshing =
          controller.state as HouseholdActivationProgressReady;
      expect(refreshing.refreshing, isTrue);
      expect(refreshing.progress.choreCreationProgress, 1);

      refresh.complete(
        HouseholdActivationProgressLoaded(
          householdActivationProgressFixture(
            householdId: householdId,
            choreCreationProgress: 2,
          ),
        ),
      );
      await pending;
      expect(
        (controller.state as HouseholdActivationProgressReady)
            .progress
            .choreCreationProgress,
        2,
      );
    },
  );

  test(
    'ignores an older household response after a household switch',
    () async {
      final Completer<LoadHouseholdActivationProgressResult> firstResponse =
          Completer<LoadHouseholdActivationProgressResult>();
      final Completer<LoadHouseholdActivationProgressResult> secondResponse =
          Completer<LoadHouseholdActivationProgressResult>();
      final FakeChoreRepository repository = FakeChoreRepository(
        activationProgressCallback: (HouseholdId requested) =>
            requested == householdId
            ? firstResponse.future
            : secondResponse.future,
      );
      final HouseholdActivationProgressController controller =
          HouseholdActivationProgressController(repository: repository);
      addTearDown(controller.dispose);

      final Future<void> first = controller.load(householdId);
      final Future<void> second = controller.load(nextHouseholdId);
      secondResponse.complete(
        HouseholdActivationProgressLoaded(
          householdActivationProgressFixture(householdId: nextHouseholdId),
        ),
      );
      await second;
      firstResponse.complete(
        HouseholdActivationProgressLoaded(
          householdActivationProgressFixture(householdId: householdId),
        ),
      );
      await first;

      expect(
        (controller.state as HouseholdActivationProgressReady)
            .progress
            .householdId,
        nextHouseholdId,
      );
    },
  );

  test(
    'maps repository failures and thrown errors without raw detail',
    () async {
      final FakeChoreRepository failedRepository = FakeChoreRepository(
        activationProgressResults:
            const <LoadHouseholdActivationProgressResult>[
              LoadHouseholdActivationProgressFailed(
                ChoreFailure(ChoreFailureKind.temporarilyUnavailable),
              ),
            ],
      );
      final HouseholdActivationProgressController failed =
          HouseholdActivationProgressController(repository: failedRepository);
      addTearDown(failed.dispose);
      await failed.load(householdId);
      expect(
        (failed.state as HouseholdActivationProgressFailed).failure.kind,
        ChoreFailureKind.temporarilyUnavailable,
      );

      final FakeChoreRepository throwingRepository = FakeChoreRepository(
        activationProgressCallback: (_) => throw StateError('provider secret'),
      );
      final HouseholdActivationProgressController throwing =
          HouseholdActivationProgressController(repository: throwingRepository);
      addTearDown(throwing.dispose);
      await throwing.load(householdId);
      expect(
        (throwing.state as HouseholdActivationProgressFailed).failure.kind,
        ChoreFailureKind.internal,
      );
    },
  );
}
