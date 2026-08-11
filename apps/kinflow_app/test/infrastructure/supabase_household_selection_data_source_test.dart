import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/data/datasources/household_selection_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_selection_data_source.dart';

import '../support/fakes/fake_household_selection_dependencies.dart';

void main() {
  Map<String, Object?> selectionRow({
    String householdId = householdSelectionAId,
    String memberId = householdSelectionAMemberId,
    bool isActive = true,
    int selectionVersion = 4,
  }) {
    return <String, Object?>{
      'household_id': householdId,
      'member_id': memberId,
      'household_name': 'Alpha family',
      'member_role': 'owner',
      'membership_version': 2,
      'is_active': isActive,
      'selection_version': selectionVersion,
    };
  }

  test(
    'list parser accepts an empty or exact privacy-minimized projection',
    () {
      expect(householdSelectionRecordsFromPayload(const <Object?>[]), isEmpty);
      final records = householdSelectionRecordsFromPayload(<Object?>[
        selectionRow(),
      ]);
      expect(records?.single.householdId, householdSelectionAId);
      expect(records?.single.isActive, isTrue);

      expect(
        householdSelectionRecordsFromPayload(<Object?>[
          <String, Object?>{
            ...selectionRow(),
            'other_member_name': 'must-not-cross-boundary',
          },
        ]),
        isNull,
      );
      expect(
        householdSelectionRecordsFromPayload(<Object?>[
          <String, Object?>{...selectionRow(), 'membership_version': 2.5},
        ]),
        isNull,
      );
    },
  );

  test('switch parser requires exactly one four-key result row', () {
    final Map<String, Object?> row = <String, Object?>{
      'household_id': householdSelectionBId,
      'member_id': householdSelectionBMemberId,
      'selection_version': 5,
      'changed': true,
    };
    final record = activeHouseholdSwitchRecordFromPayload(<Object?>[row]);
    expect(record?.selectionVersion, 5);
    expect(record?.changed, isTrue);

    expect(activeHouseholdSwitchRecordFromPayload(<Object?>[row, row]), isNull);
    expect(
      activeHouseholdSwitchRecordFromPayload(<Object?>[
        <String, Object?>{...row, 'member_count': 2},
      ]),
      isNull,
    );
  });

  test('provider codes map to stable non-reflective failure kinds', () {
    expect(
      householdSelectionDataFailureFromProviderCode('KFH01'),
      HouseholdSelectionDataFailureKind.unauthenticated,
    );
    expect(
      householdSelectionDataFailureFromProviderCode('KFH06'),
      HouseholdSelectionDataFailureKind.targetUnavailable,
    );
    expect(
      householdSelectionDataFailureFromProviderCode('KFH07'),
      HouseholdSelectionDataFailureKind.versionConflict,
    );
    expect(
      householdSelectionDataFailureFromProviderCode('private-provider-detail'),
      HouseholdSelectionDataFailureKind.unknown,
    );
    expect(
      householdSelectionDataFailureFromProviderCode(null),
      HouseholdSelectionDataFailureKind.unknown,
    );
  });
}
