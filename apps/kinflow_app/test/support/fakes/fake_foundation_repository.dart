import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';

final class FakeFoundationRepository implements FoundationRepository {
  FakeFoundationRepository({required List<LoadFoundationResult> results})
    : _results = List<LoadFoundationResult>.unmodifiable(results) {
    if (results.isEmpty) {
      throw ArgumentError.value(results, 'results', 'must not be empty');
    }
  }

  final List<LoadFoundationResult> _results;
  int loadCount = 0;

  @override
  Future<LoadFoundationResult> loadStatus() {
    final int index = loadCount < _results.length
        ? loadCount
        : _results.length - 1;
    loadCount += 1;
    return Future<LoadFoundationResult>.value(_results[index]);
  }
}
