import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/data_export_identifiers.dart';

abstract interface class DataExportRepository {
  Future<DataExportResult<DataExportPreflight>> loadPreflight();

  Future<DataExportResult<DataExportRequest?>> loadLatest({
    DataExportRequestId? requestId,
  });

  Future<DataExportResult<DataExportRequest>> requestExport({
    required RecentAuthenticationProof recentAuthenticationProof,
    required DataExportCommandId commandId,
  });

  Future<DataExportResult<DataExportRequest>> cancel({
    required DataExportRequestId requestId,
    required int expectedVersion,
    required DataExportCommandId commandId,
  });

  Future<DataExportResult<DataExportRequest>> revoke({
    required DataExportRequestId requestId,
    required int expectedArtifactVersion,
    required RecentAuthenticationProof recentAuthenticationProof,
    required DataExportCommandId commandId,
  });

  Future<DataExportResult<DataExportDownload>> createDownload({
    required DataExportRequestId requestId,
    required DataExportFormat format,
    required RecentAuthenticationProof recentAuthenticationProof,
  });
}

sealed class DataExportResult<T> {
  const DataExportResult();
}

final class DataExportSucceeded<T> extends DataExportResult<T> {
  const DataExportSucceeded(this.value);

  final T value;
}

final class DataExportFailed<T> extends DataExportResult<T> {
  const DataExportFailed(this.failure);

  final DataExportFailure failure;
}
