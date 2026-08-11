import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/repositories/bundled_timezone_catalog_repository.dart';
import 'package:kinflow_app/features/settings/domain/entities/timezone_catalog.dart';
import 'package:kinflow_app/features/settings/domain/repositories/timezone_catalog_repository.dart';

void main() {
  test('bundled 2025c catalog exposes representative IANA zones', () async {
    final BundledTimezoneCatalogRepository repository =
        BundledTimezoneCatalogRepository(
          now: () => DateTime.utc(2026, 1, 15, 12),
        );

    expect(repository.databaseVersion, '2025c');
    final TimezoneCatalogResult result = await repository.load();
    expect(result, isA<TimezoneCatalogSucceeded>());
    final TimezoneCatalog catalog =
        (result as TimezoneCatalogSucceeded).catalog;
    expect(catalog.entries.length, greaterThan(300));
    expect(_exact(catalog, 'UTC').currentUtcOffsetMinutes, 0);
    expect(_exact(catalog, 'Asia/Seoul').currentUtcOffsetMinutes, 9 * 60);
    expect(
      _exact(catalog, 'America/New_York').currentUtcOffsetMinutes,
      -5 * 60,
    );
    expect(_exact(catalog, 'America/New_York').isDaylightSaving, isFalse);
    expect(
      catalog.entries.where(
        (TimezoneCatalogEntry entry) =>
            entry.identifier.startsWith('posix/') ||
            entry.identifier.startsWith('right/'),
      ),
      isEmpty,
    );
  });

  test('clock failure becomes a bounded catalog failure', () async {
    final BundledTimezoneCatalogRepository repository =
        BundledTimezoneCatalogRepository(
          now: () => throw StateError('clock unavailable'),
        );

    expect(
      await repository.load(),
      isA<TimezoneCatalogFailed>().having(
        (TimezoneCatalogFailed failure) => failure.kind,
        'kind',
        TimezoneCatalogFailureKind.unavailable,
      ),
    );
  });
}

TimezoneCatalogEntry _exact(TimezoneCatalog catalog, String identifier) {
  return catalog.entries.singleWhere(
    (TimezoneCatalogEntry entry) => entry.identifier == identifier,
  );
}
