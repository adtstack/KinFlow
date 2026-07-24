import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/foundation/application/use_cases/load_foundation_status.dart';
import 'package:kinflow_app/features/foundation/data/datasources/local_foundation_status_data_source.dart';
import 'package:kinflow_app/features/foundation/data/dto/foundation_status_dto.dart';
import 'package:kinflow_app/features/foundation/data/mappers/foundation_status_mapper.dart';
import 'package:kinflow_app/features/foundation/data/repositories/fixture_foundation_repository.dart';
import 'package:kinflow_app/features/foundation/domain/entities/foundation_status.dart';
import 'package:kinflow_app/features/foundation/domain/failures/foundation_failure.dart';
import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';
import 'package:kinflow_app/features/foundation/domain/value_objects/foundation_sample_id.dart';

import '../../support/fakes/fake_foundation_repository.dart';

void main() {
  group('foundation domain', () {
    test('accepts a stable sample id and rejects invalid values', () {
      final FoundationSampleId? id = FoundationSampleId.tryParse(
        'local-foundation',
      );

      expect(id?.value, 'local-foundation');
      expect(FoundationSampleId.tryParse(''), isNull);
      expect(FoundationSampleId.tryParse('Contains Spaces'), isNull);
      expect(FoundationSampleId.tryParse('A-uppercase'), isNull);
    });
  });

  group('foundation data boundary', () {
    test('generated DTO uses the explicit snake_case contract', () {
      final FoundationStatusDto dto = FoundationStatusDto.fromJson(
        const <String, Object?>{
          'sample_id': 'fixture-foundation',
          'status': 'ready',
        },
      );

      expect(dto.sampleId, 'fixture-foundation');
      expect(dto.status, 'ready');
      expect(dto.toJson(), <String, Object?>{
        'sample_id': 'fixture-foundation',
        'status': 'ready',
      });
    });

    test('generated DTO rejects an invalid field type', () {
      expect(
        () => FoundationStatusDto.fromJson(const <String, Object?>{
          'sample_id': 7,
          'status': 'ready',
        }),
        throwsA(anything),
      );
    });

    test('mapper converts known values and rejects unknown status', () {
      const FoundationStatusMapper mapper = FoundationStatusMapper();

      final LoadFoundationResult loaded = mapper.toDomain(
        const FoundationStatusDto(
          sampleId: 'fixture-foundation',
          status: 'ready',
        ),
      );
      final LoadFoundationResult invalid = mapper.toDomain(
        const FoundationStatusDto(
          sampleId: 'fixture-foundation',
          status: 'future-status',
        ),
      );

      expect(loaded, isA<FoundationLoaded>());
      expect(
        (loaded as FoundationLoaded).status.readiness,
        FoundationReadiness.ready,
      );
      expect(invalid, isA<FoundationLoadFailed>());
      expect(
        (invalid as FoundationLoadFailed).failure,
        isA<InvalidFoundationPayload>(),
      );
    });

    test('repository maps valid fixture data to a domain entity', () async {
      const FixtureFoundationRepository repository =
          FixtureFoundationRepository(
            LocalFoundationStatusDataSource(),
            FoundationStatusMapper(),
          );

      final LoadFoundationResult result = await repository.loadStatus();

      expect(result, isA<FoundationLoaded>());
      expect((result as FoundationLoaded).status.id.value, 'local-foundation');
    });

    test('repository converts malformed JSON to a stable failure', () async {
      const FixtureFoundationRepository repository =
          FixtureFoundationRepository(
            _MalformedFoundationStatusDataSource(),
            FoundationStatusMapper(),
          );

      final LoadFoundationResult result = await repository.loadStatus();

      expect(result, isA<FoundationLoadFailed>());
      expect(
        (result as FoundationLoadFailed).failure.code,
        'foundation.invalid_payload',
      );
    });
  });

  test('application use case delegates to the repository port', () async {
    const FoundationLoadFailed expected = FoundationLoadFailed(
      FoundationUnavailable(),
    );
    final FakeFoundationRepository repository = FakeFoundationRepository(
      results: <LoadFoundationResult>[expected],
    );
    final LoadFoundationStatus useCase = LoadFoundationStatus(repository);

    final LoadFoundationResult result = await useCase();

    expect(result, same(expected));
    expect(repository.loadCount, 1);
  });
}

final class _MalformedFoundationStatusDataSource
    implements FoundationStatusDataSource {
  const _MalformedFoundationStatusDataSource();

  @override
  Future<Map<String, Object?>> loadStatus() {
    return Future<Map<String, Object?>>.value(const <String, Object?>{
      'sample_id': 7,
      'status': 'ready',
    });
  }
}
