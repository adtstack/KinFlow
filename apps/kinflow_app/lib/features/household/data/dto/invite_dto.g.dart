// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invite_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InviteDto _$InviteDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_InviteDto', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const ['id', 'householdId', 'role', 'expiresAt', 'status'],
      );
      final val = _InviteDto(
        id: $checkedConvert('id', (v) => v as String),
        householdId: $checkedConvert('householdId', (v) => v as String),
        role: $checkedConvert('role', (v) => v as String),
        expiresAt: $checkedConvert('expiresAt', (v) => v as String),
        status: $checkedConvert('status', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$InviteDtoToJson(_InviteDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'householdId': instance.householdId,
      'role': instance.role,
      'expiresAt': instance.expiresAt,
      'status': instance.status,
    };

_InvitePreviewDto _$InvitePreviewDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_InvitePreviewDto', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'valid',
          'householdDisplayName',
          'inviterDisplayName',
          'role',
          'expiresAt',
        ],
      );
      final val = _InvitePreviewDto(
        valid: $checkedConvert('valid', (v) => v as bool),
        householdDisplayName: $checkedConvert(
          'householdDisplayName',
          (v) => v as String,
        ),
        inviterDisplayName: $checkedConvert(
          'inviterDisplayName',
          (v) => v as String,
        ),
        role: $checkedConvert('role', (v) => v as String),
        expiresAt: $checkedConvert('expiresAt', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$InvitePreviewDtoToJson(_InvitePreviewDto instance) =>
    <String, dynamic>{
      'valid': instance.valid,
      'householdDisplayName': instance.householdDisplayName,
      'inviterDisplayName': instance.inviterDisplayName,
      'role': instance.role,
      'expiresAt': instance.expiresAt,
    };

_InviteMemberDto _$InviteMemberDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_InviteMemberDto', json, ($checkedConvert) {
      $checkKeys(
        json,
        allowedKeys: const [
          'id',
          'householdId',
          'displayName',
          'role',
          'activeHouseholdSet',
        ],
      );
      final val = _InviteMemberDto(
        id: $checkedConvert('id', (v) => v as String),
        householdId: $checkedConvert('householdId', (v) => v as String),
        displayName: $checkedConvert('displayName', (v) => v as String),
        role: $checkedConvert('role', (v) => v as String),
        activeHouseholdSet: $checkedConvert(
          'activeHouseholdSet',
          (v) => v as bool,
        ),
      );
      return val;
    });

Map<String, dynamic> _$InviteMemberDtoToJson(_InviteMemberDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'householdId': instance.householdId,
      'displayName': instance.displayName,
      'role': instance.role,
      'activeHouseholdSet': instance.activeHouseholdSet,
    };

_RevokedInviteDto _$RevokedInviteDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_RevokedInviteDto', json, ($checkedConvert) {
      $checkKeys(json, allowedKeys: const ['id', 'householdId', 'status']);
      final val = _RevokedInviteDto(
        id: $checkedConvert('id', (v) => v as String),
        householdId: $checkedConvert('householdId', (v) => v as String),
        status: $checkedConvert('status', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$RevokedInviteDtoToJson(_RevokedInviteDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'householdId': instance.householdId,
      'status': instance.status,
    };
