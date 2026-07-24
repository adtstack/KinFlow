import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';

final class LoadFoundationStatus {
  const LoadFoundationStatus(this._repository);

  final FoundationRepository _repository;

  Future<LoadFoundationResult> call() {
    return _repository.loadStatus();
  }
}
