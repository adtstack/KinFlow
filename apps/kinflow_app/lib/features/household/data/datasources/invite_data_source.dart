import 'package:kinflow_app/features/household/data/dto/invite_dto.dart';

enum InviteDataFailureKind {
  unauthenticated,
  invalidInput,
  permissionDenied,
  idempotencyConflict,
  invalid,
  expired,
  revoked,
  alreadyUsed,
  emailMismatch,
  rateLimited,
  profileUnavailable,
  featurePolicyUnavailable,
  featureLimitReached,
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class CreatedInviteRecord {
  const CreatedInviteRecord({
    required this.dto,
    this.rawToken,
    this.rawShortCode,
    this.shortCodeExpiresAt,
  });

  final InviteDto dto;
  final String? rawToken;
  final String? rawShortCode;
  final String? shortCodeExpiresAt;

  @override
  String toString() {
    return 'CreatedInviteRecord(dto: $dto, rawToken: redacted, '
        'rawShortCode: redacted)';
  }
}

abstract interface class InviteDataSource {
  Future<InviteDataResult<CreatedInviteRecord>> createInvite({
    required String idempotencyKey,
    required String householdId,
    required String role,
    required int expiresInHours,
    required String? targetEmail,
  });

  Future<InviteDataResult<InvitePreviewDto>> previewInvite({
    required String token,
  });

  Future<InviteDataResult<InvitePreviewDto>> previewInviteByShortCode({
    required String shortCode,
  });

  Future<InviteDataResult<InviteMemberDto>> acceptInvite({
    required String idempotencyKey,
    required String token,
    required bool setActiveHousehold,
  });

  Future<InviteDataResult<InviteMemberDto>> acceptInviteByShortCode({
    required String idempotencyKey,
    required String shortCode,
    required bool setActiveHousehold,
  });

  Future<InviteDataResult<RevokedInviteDto>> revokeInvite({
    required String idempotencyKey,
    required String householdId,
    required String inviteId,
  });
}

sealed class InviteDataResult<T> {
  const InviteDataResult();
}

final class InviteDataSucceeded<T> extends InviteDataResult<T> {
  const InviteDataSucceeded(this.value);

  final T value;
}

final class InviteDataFailed<T> extends InviteDataResult<T> {
  const InviteDataFailed(this.kind);

  final InviteDataFailureKind kind;
}
