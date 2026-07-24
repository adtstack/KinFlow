import 'package:kinflow_app/features/foundation/data/datasources/local_foundation_status_data_source.dart';
import 'package:kinflow_app/features/foundation/data/mappers/foundation_status_mapper.dart';
import 'package:kinflow_app/features/foundation/data/repositories/fixture_foundation_repository.dart';
import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';

FoundationRepository createFoundationRepository() {
  return const FixtureFoundationRepository(
    LocalFoundationStatusDataSource(),
    FoundationStatusMapper(),
  );
}
