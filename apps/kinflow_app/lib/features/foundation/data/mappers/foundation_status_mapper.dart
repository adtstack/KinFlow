import 'package:kinflow_app/features/foundation/data/dto/foundation_status_dto.dart';
import 'package:kinflow_app/features/foundation/domain/entities/foundation_status.dart';
import 'package:kinflow_app/features/foundation/domain/failures/foundation_failure.dart';
import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';
import 'package:kinflow_app/features/foundation/domain/value_objects/foundation_sample_id.dart';

final class FoundationStatusMapper {
  const FoundationStatusMapper();

  LoadFoundationResult toDomain(FoundationStatusDto dto) {
    final FoundationSampleId? id = FoundationSampleId.tryParse(dto.sampleId);
    if (id == null || dto.status != 'ready') {
      return const FoundationLoadFailed(InvalidFoundationPayload());
    }

    return FoundationLoaded(
      FoundationStatus(id: id, readiness: FoundationReadiness.ready),
    );
  }
}
