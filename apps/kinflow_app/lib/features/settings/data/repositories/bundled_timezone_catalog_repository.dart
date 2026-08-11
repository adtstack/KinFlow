import 'package:kinflow_app/features/settings/domain/entities/timezone_catalog.dart';
import 'package:kinflow_app/features/settings/domain/repositories/timezone_catalog_repository.dart';
import 'package:kinflow_app/infrastructure/timezone/bundled_timezone_database.dart';
import 'package:timezone/timezone.dart' as timezone;

final class BundledTimezoneCatalogRepository
    implements TimezoneCatalogRepository {
  BundledTimezoneCatalogRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  @override
  String get databaseVersion => BundledTimezoneDatabase.version;

  @override
  Future<TimezoneCatalogResult> load() async {
    try {
      BundledTimezoneDatabase.initialize();
      final DateTime instant = _now().toUtc();
      final Map<String, timezone.Location> locations =
          <String, timezone.Location>{
            ...timezone.timeZoneDatabase.locations,
            'UTC': timezone.UTC,
          };
      final List<TimezoneCatalogEntry> entries = <TimezoneCatalogEntry>[];
      for (final MapEntry<String, timezone.Location> location
          in locations.entries) {
        final timezone.TZDateTime current = timezone.TZDateTime.from(
          instant,
          location.value,
        );
        final TimezoneCatalogEntry? entry = TimezoneCatalogEntry.tryCreate(
          identifier: location.key,
          currentUtcOffsetMinutes: current.timeZoneOffset.inMinutes,
          isDaylightSaving: current.timeZone.isDst,
        );
        if (entry != null) entries.add(entry);
      }
      final TimezoneCatalog? catalog = TimezoneCatalog.tryCreate(entries);
      return catalog == null
          ? const TimezoneCatalogFailed(
              TimezoneCatalogFailureKind.invalidPayload,
            )
          : TimezoneCatalogSucceeded(catalog);
    } on Object {
      return const TimezoneCatalogFailed(
        TimezoneCatalogFailureKind.unavailable,
      );
    }
  }
}
