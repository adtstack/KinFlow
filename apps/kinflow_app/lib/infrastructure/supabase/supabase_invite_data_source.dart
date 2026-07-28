import 'package:json_annotation/json_annotation.dart';
import 'package:kinflow_app/features/household/data/datasources/invite_data_source.dart';
import 'package:kinflow_app/features/household/data/dto/invite_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseInviteDataSource implements InviteDataSource {
  const SupabaseInviteDataSource(this._client);

  final SupabaseClient _client;

  @override
  Future<InviteDataResult<CreatedInviteRecord>> createInvite({
    required String idempotencyKey,
    required String householdId,
    required String role,
    required int expiresInHours,
    required String? targetEmail,
  }) async {
    try {
      final Map<String, Object?> body = <String, Object?>{
        'householdId': householdId,
        'role': role,
        'expiresInHours': expiresInHours,
      };
      if (targetEmail != null) {
        body['targetEmail'] = targetEmail;
      }
      final FunctionResponse response = await _client.functions.invoke(
        'create-invite',
        headers: <String, String>{'idempotency-key': idempotencyKey},
        body: body,
      );
      final Map<String, Object?>? data = inviteDataFromEnvelope(response.data);
      if (data == null ||
          !hasExactCreatedInviteKeys(data, const <String>{
            'id',
            'householdId',
            'role',
            'expiresAt',
            'status',
            'rawToken',
          })) {
        return const InviteDataFailed<CreatedInviteRecord>(
          InviteDataFailureKind.invalidPayload,
        );
      }
      final Object? rawTokenValue = data.remove('rawToken');
      if (rawTokenValue != null && rawTokenValue is! String) {
        return const InviteDataFailed<CreatedInviteRecord>(
          InviteDataFailureKind.invalidPayload,
        );
      }
      return InviteDataSucceeded<CreatedInviteRecord>(
        CreatedInviteRecord(
          dto: InviteDto.fromJson(data),
          rawToken: rawTokenValue as String?,
        ),
      );
    } on FunctionException catch (error) {
      return InviteDataFailed<CreatedInviteRecord>(
        inviteDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return const InviteDataFailed<CreatedInviteRecord>(
        InviteDataFailureKind.unauthenticated,
      );
    } on CheckedFromJsonException {
      return const InviteDataFailed<CreatedInviteRecord>(
        InviteDataFailureKind.invalidPayload,
      );
    } on Object {
      return const InviteDataFailed<CreatedInviteRecord>(
        InviteDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<InviteDataResult<InvitePreviewDto>> previewInvite({
    required String token,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'preview-invite',
        body: <String, Object?>{'token': token},
      );
      final Map<String, Object?>? data = inviteDataFromEnvelope(response.data);
      if (data == null) {
        return const InviteDataFailed<InvitePreviewDto>(
          InviteDataFailureKind.invalidPayload,
        );
      }
      return InviteDataSucceeded<InvitePreviewDto>(
        InvitePreviewDto.fromJson(data),
      );
    } on FunctionException catch (error) {
      return InviteDataFailed<InvitePreviewDto>(
        inviteDataFailureFromFunctionDetails(error.details),
      );
    } on CheckedFromJsonException {
      return const InviteDataFailed<InvitePreviewDto>(
        InviteDataFailureKind.invalidPayload,
      );
    } on Object {
      return const InviteDataFailed<InvitePreviewDto>(
        InviteDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<InviteDataResult<InviteMemberDto>> acceptInvite({
    required String idempotencyKey,
    required String token,
    required bool setActiveHousehold,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'accept-invite',
        headers: <String, String>{'idempotency-key': idempotencyKey},
        body: <String, Object?>{
          'token': token,
          'setActiveHousehold': setActiveHousehold,
        },
      );
      final Map<String, Object?>? data = inviteDataFromEnvelope(response.data);
      if (data == null) {
        return const InviteDataFailed<InviteMemberDto>(
          InviteDataFailureKind.invalidPayload,
        );
      }
      return InviteDataSucceeded<InviteMemberDto>(
        InviteMemberDto.fromJson(data),
      );
    } on FunctionException catch (error) {
      return InviteDataFailed<InviteMemberDto>(
        inviteDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return const InviteDataFailed<InviteMemberDto>(
        InviteDataFailureKind.unauthenticated,
      );
    } on CheckedFromJsonException {
      return const InviteDataFailed<InviteMemberDto>(
        InviteDataFailureKind.invalidPayload,
      );
    } on Object {
      return const InviteDataFailed<InviteMemberDto>(
        InviteDataFailureKind.temporarilyUnavailable,
      );
    }
  }

  @override
  Future<InviteDataResult<RevokedInviteDto>> revokeInvite({
    required String idempotencyKey,
    required String householdId,
    required String inviteId,
  }) async {
    try {
      final FunctionResponse response = await _client.functions.invoke(
        'revoke-invite',
        headers: <String, String>{'idempotency-key': idempotencyKey},
        body: <String, Object?>{
          'householdId': householdId,
          'inviteId': inviteId,
        },
      );
      final Map<String, Object?>? data = inviteDataFromEnvelope(response.data);
      if (data == null) {
        return const InviteDataFailed<RevokedInviteDto>(
          InviteDataFailureKind.invalidPayload,
        );
      }
      return InviteDataSucceeded<RevokedInviteDto>(
        RevokedInviteDto.fromJson(data),
      );
    } on FunctionException catch (error) {
      return InviteDataFailed<RevokedInviteDto>(
        inviteDataFailureFromFunctionDetails(error.details),
      );
    } on AuthException {
      return const InviteDataFailed<RevokedInviteDto>(
        InviteDataFailureKind.unauthenticated,
      );
    } on CheckedFromJsonException {
      return const InviteDataFailed<RevokedInviteDto>(
        InviteDataFailureKind.invalidPayload,
      );
    } on Object {
      return const InviteDataFailed<RevokedInviteDto>(
        InviteDataFailureKind.temporarilyUnavailable,
      );
    }
  }
}

Map<String, Object?>? inviteDataFromEnvelope(Object? payload) {
  if (payload is! Map) {
    return null;
  }
  final Object? data = payload['data'];
  if (data is! Map) {
    return null;
  }
  try {
    return Map<String, Object?>.from(data);
  } on Object {
    return null;
  }
}

bool hasExactCreatedInviteKeys(Map<String, Object?> data, Set<String> allowed) {
  return data.keys.every(allowed.contains) &&
      const <String>{
        'id',
        'householdId',
        'role',
        'expiresAt',
        'status',
      }.every(data.containsKey);
}

InviteDataFailureKind inviteDataFailureFromFunctionDetails(Object? details) {
  if (details is! Map) {
    return InviteDataFailureKind.unknown;
  }
  final Object? error = details['error'];
  if (error is! Map || error['code'] is! String) {
    return InviteDataFailureKind.unknown;
  }
  return switch (error['code']) {
    'AUTH_REQUIRED' => InviteDataFailureKind.unauthenticated,
    'VALIDATION_FAILED' ||
    'IDEMPOTENCY_KEY_REQUIRED' => InviteDataFailureKind.invalidInput,
    'PERMISSION_DENIED' => InviteDataFailureKind.permissionDenied,
    'IDEMPOTENCY_KEY_REUSED' => InviteDataFailureKind.idempotencyConflict,
    'INVITE_INVALID' => InviteDataFailureKind.invalid,
    'INVITE_EXPIRED' => InviteDataFailureKind.expired,
    'INVITE_REVOKED' => InviteDataFailureKind.revoked,
    'INVITE_ALREADY_USED' => InviteDataFailureKind.alreadyUsed,
    'INVITE_EMAIL_MISMATCH' => InviteDataFailureKind.emailMismatch,
    'RATE_LIMITED' => InviteDataFailureKind.rateLimited,
    'PROFILE_UNAVAILABLE' => InviteDataFailureKind.profileUnavailable,
    'CAPABILITY_UNSUPPORTED' => InviteDataFailureKind.invalidInput,
    'TEMPORARILY_UNAVAILABLE' => InviteDataFailureKind.temporarilyUnavailable,
    _ => InviteDataFailureKind.unknown,
  };
}
