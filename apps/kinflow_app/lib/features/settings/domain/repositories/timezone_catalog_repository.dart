import 'package:kinflow_app/features/settings/domain/entities/timezone_catalog.dart';

abstract interface class TimezoneCatalogRepository {
  String get databaseVersion;

  Future<TimezoneCatalogResult> load();
}

enum TimezoneCatalogFailureKind { unavailable, invalidPayload }

sealed class TimezoneCatalogResult {
  const TimezoneCatalogResult();
}

final class TimezoneCatalogSucceeded extends TimezoneCatalogResult {
  const TimezoneCatalogSucceeded(this.catalog);

  final TimezoneCatalog catalog;
}

final class TimezoneCatalogFailed extends TimezoneCatalogResult {
  const TimezoneCatalogFailed(this.kind);

  final TimezoneCatalogFailureKind kind;
}
