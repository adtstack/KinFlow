import 'package:freezed_annotation/freezed_annotation.dart';

part 'foundation_status_dto.freezed.dart';
part 'foundation_status_dto.g.dart';

@freezed
abstract class FoundationStatusDto with _$FoundationStatusDto {
  // Freezed copies this class-only annotation to the generated implementation.
  // ignore: invalid_annotation_target
  @JsonSerializable(checked: true)
  const factory FoundationStatusDto({
    @JsonKey(name: 'sample_id') required String sampleId,
    required String status,
  }) = _FoundationStatusDto;

  factory FoundationStatusDto.fromJson(Map<String, Object?> json) =>
      _$FoundationStatusDtoFromJson(json);
}
