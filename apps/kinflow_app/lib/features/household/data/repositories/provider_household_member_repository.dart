import 'package:kinflow_app/features/household/data/datasources/household_member_data_source.dart';
import 'package:kinflow_app/features/household/data/dto/household_member_dto.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member_command.dart';
import 'package:kinflow_app/features/household/domain/failures/household_member_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ProviderHouseholdMemberRepository
    implements HouseholdMemberRepository {
  const ProviderHouseholdMemberRepository(this._dataSource);

  final HouseholdMemberDataSource _dataSource;

  @override
  Future<LoadHouseholdMemberRosterResult> loadRoster(
    HouseholdId householdId,
  ) async {
    final HouseholdMemberDataResult<List<HouseholdMemberRosterRowDto>> result =
        await _dataSource.loadRoster(householdId: householdId.value);
    return switch (result) {
      HouseholdMemberDataSucceeded<List<HouseholdMemberRosterRowDto>>(
        :final value,
      ) =>
        _mapRoster(value),
      HouseholdMemberDataFailed<List<HouseholdMemberRosterRowDto>>(
        :final kind,
      ) =>
        LoadHouseholdMemberRosterFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<HouseholdMemberCommandResult> changeRole(
    ChangeHouseholdMemberRoleCommand command,
  ) async {
    final HouseholdMemberDataResult<HouseholdMemberRoleMutationDto> result =
        await _dataSource.changeRole(
          idempotencyKey: command.idempotencyKey.value,
          recentAuthenticationProof: command.recentAuthenticationProof.value,
          householdId: command.householdId.value,
          memberId: command.memberId.value,
          role: command.role.name,
          expectedVersion: command.expectedVersion,
        );
    return switch (result) {
      HouseholdMemberDataSucceeded<HouseholdMemberRoleMutationDto>(
        :final value,
      ) =>
        _validRoleMutation(value, command)
            ? const HouseholdMemberCommandCompleted()
            : _invalidPayload(),
      HouseholdMemberDataFailed<HouseholdMemberRoleMutationDto>(:final kind) =>
        HouseholdMemberCommandFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<HouseholdMemberCommandResult> removeMember(
    RemoveHouseholdMemberCommand command,
  ) async {
    final HouseholdMemberDataResult<HouseholdMemberRemovalDto> result =
        await _dataSource.removeMember(
          idempotencyKey: command.idempotencyKey.value,
          householdId: command.householdId.value,
          memberId: command.memberId.value,
          expectedVersion: command.expectedVersion,
        );
    return switch (result) {
      HouseholdMemberDataSucceeded<HouseholdMemberRemovalDto>(:final value) =>
        _validRemoval(value, command)
            ? const HouseholdMemberCommandCompleted()
            : _invalidPayload(),
      HouseholdMemberDataFailed<HouseholdMemberRemovalDto>(:final kind) =>
        HouseholdMemberCommandFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<HouseholdMemberCommandResult> leaveHousehold(
    LeaveHouseholdCommand command,
  ) async {
    final HouseholdMemberDataResult<LeaveHouseholdDto> result =
        await _dataSource.leaveHousehold(
          idempotencyKey: command.idempotencyKey.value,
          householdId: command.householdId.value,
          expectedVersion: command.expectedVersion,
        );
    return switch (result) {
      HouseholdMemberDataSucceeded<LeaveHouseholdDto>(:final value) =>
        _mapLeave(value, command),
      HouseholdMemberDataFailed<LeaveHouseholdDto>(:final kind) =>
        HouseholdMemberCommandFailed(_mapFailure(kind)),
    };
  }

  @override
  Future<HouseholdMemberCommandResult> transferOwner(
    TransferHouseholdOwnerCommand command,
  ) async {
    final HouseholdMemberDataResult<HouseholdOwnerTransferDto> result =
        await _dataSource.transferOwner(
          idempotencyKey: command.idempotencyKey.value,
          recentAuthenticationProof: command.recentAuthenticationProof.value,
          householdId: command.householdId.value,
          newOwnerMemberId: command.newOwnerMemberId.value,
          expectedVersion: command.expectedVersion,
        );
    return switch (result) {
      HouseholdMemberDataSucceeded<HouseholdOwnerTransferDto>(:final value) =>
        _validOwnerTransfer(value, command)
            ? const HouseholdMemberCommandCompleted()
            : _invalidPayload(),
      HouseholdMemberDataFailed<HouseholdOwnerTransferDto>(:final kind) =>
        HouseholdMemberCommandFailed(_mapFailure(kind)),
    };
  }

  LoadHouseholdMemberRosterResult _mapRoster(
    List<HouseholdMemberRosterRowDto> rows,
  ) {
    if (rows.isEmpty) {
      return _invalidRoster();
    }
    final HouseholdId? householdId = HouseholdId.tryParse(
      rows.first.householdId,
    );
    final String householdName = rows.first.householdName.trim();
    final int householdVersion = rows.first.householdVersion;
    if (householdId == null ||
        householdName.isEmpty ||
        householdName.length > 80 ||
        householdVersion < 1) {
      return _invalidRoster();
    }

    final List<HouseholdMember> members = <HouseholdMember>[];
    final Set<String> memberIds = <String>{};
    for (final HouseholdMemberRosterRowDto row in rows) {
      if (row.householdId.toLowerCase() != householdId.value ||
          row.householdName != rows.first.householdName ||
          row.householdVersion != householdVersion) {
        return _invalidRoster();
      }
      final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
        row.memberId,
      );
      final HouseholdMemberRole? role = _role(row.role);
      final String displayName = row.displayName.trim();
      if (memberId == null ||
          !memberIds.add(memberId.value) ||
          role == null ||
          displayName.isEmpty ||
          displayName.length > 80 ||
          row.memberVersion < 1) {
        return _invalidRoster();
      }
      members.add(
        HouseholdMember(
          id: memberId,
          displayName: displayName,
          role: role,
          version: row.memberVersion,
          isCurrentUser: row.isCurrentUser,
        ),
      );
    }

    if (members
                .where((HouseholdMember member) => member.isCurrentUser)
                .length !=
            1 ||
        members
                .where(
                  (HouseholdMember member) =>
                      member.role == HouseholdMemberRole.owner,
                )
                .length !=
            1) {
      return _invalidRoster();
    }
    return HouseholdMemberRosterLoaded(
      HouseholdMemberRoster(
        householdId: householdId,
        householdName: householdName,
        householdVersion: householdVersion,
        members: members,
      ),
    );
  }

  bool _validRoleMutation(
    HouseholdMemberRoleMutationDto dto,
    ChangeHouseholdMemberRoleCommand command,
  ) {
    return dto.householdId.toLowerCase() == command.householdId.value &&
        dto.memberId.toLowerCase() == command.memberId.value &&
        dto.role == command.role.name &&
        command.role != HouseholdMemberRole.owner &&
        dto.version == command.expectedVersion + 1;
  }

  bool _validRemoval(
    HouseholdMemberRemovalDto dto,
    RemoveHouseholdMemberCommand command,
  ) {
    return dto.householdId.toLowerCase() == command.householdId.value &&
        dto.memberId.toLowerCase() == command.memberId.value &&
        dto.version == command.expectedVersion + 1 &&
        DateTime.tryParse(dto.removedAt)?.isUtc == true;
  }

  HouseholdMemberCommandResult _mapLeave(
    LeaveHouseholdDto dto,
    LeaveHouseholdCommand command,
  ) {
    if (dto.householdId.toLowerCase() != command.householdId.value ||
        dto.memberId.toLowerCase() != command.memberId.value ||
        dto.version != command.expectedVersion + 1 ||
        DateTime.tryParse(dto.removedAt)?.isUtc != true) {
      return _invalidPayload();
    }

    final String? activeHouseholdId = dto.activeHouseholdId;
    final String? activeMemberId = dto.activeMemberId;
    if (activeHouseholdId == null && activeMemberId == null) {
      return const HouseholdLeaveCompleted(null);
    }
    if (activeHouseholdId == null || activeMemberId == null) {
      return _invalidPayload();
    }

    final HouseholdId? householdId = HouseholdId.tryParse(activeHouseholdId);
    final HouseholdMemberId? memberId = HouseholdMemberId.tryParse(
      activeMemberId,
    );
    if (householdId == null || memberId == null) {
      return _invalidPayload();
    }
    return HouseholdLeaveCompleted(
      ActiveHousehold(householdId: householdId, memberId: memberId),
    );
  }

  bool _validOwnerTransfer(
    HouseholdOwnerTransferDto dto,
    TransferHouseholdOwnerCommand command,
  ) {
    return dto.householdId.toLowerCase() == command.householdId.value &&
        dto.ownerMemberId.toLowerCase() == command.newOwnerMemberId.value &&
        dto.version == command.expectedVersion + 1;
  }

  HouseholdMemberRole? _role(String value) {
    return switch (value) {
      'owner' => HouseholdMemberRole.owner,
      'admin' => HouseholdMemberRole.admin,
      'member' => HouseholdMemberRole.member,
      _ => null,
    };
  }

  HouseholdMemberCommandResult _invalidPayload() {
    return const HouseholdMemberCommandFailed(
      HouseholdMemberFailure(HouseholdMemberFailureKind.invalidPayload),
    );
  }

  LoadHouseholdMemberRosterResult _invalidRoster() {
    return const LoadHouseholdMemberRosterFailed(
      HouseholdMemberFailure(HouseholdMemberFailureKind.invalidPayload),
    );
  }

  HouseholdMemberFailure _mapFailure(HouseholdMemberDataFailureKind kind) {
    return HouseholdMemberFailure(switch (kind) {
      HouseholdMemberDataFailureKind.unauthenticated =>
        HouseholdMemberFailureKind.unauthenticated,
      HouseholdMemberDataFailureKind.invalidInput =>
        HouseholdMemberFailureKind.invalidInput,
      HouseholdMemberDataFailureKind.permissionDenied =>
        HouseholdMemberFailureKind.permissionDenied,
      HouseholdMemberDataFailureKind.notFound =>
        HouseholdMemberFailureKind.notFound,
      HouseholdMemberDataFailureKind.roleNotAllowed =>
        HouseholdMemberFailureKind.roleNotAllowed,
      HouseholdMemberDataFailureKind.ownerTransferRequired =>
        HouseholdMemberFailureKind.ownerTransferRequired,
      HouseholdMemberDataFailureKind.recentAuthenticationRequired =>
        HouseholdMemberFailureKind.recentAuthenticationRequired,
      HouseholdMemberDataFailureKind.versionConflict =>
        HouseholdMemberFailureKind.versionConflict,
      HouseholdMemberDataFailureKind.idempotencyConflict =>
        HouseholdMemberFailureKind.idempotencyConflict,
      HouseholdMemberDataFailureKind.temporarilyUnavailable =>
        HouseholdMemberFailureKind.temporarilyUnavailable,
      HouseholdMemberDataFailureKind.invalidPayload =>
        HouseholdMemberFailureKind.invalidPayload,
      HouseholdMemberDataFailureKind.unknown =>
        HouseholdMemberFailureKind.internal,
    });
  }
}
