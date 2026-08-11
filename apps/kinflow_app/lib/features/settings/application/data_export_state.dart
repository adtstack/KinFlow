import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';

sealed class DataExportState {
  const DataExportState();
}

final class DataExportInitial extends DataExportState {
  const DataExportInitial();
}

final class DataExportLoading extends DataExportState {
  const DataExportLoading();
}

final class DataExportLoadFailed extends DataExportState {
  const DataExportLoadFailed(this.failure);

  final DataExportFailure failure;
}

final class DataExportReady extends DataExportState {
  const DataExportReady({
    required this.preflight,
    required this.latestRequest,
    this.isSubmitting = false,
    this.isRefreshing = false,
    this.failure,
    this.lastOpenedFormat,
  });

  final DataExportPreflight preflight;
  final DataExportRequest? latestRequest;
  final bool isSubmitting;
  final bool isRefreshing;
  final DataExportFailure? failure;
  final DataExportFormat? lastOpenedFormat;

  bool get busy => isSubmitting || isRefreshing;
}
