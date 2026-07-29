import 'package:json_annotation/json_annotation.dart';
import 'package:kinflow_app/features/household/data/datasources/household_member_data_source.dart';
import 'package:kinflow_app/features/household/data/dto/household_member_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseHouseholdMemberDataSource
    implements HouseholdMemberDataSource {
  const SupabaseHouseholdMemberDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<HouseholdMemberDataResult<List<HouseholdMemberRosterRowDto>>>
  loadRoster({required String householdId}) async {
    try {
      final Object? response = await _client.rpc(
        'get_household_member_roster',
        params: <String, Object?>{'p_household_id': householdId},
      );
      if (response is! List<dynamic> || response.isEmpty) {
        return const HouseholdMemberDataFailed<
          List<HouseholdMemberRosterRowDto>
        >(HouseholdMemberDataFailureKind.invalidPayload);
      }
      final List<HouseholdMemberRosterRowDto> rows =
          <HouseholdMemberRosterRowDto>[];
      for (final Object? row in response) {
        if (row is! Map) {
          return const HouseholdMemberDataFailed<
            List<HouseholdMemberRosterRowDto>
          >(HouseholdMemberDataFailureKind.invalidPayload);
        }
        rows.add(
          HouseholdMemberRosterRowDto.fromJson(Map<String, Object?>.from(row)),
        );
      }
      return HouseholdMemberDataSucceeded<List<HouseholdMemberRosterRowDto>>(
        rows,
      );
    } on PostgrestException catch (error) {
      return HouseholdMemberDataFailed<List<HouseholdMemberRosterRowDto>>(
        householdMemberDataFailureFromCode(error.code),
      );
    } on AuthException {
      return const HouseholdMemberDataFailed<List<HouseholdMemberRosterRowDto>>(
        HouseholdMemberDataFailureKind.unauthenticated,
      );
    } on CheckedFromJsonException {
      return const HouseholdMemberDataFailed<List<HouseholdMemberRosterRowDto>>(
        HouseholdMemberDataFailureKind.invalidPayload,
      );
    } on FormatException {
      return const HouseholdMemberDataFailed<List<HouseholdMemberRosterRowDto>>(
        HouseholdMemberDataFailureKind.invalidPayload,
      );
    } on Object {
      return const HouseholdMemberDataFailed<List<HouseholdMemberRosterRowDto>>(
        HouseholdMemberDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<HouseholdMemberDataResult<HouseholdMemberRoleMutationDto>> changeRole({
    required String idempotencyKey,
    required String recentAuthenticationProof,
    required String householdId,
    required String memberId,
    required String role,
    required int expectedVersion,
  }) {
    return _invoke(
      idempotencyKey: idempotencyKey,
      recentAuthenticationProof: recentAuthenticationProof,
      body: <String, Object?>{
        'operation': 'changeRole',
        'householdId': householdId,
        'memberId': memberId,
        'role': role,
        'expectedVersion': expectedVersion,
      },
      parse: HouseholdMemberRoleMutationDto.fromJson,
    );
  }

  @override
  Future<HouseholdMemberDataResult<HouseholdMemberRemovalDto>> removeMember({
    required String idempotencyKey,
    required String householdId,
    required String memberId,
    required int expectedVersion,
  }) {
    return _invoke(
      idempotencyKey: idempotencyKey,
      body: <String, Object?>{
        'operation': 'removeMember',
        'householdId': householdId,
        'memberId': memberId,
        'expectedVersion': expectedVersion,
      },
      parse: HouseholdMemberRemovalDto.fromJson,
    );
  }

  @override
  Future<HouseholdMemberDataResult<LeaveHouseholdDto>> leaveHousehold({
    required String idempotencyKey,
    required String householdId,
    required int expectedVersion,
  }) {
    return _invoke(
      idempotencyKey: idempotencyKey,
      body: <String, Object?>{
        'operation': 'leaveHousehold',
        'householdId': householdId,
        'expectedVersion': expectedVersion,
      },
      parse: LeaveHouseholdDto.fromJson,
    );
  }

  @override
  Future<HouseholdMemberDataResult<HouseholdOwnerTransferDto>> transferOwner({
    required String idempotencyKey,
    required String recentAuthenticationProof,
    required String householdId,
    required String newOwnerMemberId,
    required int expectedVersion,
  }) {
    return _invoke(
      idempotencyKey: idempotencyKey,
      recentAuthenticationProof: recentAuthenticationProof,
      body: <String, Object?>{
        'operation': 'transferOwner',
        'householdId': householdId,
        'newOwnerMemberId': newOwnerMemberId,
        'expectedVersion': expectedVersion,
      },
      parse: HouseholdOwnerTransferDto.fromJson,
    );
  }

  Future<HouseholdMemberDataResult<T>> _invoke<T>({
    required String idempotencyKey,
    required Map<String, Object?> body,
    required T Function(Map<String, Object?> json) parse,
    String? recentAuthenticationProof,
  }) async {
    try {
      final Map<String, String> headers = <String, String>{
        'idempotency-key': idempotencyKey,
      };
      if (recentAuthenticationProof != null) {
        headers['x-kinflow-recent-auth'] = recentAuthenticationProof;
      }
      final FunctionResponse response = await _client.functions.invoke(
        'manage-household-members',
        headers: headers,
        body: body,
      );
      final Map<String, Object?>? data = _dataFromEnvelope(response.data);
      return data == null
          ? HouseholdMemberDataFailed<T>(
              HouseholdMemberDataFailureKind.invalidPayload,
            )
          : HouseholdMemberDataSucceeded<T>(parse(data));
    } on FunctionException catch (error) {
      return HouseholdMemberDataFailed<T>(
        householdMemberDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return HouseholdMemberDataFailed<T>(
        HouseholdMemberDataFailureKind.unauthenticated,
      );
    } on CheckedFromJsonException {
      return HouseholdMemberDataFailed<T>(
        HouseholdMemberDataFailureKind.invalidPayload,
      );
    } on FormatException {
      return HouseholdMemberDataFailed<T>(
        HouseholdMemberDataFailureKind.invalidPayload,
      );
    } on Object {
      return HouseholdMemberDataFailed<T>(
        HouseholdMemberDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

Map<String, Object?>? _dataFromEnvelope(Object? payload) {
  if (payload is! Map || payload['data'] is! Map) {
    return null;
  }
  try {
    return Map<String, Object?>.from(payload['data']! as Map);
  } on Object {
    return null;
  }
}

HouseholdMemberDataFailureKind householdMemberDataFailureFromFunctionDetails(
  Object? details,
) {
  if (details is! Map || details['error'] is! Map) {
    return HouseholdMemberDataFailureKind.unknown;
  }
  final Object? code = (details['error']! as Map)['code'];
  return code is String
      ? householdMemberDataFailureFromCode(code)
      : HouseholdMemberDataFailureKind.unknown;
}

HouseholdMemberDataFailureKind householdMemberDataFailureFromCode(
  String? code,
) {
  return switch (code) {
    'AUTH_REQUIRED' ||
    'KFM01' ||
    'PGRST301' => HouseholdMemberDataFailureKind.unauthenticated,
    'VALIDATION_FAILED' ||
    'IDEMPOTENCY_KEY_REQUIRED' ||
    'KFM02' => HouseholdMemberDataFailureKind.invalidInput,
    'PERMISSION_DENIED' ||
    'KFM03' => HouseholdMemberDataFailureKind.permissionDenied,
    'IDEMPOTENCY_KEY_REUSED' ||
    'KFM04' => HouseholdMemberDataFailureKind.idempotencyConflict,
    'NOT_FOUND_OR_FORBIDDEN' ||
    'KFM05' => HouseholdMemberDataFailureKind.notFound,
    'VERSION_CONFLICT' ||
    'KFM06' => HouseholdMemberDataFailureKind.versionConflict,
    'ROLE_NOT_ALLOWED' ||
    'KFM07' => HouseholdMemberDataFailureKind.roleNotAllowed,
    'OWNER_TRANSFER_REQUIRED' ||
    'KFM08' => HouseholdMemberDataFailureKind.ownerTransferRequired,
    'RECENT_AUTH_REQUIRED' =>
      HouseholdMemberDataFailureKind.recentAuthenticationRequired,
    'TEMPORARILY_UNAVAILABLE' =>
      HouseholdMemberDataFailureKind.temporarilyUnavailable,
    _ when code?.startsWith('PGRST') ?? false =>
      HouseholdMemberDataFailureKind.temporarilyUnavailable,
    _ => HouseholdMemberDataFailureKind.unknown,
  };
}
