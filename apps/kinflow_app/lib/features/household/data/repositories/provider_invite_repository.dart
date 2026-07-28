import 'package:kinflow_app/features/household/data/datasources/invite_data_source.dart';
import 'package:kinflow_app/features/household/data/dto/invite_dto.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite_request.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class ProviderInviteRepository implements InviteRepository {
  const ProviderInviteRepository(this._dataSource);

  final InviteDataSource _dataSource;

  @override
  Future<CreateHouseholdInviteResult> createInvite(
    CreateHouseholdInviteRequest request,
  ) async {
    final InviteDataResult<CreatedInviteRecord> result = await _dataSource
        .createInvite(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          role: request.role.name,
          expiresInHours: request.expiresInHours,
          targetEmail: request.targetEmail,
        );
    return switch (result) {
      InviteDataSucceeded<CreatedInviteRecord>(:final value) => _mapCreated(
        value,
      ),
      InviteDataFailed<CreatedInviteRecord>(:final kind) =>
        CreateHouseholdInviteFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<PreviewHouseholdInviteResult> previewInvite(InviteToken token) async {
    final InviteDataResult<InvitePreviewDto> result = await _dataSource
        .previewInvite(token: token.value);
    return switch (result) {
      InviteDataSucceeded<InvitePreviewDto>(:final value) => _mapPreview(value),
      InviteDataFailed<InvitePreviewDto>(:final kind) =>
        PreviewHouseholdInviteFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<AcceptHouseholdInviteResult> acceptInvite(
    AcceptHouseholdInviteRequest request,
  ) async {
    final InviteDataResult<InviteMemberDto> result = await _dataSource
        .acceptInvite(
          idempotencyKey: request.idempotencyKey.value,
          token: request.token.value,
          setActiveHousehold: request.setActiveHousehold,
        );
    return switch (result) {
      InviteDataSucceeded<InviteMemberDto>(:final value) => _mapAccepted(value),
      InviteDataFailed<InviteMemberDto>(:final kind) =>
        AcceptHouseholdInviteFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<RevokeHouseholdInviteResult> revokeInvite(
    RevokeHouseholdInviteRequest request,
  ) async {
    final InviteDataResult<RevokedInviteDto> result = await _dataSource
        .revokeInvite(
          idempotencyKey: request.idempotencyKey.value,
          householdId: request.householdId.value,
          inviteId: request.inviteId.value,
        );
    return switch (result) {
      InviteDataSucceeded<RevokedInviteDto>(:final value) => _mapRevoked(value),
      InviteDataFailed<RevokedInviteDto>(:final kind) =>
        RevokeHouseholdInviteFailed(_mapFailure(kind)),
    };
  }

  CreateHouseholdInviteResult _mapCreated(CreatedInviteRecord record) {
    final InviteDto dto = record.dto;
    final InviteId? id = InviteId.tryParse(dto.id);
    final HouseholdId? householdId = HouseholdId.tryParse(dto.householdId);
    final HouseholdInviteRole? role = _role(dto.role);
    final HouseholdInviteStatus? status = _status(dto.status);
    final DateTime? expiresAt = DateTime.tryParse(dto.expiresAt)?.toUtc();
    final InviteToken? token = record.rawToken == null
        ? null
        : InviteToken.tryParse(record.rawToken!);
    if (id == null ||
        householdId == null ||
        role == null ||
        status == null ||
        expiresAt == null ||
        record.rawToken != null && token == null) {
      return const CreateHouseholdInviteFailed(
        InviteFailure(InviteFailureKind.invalidPayload),
      );
    }
    return HouseholdInviteCreated(
      HouseholdInvite(
        id: id,
        householdId: householdId,
        role: role,
        expiresAt: expiresAt,
        status: status,
        rawToken: token,
      ),
    );
  }

  PreviewHouseholdInviteResult _mapPreview(InvitePreviewDto dto) {
    final HouseholdInviteRole? role = _role(dto.role);
    final DateTime? expiresAt = DateTime.tryParse(dto.expiresAt)?.toUtc();
    if (!dto.valid ||
        dto.householdDisplayName.trim().isEmpty ||
        dto.inviterDisplayName.trim().isEmpty ||
        role == null ||
        expiresAt == null) {
      return const PreviewHouseholdInviteFailed(
        InviteFailure(InviteFailureKind.invalidPayload),
      );
    }
    return HouseholdInvitePreviewed(
      HouseholdInvitePreview(
        householdDisplayName: dto.householdDisplayName,
        inviterDisplayName: dto.inviterDisplayName,
        role: role,
        expiresAt: expiresAt,
      ),
    );
  }

  AcceptHouseholdInviteResult _mapAccepted(InviteMemberDto dto) {
    final HouseholdId? householdId = HouseholdId.tryParse(dto.householdId);
    final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(dto.id);
    final HouseholdInviteRole? role = _role(dto.role);
    if (householdId == null ||
        memberId == null ||
        dto.displayName.trim().isEmpty ||
        role == null) {
      return const AcceptHouseholdInviteFailed(
        InviteFailure(InviteFailureKind.invalidPayload),
      );
    }
    return HouseholdInviteAccepted(
      AcceptedHouseholdInvite(
        household: ActiveHousehold(
          householdId: householdId,
          memberId: memberId,
        ),
        displayName: dto.displayName,
        role: role,
        activeHouseholdSet: dto.activeHouseholdSet,
      ),
    );
  }

  RevokeHouseholdInviteResult _mapRevoked(RevokedInviteDto dto) {
    final InviteId? id = InviteId.tryParse(dto.id);
    if (id == null ||
        HouseholdId.tryParse(dto.householdId) == null ||
        dto.status != HouseholdInviteStatus.revoked.name) {
      return const RevokeHouseholdInviteFailed(
        InviteFailure(InviteFailureKind.invalidPayload),
      );
    }
    return HouseholdInviteRevoked(id);
  }

  HouseholdInviteRole? _role(String value) {
    return switch (value) {
      'admin' => HouseholdInviteRole.admin,
      'member' => HouseholdInviteRole.member,
      _ => null,
    };
  }

  HouseholdInviteStatus? _status(String value) {
    return switch (value) {
      'active' => HouseholdInviteStatus.active,
      'accepted' => HouseholdInviteStatus.accepted,
      'revoked' => HouseholdInviteStatus.revoked,
      'expired' => HouseholdInviteStatus.expired,
      _ => null,
    };
  }

  InviteFailure _mapFailure(InviteDataFailureKind kind) {
    return InviteFailure(switch (kind) {
      InviteDataFailureKind.unauthenticated =>
        InviteFailureKind.unauthenticated,
      InviteDataFailureKind.invalidInput => InviteFailureKind.invalidInput,
      InviteDataFailureKind.permissionDenied =>
        InviteFailureKind.permissionDenied,
      InviteDataFailureKind.idempotencyConflict =>
        InviteFailureKind.idempotencyConflict,
      InviteDataFailureKind.invalid => InviteFailureKind.invalid,
      InviteDataFailureKind.expired => InviteFailureKind.expired,
      InviteDataFailureKind.revoked => InviteFailureKind.revoked,
      InviteDataFailureKind.alreadyUsed => InviteFailureKind.alreadyUsed,
      InviteDataFailureKind.emailMismatch => InviteFailureKind.emailMismatch,
      InviteDataFailureKind.rateLimited => InviteFailureKind.rateLimited,
      InviteDataFailureKind.profileUnavailable =>
        InviteFailureKind.profileUnavailable,
      InviteDataFailureKind.temporarilyUnavailable =>
        InviteFailureKind.temporarilyUnavailable,
      InviteDataFailureKind.invalidPayload => InviteFailureKind.invalidPayload,
      InviteDataFailureKind.unknown => InviteFailureKind.internal,
    });
  }
}
