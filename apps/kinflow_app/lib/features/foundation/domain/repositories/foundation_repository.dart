import 'package:kinflow_app/features/foundation/domain/entities/foundation_status.dart';
import 'package:kinflow_app/features/foundation/domain/failures/foundation_failure.dart';

abstract interface class FoundationRepository {
  Future<LoadFoundationResult> loadStatus();
}

sealed class LoadFoundationResult {
  const LoadFoundationResult();
}

final class FoundationLoaded extends LoadFoundationResult {
  const FoundationLoaded(this.status);

  final FoundationStatus status;
}

final class FoundationLoadFailed extends LoadFoundationResult {
  const FoundationLoadFailed(this.failure);

  final FoundationFailure failure;
}
