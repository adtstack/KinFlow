import 'package:json_annotation/json_annotation.dart';
import 'package:kinflow_app/features/foundation/data/datasources/local_foundation_status_data_source.dart';
import 'package:kinflow_app/features/foundation/data/dto/foundation_status_dto.dart';
import 'package:kinflow_app/features/foundation/data/mappers/foundation_status_mapper.dart';
import 'package:kinflow_app/features/foundation/domain/failures/foundation_failure.dart';
import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';

final class FixtureFoundationRepository implements FoundationRepository {
  const FixtureFoundationRepository(this._dataSource, this._mapper);

  final FoundationStatusDataSource _dataSource;
  final FoundationStatusMapper _mapper;

  @override
  Future<LoadFoundationResult> loadStatus() async {
    final Map<String, Object?> payload = await _dataSource.loadStatus();

    try {
      final FoundationStatusDto dto = FoundationStatusDto.fromJson(payload);
      return _mapper.toDomain(dto);
    } on CheckedFromJsonException {
      return const FoundationLoadFailed(InvalidFoundationPayload());
    }
  }
}
