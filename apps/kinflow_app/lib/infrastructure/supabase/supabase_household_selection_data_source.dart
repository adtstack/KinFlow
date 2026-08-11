import 'package:kinflow_app/features/household/data/datasources/household_selection_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseHouseholdSelectionDataSource
    implements HouseholdSelectionDataSource {
  const SupabaseHouseholdSelectionDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<HouseholdSelectionDataResult<List<HouseholdSelectionDataRecord>>>
  load() async {
    try {
      final Object? response = await _client.rpc('list_my_households');
      final List<HouseholdSelectionDataRecord>? records =
          householdSelectionRecordsFromPayload(response);
      return records == null
          ? const HouseholdSelectionDataFailed<
              List<HouseholdSelectionDataRecord>
            >(HouseholdSelectionDataFailureKind.invalidPayload)
          : HouseholdSelectionDataSucceeded<List<HouseholdSelectionDataRecord>>(
              records,
            );
    } on PostgrestException catch (error) {
      return HouseholdSelectionDataFailed<List<HouseholdSelectionDataRecord>>(
        householdSelectionDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const HouseholdSelectionDataFailed<
        List<HouseholdSelectionDataRecord>
      >(HouseholdSelectionDataFailureKind.unauthenticated);
    } on Object {
      return const HouseholdSelectionDataFailed<
        List<HouseholdSelectionDataRecord>
      >(HouseholdSelectionDataFailureKind.temporarilyUnavailable);
    }
  }

  @override
  Future<HouseholdSelectionDataResult<ActiveHouseholdSwitchDataRecord>>
  switchActiveHousehold({
    required String targetHouseholdId,
    required int expectedSelectionVersion,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'switch_active_household',
        params: <String, Object?>{
          'p_target_household_id': targetHouseholdId,
          'p_expected_selection_version': expectedSelectionVersion,
        },
      );
      final ActiveHouseholdSwitchDataRecord? record =
          activeHouseholdSwitchRecordFromPayload(response);
      return record == null
          ? const HouseholdSelectionDataFailed<ActiveHouseholdSwitchDataRecord>(
              HouseholdSelectionDataFailureKind.invalidPayload,
            )
          : HouseholdSelectionDataSucceeded<ActiveHouseholdSwitchDataRecord>(
              record,
            );
    } on PostgrestException catch (error) {
      return HouseholdSelectionDataFailed<ActiveHouseholdSwitchDataRecord>(
        householdSelectionDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const HouseholdSelectionDataFailed<
        ActiveHouseholdSwitchDataRecord
      >(HouseholdSelectionDataFailureKind.unauthenticated);
    } on Object {
      return const HouseholdSelectionDataFailed<
        ActiveHouseholdSwitchDataRecord
      >(HouseholdSelectionDataFailureKind.temporarilyUnavailable);
    }
  }
}

List<HouseholdSelectionDataRecord>? householdSelectionRecordsFromPayload(
  Object? payload,
) {
  if (payload is! List<Object?>) {
    return null;
  }
  final List<HouseholdSelectionDataRecord> records =
      <HouseholdSelectionDataRecord>[];
  for (final Object? rawRow in payload) {
    final Map<String, Object?>? row = _exactMap(rawRow, const <String>{
      'household_id',
      'member_id',
      'household_name',
      'member_role',
      'membership_version',
      'is_active',
      'selection_version',
    });
    if (row == null ||
        row['household_id'] is! String ||
        row['member_id'] is! String ||
        row['household_name'] is! String ||
        row['member_role'] is! String ||
        row['membership_version'] is! int ||
        row['is_active'] is! bool ||
        row['selection_version'] is! int) {
      return null;
    }
    records.add(
      HouseholdSelectionDataRecord(
        householdId: row['household_id']! as String,
        memberId: row['member_id']! as String,
        householdName: row['household_name']! as String,
        memberRole: row['member_role']! as String,
        membershipVersion: row['membership_version']! as int,
        isActive: row['is_active']! as bool,
        selectionVersion: row['selection_version']! as int,
      ),
    );
  }
  return records;
}

ActiveHouseholdSwitchDataRecord? activeHouseholdSwitchRecordFromPayload(
  Object? payload,
) {
  if (payload is! List<Object?> || payload.length != 1) {
    return null;
  }
  final Map<String, Object?>? row = _exactMap(payload.single, const <String>{
    'household_id',
    'member_id',
    'selection_version',
    'changed',
  });
  if (row == null ||
      row['household_id'] is! String ||
      row['member_id'] is! String ||
      row['selection_version'] is! int ||
      row['changed'] is! bool) {
    return null;
  }
  return ActiveHouseholdSwitchDataRecord(
    householdId: row['household_id']! as String,
    memberId: row['member_id']! as String,
    selectionVersion: row['selection_version']! as int,
    changed: row['changed']! as bool,
  );
}

HouseholdSelectionDataFailureKind householdSelectionDataFailureFromProviderCode(
  String? code,
) {
  return switch (code) {
    'KFH01' || 'PGRST301' => HouseholdSelectionDataFailureKind.unauthenticated,
    'KFH02' || '22023' => HouseholdSelectionDataFailureKind.invalidInput,
    'KFH06' => HouseholdSelectionDataFailureKind.targetUnavailable,
    'KFH07' => HouseholdSelectionDataFailureKind.versionConflict,
    'KFR06' => HouseholdSelectionDataFailureKind.featureDisabled,
    'PGRST003' ||
    '57014' => HouseholdSelectionDataFailureKind.temporarilyUnavailable,
    _ => HouseholdSelectionDataFailureKind.unknown,
  };
}

Map<String, Object?>? _exactMap(Object? raw, Set<String> keys) {
  if (raw is! Map || raw.keys.any((Object? key) => key is! String)) {
    return null;
  }
  final Map<String, Object?> row;
  try {
    row = Map<String, Object?>.from(raw);
  } on Object {
    return null;
  }
  return row.length == keys.length && row.keys.toSet().containsAll(keys)
      ? row
      : null;
}
