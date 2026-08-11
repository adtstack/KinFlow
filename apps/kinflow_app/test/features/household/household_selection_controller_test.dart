import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/application/household_selection_controller.dart';
import 'package:kinflow_app/features/household/application/household_selection_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_selection.dart';
import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';

import '../../support/fakes/fake_household_selection_dependencies.dart';

void main() {
  test('loads memberships then commits a versioned switch locally', () async {
    final HouseholdSelectionSnapshot snapshot =
        householdSelectionSnapshotFixture();
    final FakeHouseholdSelectionRepository repository =
        FakeHouseholdSelectionRepository(
          loadResult: HouseholdSelectionsLoaded(snapshot),
          switchResult: ActiveHouseholdSwitched(
            HouseholdSelectionCommit(
              activeHousehold: switchedActiveHouseholdFixture(),
              selectionVersion: 5,
              changed: true,
            ),
          ),
        );
    final FakeActiveHouseholdCommitter committer =
        FakeActiveHouseholdCommitter();
    final HouseholdSelectionController controller =
        HouseholdSelectionController(
          repository: repository,
          committer: committer,
        );
    addTearDown(controller.dispose);

    await controller.load();
    final bool switched = await controller.switchActiveHousehold(
      householdIdFixture(householdSelectionBId),
    );

    expect(switched, isTrue);
    expect(repository.expectedSelectionVersion, 4);
    expect(committer.households.single, switchedActiveHouseholdFixture());
    final HouseholdSelectionReady state =
        controller.state as HouseholdSelectionReady;
    expect(state.snapshot.selectionVersion, 5);
    expect(
      state.snapshot.activeHousehold?.householdId.value,
      householdSelectionBId,
    );
    expect(state.successfulSwitchCount, 1);
  });

  test(
    'single-flight switch retains list while the server is pending',
    () async {
      final Completer<SwitchActiveHouseholdResult> response =
          Completer<SwitchActiveHouseholdResult>();
      final FakeHouseholdSelectionRepository repository =
          FakeHouseholdSelectionRepository(
            loadResult: HouseholdSelectionsLoaded(
              householdSelectionSnapshotFixture(),
            ),
            switchResult: const SwitchActiveHouseholdFailed(
              HouseholdSelectionFailure(HouseholdSelectionFailureKind.internal),
            ),
            switchCallback: (_, _) => response.future,
          );
      final HouseholdSelectionController controller =
          HouseholdSelectionController(
            repository: repository,
            committer: FakeActiveHouseholdCommitter(),
          );
      addTearDown(controller.dispose);
      await controller.load();

      final Future<bool> first = controller.switchActiveHousehold(
        householdIdFixture(householdSelectionBId),
      );
      final bool duplicate = await controller.switchActiveHousehold(
        householdIdFixture(householdSelectionBId),
      );
      expect(duplicate, isFalse);
      expect(repository.switchCount, 1);
      expect(
        (controller.state as HouseholdSelectionReady).snapshot.households,
        hasLength(2),
      );

      response.complete(
        ActiveHouseholdSwitched(
          HouseholdSelectionCommit(
            activeHousehold: switchedActiveHouseholdFixture(),
            selectionVersion: 5,
            changed: true,
          ),
        ),
      );
      expect(await first, isTrue);
    },
  );

  test('conflict and local purge failure stay fail closed', () async {
    final HouseholdSelectionSnapshot snapshot =
        householdSelectionSnapshotFixture();
    final conflictController = HouseholdSelectionController(
      repository: FakeHouseholdSelectionRepository(
        loadResult: HouseholdSelectionsLoaded(snapshot),
        switchResult: const SwitchActiveHouseholdFailed(
          HouseholdSelectionFailure(
            HouseholdSelectionFailureKind.versionConflict,
          ),
        ),
      ),
      committer: FakeActiveHouseholdCommitter(),
    );
    addTearDown(conflictController.dispose);
    await conflictController.load();
    expect(
      await conflictController.switchActiveHousehold(
        householdIdFixture(householdSelectionBId),
      ),
      isFalse,
    );
    expect(
      (conflictController.state as HouseholdSelectionReady).failure?.kind,
      HouseholdSelectionFailureKind.versionConflict,
    );

    final localFailureController = HouseholdSelectionController(
      repository: FakeHouseholdSelectionRepository(
        loadResult: HouseholdSelectionsLoaded(snapshot),
        switchResult: ActiveHouseholdSwitched(
          HouseholdSelectionCommit(
            activeHousehold: switchedActiveHouseholdFixture(),
            selectionVersion: 5,
            changed: true,
          ),
        ),
      ),
      committer: FakeActiveHouseholdCommitter(result: false),
    );
    addTearDown(localFailureController.dispose);
    await localFailureController.load();
    expect(
      await localFailureController.switchActiveHousehold(
        householdIdFixture(householdSelectionBId),
      ),
      isFalse,
    );
    final HouseholdSelectionReady failed =
        localFailureController.state as HouseholdSelectionReady;
    expect(
      failed.failure?.kind,
      HouseholdSelectionFailureKind.localStateUnavailable,
    );
    expect(
      failed.snapshot.activeHousehold?.householdId.value,
      householdSelectionAId,
    );
  });
}
