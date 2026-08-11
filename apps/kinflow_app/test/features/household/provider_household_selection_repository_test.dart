import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/data/datasources/household_selection_data_source.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_household_selection_repository.dart';
import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';

import '../../support/fakes/fake_household_selection_dependencies.dart';

void main() {
  HouseholdSelectionDataRecord row({
    String householdId = householdSelectionAId,
    String memberId = householdSelectionAMemberId,
    String householdName = 'Alpha family',
    String memberRole = 'owner',
    int membershipVersion = 2,
    bool isActive = true,
    int selectionVersion = 4,
  }) {
    return HouseholdSelectionDataRecord(
      householdId: householdId,
      memberId: memberId,
      householdName: householdName,
      memberRole: memberRole,
      membershipVersion: membershipVersion,
      isActive: isActive,
      selectionVersion: selectionVersion,
    );
  }

  test('maps two own memberships and the single active selection', () async {
    final FakeHouseholdSelectionDataSource dataSource =
        FakeHouseholdSelectionDataSource(
          loadResult:
              HouseholdSelectionDataSucceeded(<HouseholdSelectionDataRecord>[
                row(),
                row(
                  householdId: householdSelectionBId,
                  memberId: householdSelectionBMemberId,
                  householdName: 'Beta family',
                  memberRole: 'member',
                  membershipVersion: 3,
                  isActive: false,
                ),
              ]),
          switchResult: const HouseholdSelectionDataFailed(
            HouseholdSelectionDataFailureKind.unknown,
          ),
        );
    final ProviderHouseholdSelectionRepository repository =
        ProviderHouseholdSelectionRepository(dataSource);

    final LoadHouseholdSelectionsResult result = await repository.load();

    expect(result, isA<HouseholdSelectionsLoaded>());
    final snapshot = (result as HouseholdSelectionsLoaded).snapshot;
    expect(snapshot.households, hasLength(2));
    expect(snapshot.activeHousehold?.householdName, 'Alpha family');
    expect(snapshot.selectionVersion, 4);
  });

  test('rejects duplicate, inconsistent, and non-canonical rows', () async {
    for (final List<HouseholdSelectionDataRecord> rows
        in <List<HouseholdSelectionDataRecord>>[
          <HouseholdSelectionDataRecord>[row(), row()],
          <HouseholdSelectionDataRecord>[
            row(),
            row(
              householdId: householdSelectionBId,
              memberId: householdSelectionBMemberId,
              selectionVersion: 5,
              isActive: false,
            ),
          ],
          <HouseholdSelectionDataRecord>[row(householdName: ' Alpha family')],
          <HouseholdSelectionDataRecord>[row(memberRole: 'child')],
          <HouseholdSelectionDataRecord>[
            row(isActive: false, selectionVersion: 4),
          ],
        ]) {
      final ProviderHouseholdSelectionRepository repository =
          ProviderHouseholdSelectionRepository(
            FakeHouseholdSelectionDataSource(
              loadResult: HouseholdSelectionDataSucceeded(rows),
              switchResult: const HouseholdSelectionDataFailed(
                HouseholdSelectionDataFailureKind.unknown,
              ),
            ),
          );
      final result = await repository.load();
      expect(
        (result as LoadHouseholdSelectionsFailed).failure.kind,
        HouseholdSelectionFailureKind.invalidPayload,
      );
    }
  });

  test(
    'switch derives member from response and enforces version advance',
    () async {
      final FakeHouseholdSelectionDataSource dataSource =
          FakeHouseholdSelectionDataSource(
            loadResult: const HouseholdSelectionDataSucceeded(
              <HouseholdSelectionDataRecord>[],
            ),
            switchResult: const HouseholdSelectionDataSucceeded(
              ActiveHouseholdSwitchDataRecord(
                householdId: householdSelectionBId,
                memberId: householdSelectionBMemberId,
                selectionVersion: 5,
                changed: true,
              ),
            ),
          );
      final ProviderHouseholdSelectionRepository repository =
          ProviderHouseholdSelectionRepository(dataSource);

      final SwitchActiveHouseholdResult result = await repository
          .switchActiveHousehold(
            targetHouseholdId: householdIdFixture(householdSelectionBId),
            expectedSelectionVersion: 4,
          );

      expect(result, isA<ActiveHouseholdSwitched>());
      final commit = (result as ActiveHouseholdSwitched).commit;
      expect(
        commit.activeHousehold.memberId.value,
        householdSelectionBMemberId,
      );
      expect(dataSource.targetHouseholdId, householdSelectionBId);
      expect(dataSource.expectedSelectionVersion, 4);

      final invalidRepository = ProviderHouseholdSelectionRepository(
        FakeHouseholdSelectionDataSource(
          loadResult: const HouseholdSelectionDataSucceeded(
            <HouseholdSelectionDataRecord>[],
          ),
          switchResult: const HouseholdSelectionDataSucceeded(
            ActiveHouseholdSwitchDataRecord(
              householdId: householdSelectionBId,
              memberId: householdSelectionBMemberId,
              selectionVersion: 6,
              changed: true,
            ),
          ),
        ),
      );
      final invalid = await invalidRepository.switchActiveHousehold(
        targetHouseholdId: householdIdFixture(householdSelectionBId),
        expectedSelectionVersion: 4,
      );
      expect(
        (invalid as SwitchActiveHouseholdFailed).failure.kind,
        HouseholdSelectionFailureKind.invalidPayload,
      );
    },
  );
}
