// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'household_member_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HouseholdMemberRosterRowDto _$HouseholdMemberRosterRowDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'HouseholdMemberRosterRowDto',
  json,
  ($checkedConvert) {
    $checkKeys(
      json,
      allowedKeys: const [
        'household_id',
        'household_name',
        'household_version',
        'member_id',
        'display_name',
        'role',
        'member_version',
        'is_current_user',
      ],
    );
    final val = HouseholdMemberRosterRowDto(
      householdId: $checkedConvert('household_id', (v) => v as String),
      householdName: $checkedConvert('household_name', (v) => v as String),
      householdVersion: $checkedConvert(
        'household_version',
        (v) => _strictIntegerFromJson(v),
      ),
      memberId: $checkedConvert('member_id', (v) => v as String),
      displayName: $checkedConvert('display_name', (v) => v as String),
      role: $checkedConvert('role', (v) => v as String),
      memberVersion: $checkedConvert(
        'member_version',
        (v) => _strictIntegerFromJson(v),
      ),
      isCurrentUser: $checkedConvert('is_current_user', (v) => v as bool),
    );
    return val;
  },
  fieldKeyMap: const {
    'householdId': 'household_id',
    'householdName': 'household_name',
    'householdVersion': 'household_version',
    'memberId': 'member_id',
    'displayName': 'display_name',
    'memberVersion': 'member_version',
    'isCurrentUser': 'is_current_user',
  },
);

HouseholdMemberRoleMutationDto _$HouseholdMemberRoleMutationDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('HouseholdMemberRoleMutationDto', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const ['householdId', 'memberId', 'role', 'version'],
  );
  final val = HouseholdMemberRoleMutationDto(
    householdId: $checkedConvert('householdId', (v) => v as String),
    memberId: $checkedConvert('memberId', (v) => v as String),
    role: $checkedConvert('role', (v) => v as String),
    version: $checkedConvert('version', (v) => _strictIntegerFromJson(v)),
  );
  return val;
});

HouseholdMemberRemovalDto _$HouseholdMemberRemovalDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('HouseholdMemberRemovalDto', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const ['householdId', 'memberId', 'version', 'removedAt'],
  );
  final val = HouseholdMemberRemovalDto(
    householdId: $checkedConvert('householdId', (v) => v as String),
    memberId: $checkedConvert('memberId', (v) => v as String),
    version: $checkedConvert('version', (v) => _strictIntegerFromJson(v)),
    removedAt: $checkedConvert('removedAt', (v) => v as String),
  );
  return val;
});

LeaveHouseholdDto _$LeaveHouseholdDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LeaveHouseholdDto', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'householdId',
          'memberId',
          'version',
          'removedAt',
          'activeHouseholdId',
          'activeMemberId',
        ],
      );
      final val = LeaveHouseholdDto(
        householdId: $checkedConvert('householdId', (v) => v as String),
        memberId: $checkedConvert('memberId', (v) => v as String),
        version: $checkedConvert('version', (v) => _strictIntegerFromJson(v)),
        removedAt: $checkedConvert('removedAt', (v) => v as String),
        activeHouseholdId: $checkedConvert(
          'activeHouseholdId',
          (v) => v as String?,
        ),
        activeMemberId: $checkedConvert('activeMemberId', (v) => v as String?),
      );
      return val;
    });

HouseholdOwnerTransferDto _$HouseholdOwnerTransferDtoFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('HouseholdOwnerTransferDto', json, ($checkedConvert) {
  $checkKeys(
    json,
    allowedKeys: const ['householdId', 'ownerMemberId', 'version'],
  );
  final val = HouseholdOwnerTransferDto(
    householdId: $checkedConvert('householdId', (v) => v as String),
    ownerMemberId: $checkedConvert('ownerMemberId', (v) => v as String),
    version: $checkedConvert('version', (v) => _strictIntegerFromJson(v)),
  );
  return val;
});
