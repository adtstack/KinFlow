import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/data/datasources/household_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_household_data_source.dart';

void main() {
  group('SupabaseHouseholdDataSource contract mapping', () {
    test('accepts active selection and RPC owner result field names', () {
      final ActiveHouseholdRecord? selection =
          activeHouseholdRecordFromPayload(const <String, dynamic>{
            'household_id': '22222222-2222-4222-8222-222222222222',
            'member_id': '33333333-3333-4333-8333-333333333333',
          });
      final ActiveHouseholdRecord? command =
          activeHouseholdRecordFromPayload(const <String, dynamic>{
            'household_id': '22222222-2222-4222-8222-222222222222',
            'owner_member_id': '33333333-3333-4333-8333-333333333333',
          });

      expect(selection?.memberId, command?.memberId);
      expect(selection?.householdId, command?.householdId);
    });

    test('rejects missing, mistyped, and non-object provider payloads', () {
      expect(activeHouseholdRecordFromPayload(null), isNull);
      expect(activeHouseholdRecordFromPayload(const <Object>[]), isNull);
      expect(
        activeHouseholdRecordFromPayload(const <String, dynamic>{
          'household_id': 7,
          'member_id': '33333333-3333-4333-8333-333333333333',
        }),
        isNull,
      );
      expect(
        activeHouseholdRecordFromPayload(const <String, dynamic>{
          'household_id': '22222222-2222-4222-8222-222222222222',
        }),
        isNull,
      );
    });

    test('maps custom SQLSTATEs and PostgREST failures to stable kinds', () {
      expect(
        householdDataFailureFromProviderCode('KFH01'),
        HouseholdDataFailureKind.unauthenticated,
      );
      expect(
        householdDataFailureFromProviderCode('KFH02'),
        HouseholdDataFailureKind.invalidInput,
      );
      expect(
        householdDataFailureFromProviderCode('KFH03'),
        HouseholdDataFailureKind.activeHouseholdExists,
      );
      expect(
        householdDataFailureFromProviderCode('KFH04'),
        HouseholdDataFailureKind.idempotencyConflict,
      );
      expect(
        householdDataFailureFromProviderCode('KFH05'),
        HouseholdDataFailureKind.profileUnavailable,
      );
      expect(
        householdDataFailureFromProviderCode('PGRST116'),
        HouseholdDataFailureKind.temporarilyUnavailable,
      );
      expect(
        householdDataFailureFromProviderCode(null),
        HouseholdDataFailureKind.unknown,
      );
    });
  });
}
