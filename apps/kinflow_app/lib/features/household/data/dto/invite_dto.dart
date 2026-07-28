import 'package:freezed_annotation/freezed_annotation.dart';

part 'invite_dto.freezed.dart';
part 'invite_dto.g.dart';

@freezed
abstract class InviteDto with _$InviteDto {
  // ignore: invalid_annotation_target
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
  const factory InviteDto({
    required String id,
    required String householdId,
    required String role,
    required String expiresAt,
    required String status,
  }) = _InviteDto;

  factory InviteDto.fromJson(Map<String, Object?> json) =>
      _$InviteDtoFromJson(json);
}

@freezed
abstract class InvitePreviewDto with _$InvitePreviewDto {
  // ignore: invalid_annotation_target
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
  const factory InvitePreviewDto({
    required bool valid,
    required String householdDisplayName,
    required String inviterDisplayName,
    required String role,
    required String expiresAt,
  }) = _InvitePreviewDto;

  factory InvitePreviewDto.fromJson(Map<String, Object?> json) =>
      _$InvitePreviewDtoFromJson(json);
}

@freezed
abstract class InviteMemberDto with _$InviteMemberDto {
  // ignore: invalid_annotation_target
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
  const factory InviteMemberDto({
    required String id,
    required String householdId,
    required String displayName,
    required String role,
    required bool activeHouseholdSet,
  }) = _InviteMemberDto;

  factory InviteMemberDto.fromJson(Map<String, Object?> json) =>
      _$InviteMemberDtoFromJson(json);
}

@freezed
abstract class RevokedInviteDto with _$RevokedInviteDto {
  // ignore: invalid_annotation_target
  @JsonSerializable(checked: true, disallowUnrecognizedKeys: true)
  const factory RevokedInviteDto({
    required String id,
    required String householdId,
    required String status,
  }) = _RevokedInviteDto;

  factory RevokedInviteDto.fromJson(Map<String, Object?> json) =>
      _$RevokedInviteDtoFromJson(json);
}
