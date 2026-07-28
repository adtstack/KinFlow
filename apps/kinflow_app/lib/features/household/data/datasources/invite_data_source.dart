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
  temporarilyUnavailable,
  invalidPayload,
  unknown,
}

final class CreatedInviteRecord {
  const CreatedInviteRecord({required this.dto, this.rawToken});

  final InviteDto dto;
  final String? rawToken;

  @override
  String toString() => 'CreatedInviteRecord(dto: $dto, rawToken: redacted)';
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

  Future<InviteDataResult<InviteMemberDto>> acceptInvite({
    required String idempotencyKey,
    required String token,
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
