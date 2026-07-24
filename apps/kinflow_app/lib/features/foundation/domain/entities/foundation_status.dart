import 'package:kinflow_app/features/foundation/domain/value_objects/foundation_sample_id.dart';

enum FoundationReadiness { ready }

final class FoundationStatus {
  const FoundationStatus({required this.id, required this.readiness});

  final FoundationSampleId id;
  final FoundationReadiness readiness;
}
