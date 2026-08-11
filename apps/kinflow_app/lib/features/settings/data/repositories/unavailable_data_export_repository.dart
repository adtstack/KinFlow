import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/data_export_identifiers.dart';

final class UnavailableDataExportRepository implements DataExportRepository {
  const UnavailableDataExportRepository();

  static const DataExportFailure _failure = DataExportFailure(
    DataExportFailureKind.temporarilyUnavailable,
  );

  @override
  Future<DataExportResult<DataExportPreflight>> loadPreflight() async {
    return const DataExportFailed<DataExportPreflight>(_failure);
  }

  @override
  Future<DataExportResult<DataExportRequest?>> loadLatest({
    DataExportRequestId? requestId,
  }) async {
    return const DataExportFailed<DataExportRequest?>(_failure);
  }

  @override
  Future<DataExportResult<DataExportRequest>> requestExport({
    required RecentAuthenticationProof recentAuthenticationProof,
    required DataExportCommandId commandId,
  }) async {
    return const DataExportFailed<DataExportRequest>(_failure);
  }

  @override
  Future<DataExportResult<DataExportRequest>> cancel({
    required DataExportRequestId requestId,
    required int expectedVersion,
    required DataExportCommandId commandId,
  }) async {
    return const DataExportFailed<DataExportRequest>(_failure);
  }

  @override
  Future<DataExportResult<DataExportRequest>> revoke({
    required DataExportRequestId requestId,
    required int expectedArtifactVersion,
    required RecentAuthenticationProof recentAuthenticationProof,
    required DataExportCommandId commandId,
  }) async {
    return const DataExportFailed<DataExportRequest>(_failure);
  }

  @override
  Future<DataExportResult<DataExportDownload>> createDownload({
    required DataExportRequestId requestId,
    required DataExportFormat format,
    required RecentAuthenticationProof recentAuthenticationProof,
  }) async {
    return const DataExportFailed<DataExportDownload>(_failure);
  }
}
