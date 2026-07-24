// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'foundation_status_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FoundationStatusDto _$FoundationStatusDtoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('_FoundationStatusDto', json, ($checkedConvert) {
      final val = _FoundationStatusDto(
        sampleId: $checkedConvert('sample_id', (v) => v as String),
        status: $checkedConvert('status', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'sampleId': 'sample_id'});

Map<String, dynamic> _$FoundationStatusDtoToJson(
  _FoundationStatusDto instance,
) => <String, dynamic>{
  'sample_id': instance.sampleId,
  'status': instance.status,
};
