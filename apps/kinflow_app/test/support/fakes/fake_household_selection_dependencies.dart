import 'dart:async';

import 'package:kinflow_app/features/household/application/ports/active_household_committer.dart';
import 'package:kinflow_app/features/household/data/datasources/household_selection_data_source.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/entities/household_selection.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

const String householdSelectionAId = '22000000-0000-4000-8000-000000000001';
const String householdSelectionAMemberId =
    '33000000-0000-4000-8000-000000000001';
const String householdSelectionBId = '22000000-0000-4000-8000-000000000002';
const String householdSelectionBMemberId =
    '33000000-0000-4000-8000-000000000002';

final class FakeHouseholdSelectionDataSource
    implements HouseholdSelectionDataSource {
  FakeHouseholdSelectionDataSource({
    required this.loadResult,
    required this.switchResult,
  });

  final HouseholdSelectionDataResult<List<HouseholdSelectionDataRecord>>
  loadResult;
  final HouseholdSelectionDataResult<ActiveHouseholdSwitchDataRecord>
  switchResult;
  String? targetHouseholdId;
  int? expectedSelectionVersion;
  var loadCount = 0;
  var switchCount = 0;

  @override
  Future<HouseholdSelectionDataResult<List<HouseholdSelectionDataRecord>>>
  load() async {
    loadCount += 1;
    return loadResult;
  }

  @override
  Future<HouseholdSelectionDataResult<ActiveHouseholdSwitchDataRecord>>
  switchActiveHousehold({
    required String targetHouseholdId,
    required int expectedSelectionVersion,
  }) async {
    switchCount += 1;
    this.targetHouseholdId = targetHouseholdId;
    this.expectedSelectionVersion = expectedSelectionVersion;
    return switchResult;
  }
}

final class FakeHouseholdSelectionRepository
    implements HouseholdSelectionRepository {
  FakeHouseholdSelectionRepository({
    required this.loadResult,
    required this.switchResult,
    this.switchCallback,
  });

  final LoadHouseholdSelectionsResult loadResult;
  final SwitchActiveHouseholdResult switchResult;
  final Future<SwitchActiveHouseholdResult> Function(
    HouseholdId target,
    int expectedVersion,
  )?
  switchCallback;
  HouseholdId? targetHouseholdId;
  int? expectedSelectionVersion;
  var loadCount = 0;
  var switchCount = 0;

  @override
  Future<LoadHouseholdSelectionsResult> load() async {
    loadCount += 1;
    return loadResult;
  }

  @override
  Future<SwitchActiveHouseholdResult> switchActiveHousehold({
    required HouseholdId targetHouseholdId,
    required int expectedSelectionVersion,
  }) async {
    switchCount += 1;
    this.targetHouseholdId = targetHouseholdId;
    this.expectedSelectionVersion = expectedSelectionVersion;
    final callback = switchCallback;
    return callback == null
        ? switchResult
        : callback(targetHouseholdId, expectedSelectionVersion);
  }
}

final class FakeActiveHouseholdCommitter implements ActiveHouseholdCommitter {
  FakeActiveHouseholdCommitter({this.result = true, this.callback});

  final bool result;
  final FutureOr<bool> Function(ActiveHousehold household)? callback;
  final List<ActiveHousehold> households = <ActiveHousehold>[];

  @override
  Future<bool> commitActiveHousehold(ActiveHousehold household) async {
    households.add(household);
    final callback = this.callback;
    return callback == null ? result : callback(household);
  }
}

HouseholdSelectionSnapshot householdSelectionSnapshotFixture({
  int selectionVersion = 4,
}) {
  return HouseholdSelectionSnapshot(
    households: <HouseholdSelection>[
      HouseholdSelection(
        householdId: householdIdFixture(householdSelectionAId),
        memberId: householdMemberIdFixture(householdSelectionAMemberId),
        householdName: 'Alpha family',
        memberRole: HouseholdMemberRole.owner,
        membershipVersion: 2,
        isActive: true,
      ),
      HouseholdSelection(
        householdId: householdIdFixture(householdSelectionBId),
        memberId: householdMemberIdFixture(householdSelectionBMemberId),
        householdName: 'Beta family',
        memberRole: HouseholdMemberRole.member,
        membershipVersion: 3,
        isActive: false,
      ),
    ],
    selectionVersion: selectionVersion,
  );
}

ActiveHousehold switchedActiveHouseholdFixture() {
  return ActiveHousehold(
    householdId: householdIdFixture(householdSelectionBId),
    memberId: householdMemberIdFixture(householdSelectionBMemberId),
  );
}

HouseholdId householdIdFixture(String value) {
  final HouseholdId? id = HouseholdId.tryParse(value);
  if (id == null) {
    throw StateError('Static household selection ID must be a UUID.');
  }
  return id;
}

HouseholdMemberId householdMemberIdFixture(String value) {
  final HouseholdMemberId? id = HouseholdMemberId.tryParse(value);
  if (id == null) {
    throw StateError('Static household selection member ID must be a UUID.');
  }
  return id;
}
