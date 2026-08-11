import 'package:kinflow_app/features/household/data/datasources/household_selection_data_source.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/entities/household_selection.dart';
import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ProviderHouseholdSelectionRepository
    implements HouseholdSelectionRepository {
  const ProviderHouseholdSelectionRepository(this._dataSource);

  final HouseholdSelectionDataSource _dataSource;

  @override
  Future<LoadHouseholdSelectionsResult> load() async {
    final HouseholdSelectionDataResult<List<HouseholdSelectionDataRecord>>
    result = await _dataSource.load();
    return switch (result) {
      HouseholdSelectionDataSucceeded<List<HouseholdSelectionDataRecord>>(
        :final value,
      ) =>
        _mapSnapshot(value),
      HouseholdSelectionDataFailed<List<HouseholdSelectionDataRecord>>(
        :final kind,
      ) =>
        LoadHouseholdSelectionsFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<SwitchActiveHouseholdResult> switchActiveHousehold({
    required HouseholdId targetHouseholdId,
    required int expectedSelectionVersion,
  }) async {
    if (expectedSelectionVersion < 0) {
      return const SwitchActiveHouseholdFailed(
        HouseholdSelectionFailure(HouseholdSelectionFailureKind.invalidInput),
      );
    }
    final HouseholdSelectionDataResult<ActiveHouseholdSwitchDataRecord> result =
        await _dataSource.switchActiveHousehold(
          targetHouseholdId: targetHouseholdId.value,
          expectedSelectionVersion: expectedSelectionVersion,
        );
    return switch (result) {
      HouseholdSelectionDataSucceeded<ActiveHouseholdSwitchDataRecord>(
        :final value,
      ) =>
        _mapCommit(value, targetHouseholdId, expectedSelectionVersion),
      HouseholdSelectionDataFailed<ActiveHouseholdSwitchDataRecord>(
        :final kind,
      ) =>
        SwitchActiveHouseholdFailed(_mapFailure(kind)),
    };
  }

  LoadHouseholdSelectionsResult _mapSnapshot(
    List<HouseholdSelectionDataRecord> rows,
  ) {
    if (rows.isEmpty) {
      return HouseholdSelectionsLoaded(
        HouseholdSelectionSnapshot(
          households: const <HouseholdSelection>[],
          selectionVersion: 0,
        ),
      );
    }
    final int selectionVersion = rows.first.selectionVersion;
    if (selectionVersion < 0 ||
        rows.any(
          (HouseholdSelectionDataRecord row) =>
              row.selectionVersion != selectionVersion,
        )) {
      return _invalidLoad();
    }

    final List<HouseholdSelection> households = <HouseholdSelection>[];
    final Set<String> householdIds = <String>{};
    var activeCount = 0;
    for (final HouseholdSelectionDataRecord row in rows) {
      final HouseholdId? householdId = HouseholdId.tryParse(row.householdId);
      final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
        row.memberId,
      );
      final HouseholdMemberRole? role = switch (row.memberRole) {
        'owner' => HouseholdMemberRole.owner,
        'admin' => HouseholdMemberRole.admin,
        'member' => HouseholdMemberRole.member,
        _ => null,
      };
      final String name = row.householdName.trim();
      if (householdId == null ||
          memberId == null ||
          role == null ||
          !householdIds.add(householdId.value) ||
          name.isEmpty ||
          name.length > 80 ||
          row.householdName != name ||
          row.membershipVersion < 1) {
        return _invalidLoad();
      }
      if (row.isActive) {
        activeCount += 1;
      }
      households.add(
        HouseholdSelection(
          householdId: householdId,
          memberId: memberId,
          householdName: name,
          memberRole: role,
          membershipVersion: row.membershipVersion,
          isActive: row.isActive,
        ),
      );
    }
    if (activeCount > 1 ||
        (selectionVersion == 0 && activeCount != 0) ||
        (selectionVersion > 0 && activeCount != 1)) {
      return _invalidLoad();
    }
    return HouseholdSelectionsLoaded(
      HouseholdSelectionSnapshot(
        households: households,
        selectionVersion: selectionVersion,
      ),
    );
  }

  SwitchActiveHouseholdResult _mapCommit(
    ActiveHouseholdSwitchDataRecord row,
    HouseholdId expectedHouseholdId,
    int expectedSelectionVersion,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(row.householdId);
    final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
      row.memberId,
    );
    if (householdId == null ||
        memberId == null ||
        householdId != expectedHouseholdId ||
        row.selectionVersion < 1 ||
        (row.changed && row.selectionVersion != expectedSelectionVersion + 1)) {
      return const SwitchActiveHouseholdFailed(
        HouseholdSelectionFailure(HouseholdSelectionFailureKind.invalidPayload),
      );
    }
    return ActiveHouseholdSwitched(
      HouseholdSelectionCommit(
        activeHousehold: ActiveHousehold(
          householdId: householdId,
          memberId: memberId,
        ),
        selectionVersion: row.selectionVersion,
        changed: row.changed,
      ),
    );
  }

  LoadHouseholdSelectionsResult _invalidLoad() {
    return const LoadHouseholdSelectionsFailed(
      HouseholdSelectionFailure(HouseholdSelectionFailureKind.invalidPayload),
    );
  }

  HouseholdSelectionFailure _mapFailure(
    HouseholdSelectionDataFailureKind kind,
  ) {
    return HouseholdSelectionFailure(switch (kind) {
      HouseholdSelectionDataFailureKind.unauthenticated =>
        HouseholdSelectionFailureKind.unauthenticated,
      HouseholdSelectionDataFailureKind.invalidInput =>
        HouseholdSelectionFailureKind.invalidInput,
      HouseholdSelectionDataFailureKind.targetUnavailable =>
        HouseholdSelectionFailureKind.targetUnavailable,
      HouseholdSelectionDataFailureKind.versionConflict =>
        HouseholdSelectionFailureKind.versionConflict,
      HouseholdSelectionDataFailureKind.featureDisabled =>
        HouseholdSelectionFailureKind.featureDisabled,
      HouseholdSelectionDataFailureKind.temporarilyUnavailable =>
        HouseholdSelectionFailureKind.temporarilyUnavailable,
      HouseholdSelectionDataFailureKind.invalidPayload =>
        HouseholdSelectionFailureKind.invalidPayload,
      HouseholdSelectionDataFailureKind.unknown =>
        HouseholdSelectionFailureKind.internal,
    });
  }
}
