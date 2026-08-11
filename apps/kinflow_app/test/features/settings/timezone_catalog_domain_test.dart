import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/domain/entities/timezone_catalog.dart';

void main() {
  test('entry rejects non-IANA namespaces and impossible current offsets', () {
    expect(_entry('UTC'), isNotNull);
    expect(_entry('Asia/Seoul'), isNotNull);
    expect(_entry('posix/Asia/Seoul'), isNull);
    expect(_entry('right/Asia/Seoul'), isNull);
    expect(_entry('Seoul'), isNull);
    expect(_entry('Asia/Seoul', offsetMinutes: 14 * 60 + 1), isNull);
  });

  test('catalog rejects duplicates and requires UTC', () {
    expect(
      TimezoneCatalog.tryCreate(<TimezoneCatalogEntry>[
        _entry('UTC')!,
        _entry('UTC')!,
      ]),
      isNull,
    );
    expect(
      TimezoneCatalog.tryCreate(<TimezoneCatalogEntry>[_entry('Asia/Seoul')!]),
      isNull,
    );
  });

  test('empty search pins selected timezone then UTC without duplicates', () {
    final TimezoneCatalog catalog = _catalog(<TimezoneCatalogEntry>[
      _entry('Europe/London')!,
      _entry('UTC')!,
      _entry('Asia/Seoul')!,
    ]);

    expect(
      catalog
          .search('', selectedIdentifier: 'Asia/Seoul')
          .map((TimezoneCatalogEntry entry) => entry.identifier),
      <String>['Asia/Seoul', 'UTC', 'Europe/London'],
    );
  });

  test('exact identifier lookup never falls back to a partial match', () {
    final TimezoneCatalog catalog = _catalog(<TimezoneCatalogEntry>[
      _entry('UTC')!,
      _entry('America/New_York')!,
      _entry('America/North_Dakota/New_Salem')!,
    ]);

    expect(
      catalog.entryForIdentifier('America/New_York')?.identifier,
      'America/New_York',
    );
    expect(catalog.entryForIdentifier('New_York'), isNull);
    expect(catalog.entryForIdentifier('america/new_york'), isNull);
  });

  test('search normalizes case slash underscore and requires every token', () {
    final TimezoneCatalog catalog = _catalog(<TimezoneCatalogEntry>[
      _entry('UTC')!,
      _entry('America/New_York')!,
      _entry('America/North_Dakota/New_Salem')!,
      _entry('Europe/London')!,
    ]);

    expect(
      catalog
          .search(' AMERICA/new york ')
          .map((TimezoneCatalogEntry entry) => entry.identifier),
      <String>['America/New_York'],
    );
    expect(
      catalog
          .search('new')
          .map((TimezoneCatalogEntry entry) => entry.identifier),
      <String>['America/New_York', 'America/North_Dakota/New_Salem'],
    );
    expect(catalog.search('america london'), isEmpty);
  });

  test('search result count is bounded and ordering is deterministic', () {
    final List<TimezoneCatalogEntry> entries = <TimezoneCatalogEntry>[
      _entry('UTC')!,
      for (int index = 129; index >= 0; index -= 1)
        _entry('Region/City_${index.toString().padLeft(3, '0')}')!,
    ];
    final List<TimezoneCatalogEntry> results = _catalog(entries).search('city');

    expect(results, hasLength(TimezoneCatalog.maximumVisibleResults));
    expect(results.first.identifier, 'Region/City_000');
    expect(results.last.identifier, 'Region/City_099');
  });

  test('control characters and overlong queries fail closed', () {
    final TimezoneCatalog catalog = _catalog(<TimezoneCatalogEntry>[
      _entry('UTC')!,
      _entry('Asia/Seoul')!,
    ]);

    expect(catalog.search('Asia\nSeoul'), isEmpty);
    expect(
      catalog.search(
        List<String>.filled(
          TimezoneCatalog.maximumQueryCharacters + 1,
          'a',
        ).join(),
      ),
      isEmpty,
    );
  });
}

TimezoneCatalogEntry? _entry(String identifier, {int offsetMinutes = 0}) {
  return TimezoneCatalogEntry.tryCreate(
    identifier: identifier,
    currentUtcOffsetMinutes: offsetMinutes,
    isDaylightSaving: false,
  );
}

TimezoneCatalog _catalog(List<TimezoneCatalogEntry> entries) {
  return TimezoneCatalog.tryCreate(entries)!;
}
