import 'package:json_annotation/json_annotation.dart';

part 'household_member_dto.g.dart';

int _strictIntegerFromJson(Object? value) {
  if (value is! int) {
    throw const FormatException('Expected an integer.');
  }
  return value;
}

@JsonSerializable(
  checked: true,
  createToJson: false,
  disallowUnrecognizedKeys: true,
)
final class HouseholdMemberRosterRowDto {
  const HouseholdMemberRosterRowDto({
    required this.householdId,
    required this.householdName,
    required this.householdVersion,
    required this.memberId,
    required this.displayName,
    required this.role,
    required this.memberVersion,
    required this.isCurrentUser,
  });

  factory HouseholdMemberRosterRowDto.fromJson(Map<String, Object?> json) =>
      _$HouseholdMemberRosterRowDtoFromJson(json);

  @JsonKey(name: 'household_id')
  final String householdId;
  @JsonKey(name: 'household_name')
  final String householdName;
  @JsonKey(name: 'household_version', fromJson: _strictIntegerFromJson)
  final int householdVersion;
  @JsonKey(name: 'member_id')
  final String memberId;
  @JsonKey(name: 'display_name')
  final String displayName;
  final String role;
  @JsonKey(name: 'member_version', fromJson: _strictIntegerFromJson)
  final int memberVersion;
  @JsonKey(name: 'is_current_user')
  final bool isCurrentUser;
}

@JsonSerializable(
  checked: true,
  createToJson: false,
  disallowUnrecognizedKeys: true,
)
final class HouseholdMemberRoleMutationDto {
  const HouseholdMemberRoleMutationDto({
    required this.householdId,
    required this.memberId,
    required this.role,
    required this.version,
  });

  factory HouseholdMemberRoleMutationDto.fromJson(Map<String, Object?> json) =>
      _$HouseholdMemberRoleMutationDtoFromJson(json);

  final String householdId;
  final String memberId;
  final String role;
  @JsonKey(fromJson: _strictIntegerFromJson)
  final int version;
}

@JsonSerializable(
  checked: true,
  createToJson: false,
  disallowUnrecognizedKeys: true,
)
final class HouseholdMemberRemovalDto {
  const HouseholdMemberRemovalDto({
    required this.householdId,
    required this.memberId,
    required this.version,
    required this.removedAt,
  });

  factory HouseholdMemberRemovalDto.fromJson(Map<String, Object?> json) =>
      _$HouseholdMemberRemovalDtoFromJson(json);

  final String householdId;
  final String memberId;
  @JsonKey(fromJson: _strictIntegerFromJson)
  final int version;
  final String removedAt;
}

@JsonSerializable(
  checked: true,
  createToJson: false,
  disallowUnrecognizedKeys: true,
)
final class LeaveHouseholdDto {
  const LeaveHouseholdDto({
    required this.householdId,
    required this.memberId,
    required this.version,
    required this.removedAt,
    required this.activeHouseholdId,
    required this.activeMemberId,
  });

  factory LeaveHouseholdDto.fromJson(Map<String, Object?> json) =>
      _$LeaveHouseholdDtoFromJson(json);

  final String householdId;
  final String memberId;
  @JsonKey(fromJson: _strictIntegerFromJson)
  final int version;
  final String removedAt;
  final String? activeHouseholdId;
  final String? activeMemberId;
}

@JsonSerializable(
  checked: true,
  createToJson: false,
  disallowUnrecognizedKeys: true,
)
final class HouseholdOwnerTransferDto {
  const HouseholdOwnerTransferDto({
    required this.householdId,
    required this.ownerMemberId,
    required this.version,
  });

  factory HouseholdOwnerTransferDto.fromJson(Map<String, Object?> json) =>
      _$HouseholdOwnerTransferDtoFromJson(json);

  final String householdId;
  final String ownerMemberId;
  @JsonKey(fromJson: _strictIntegerFromJson)
  final int version;
}
