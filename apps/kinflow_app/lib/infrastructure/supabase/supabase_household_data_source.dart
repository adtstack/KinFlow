import 'package:kinflow_app/features/household/data/datasources/household_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseHouseholdDataSource implements HouseholdDataSource {
  const SupabaseHouseholdDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<LoadActiveHouseholdDataResult> loadActiveHousehold() async {
    try {
      final Map<String, dynamic>? row = await _client
          .from('user_active_households')
          .select('household_id,member_id')
          .maybeSingle();
      if (row == null) {
        return const ActiveHouseholdDataAbsent();
      }
      final ActiveHouseholdRecord? record = activeHouseholdRecordFromPayload(
        row,
      );
      return record == null
          ? const LoadActiveHouseholdDataFailed(
              HouseholdDataFailureKind.invalidPayload,
            )
          : ActiveHouseholdDataFound(record);
    } on PostgrestException catch (error) {
      return LoadActiveHouseholdDataFailed(
        householdDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const LoadActiveHouseholdDataFailed(
        HouseholdDataFailureKind.unauthenticated,
      );
    } on Object {
      return const LoadActiveHouseholdDataFailed(
        HouseholdDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<CreateFirstHouseholdDataResult> createFirstHousehold({
    required String idempotencyKey,
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  }) async {
    try {
      final Object? response = await _client.rpc(
        'create_first_household',
        params: <String, Object?>{
          'p_idempotency_key': idempotencyKey,
          'p_household_name': householdName,
          'p_owner_display_name': ownerDisplayName,
          'p_locale': locale,
          'p_timezone': timezone,
        },
      );
      if (response is! List<dynamic> || response.length != 1) {
        return const CreateFirstHouseholdDataFailed(
          HouseholdDataFailureKind.invalidPayload,
        );
      }
      final ActiveHouseholdRecord? record = activeHouseholdRecordFromPayload(
        response.single,
      );
      return record == null
          ? const CreateFirstHouseholdDataFailed(
              HouseholdDataFailureKind.invalidPayload,
            )
          : FirstHouseholdDataCreated(record);
    } on PostgrestException catch (error) {
      return CreateFirstHouseholdDataFailed(
        householdDataFailureFromProviderCode(error.code),
      );
    } on AuthException {
      return const CreateFirstHouseholdDataFailed(
        HouseholdDataFailureKind.unauthenticated,
      );
    } on Object {
      return const CreateFirstHouseholdDataFailed(
        HouseholdDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

ActiveHouseholdRecord? activeHouseholdRecordFromPayload(Object? payload) {
  if (payload is! Map<String, dynamic>) {
    return null;
  }
  final Object? householdId = payload['household_id'];
  final Object? memberId = payload['member_id'] ?? payload['owner_member_id'];
  if (householdId is! String || memberId is! String) {
    return null;
  }
  return ActiveHouseholdRecord(householdId: householdId, memberId: memberId);
}

HouseholdDataFailureKind householdDataFailureFromProviderCode(String? code) {
  return switch (code) {
    'KFH01' || 'PGRST301' => HouseholdDataFailureKind.unauthenticated,
    'KFH02' => HouseholdDataFailureKind.invalidInput,
    'KFH03' => HouseholdDataFailureKind.activeHouseholdExists,
    'KFH04' => HouseholdDataFailureKind.idempotencyConflict,
    'KFH05' => HouseholdDataFailureKind.profileUnavailable,
    _ when code?.startsWith('PGRST') ?? false =>
      HouseholdDataFailureKind.temporarilyUnavailable,
    _ => HouseholdDataFailureKind.unknown,
  };
}
