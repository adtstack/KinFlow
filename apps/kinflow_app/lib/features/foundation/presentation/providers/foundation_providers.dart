import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/foundation/application/use_cases/load_foundation_status.dart';
import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';

final foundationRepositoryProvider = Provider<FoundationRepository>((ref) {
  throw StateError('FoundationRepository override is required.');
});

final loadFoundationStatusProvider = Provider<LoadFoundationStatus>((ref) {
  return LoadFoundationStatus(ref.watch(foundationRepositoryProvider));
});

final foundationStatusProvider = FutureProvider<LoadFoundationResult>((ref) {
  return ref.watch(loadFoundationStatusProvider).call();
});
