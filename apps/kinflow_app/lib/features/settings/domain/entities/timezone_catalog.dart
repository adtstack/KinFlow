import 'dart:collection';

final RegExp _timezoneCatalogPattern = RegExp(
  r'^[A-Za-z0-9_+.-]+(?:/[A-Za-z0-9_+.-]+)+$',
);
final RegExp _timezoneCatalogControlCharacterPattern = RegExp(
  r'[\x00-\x1f\x7f]',
);
final RegExp _timezoneCatalogWhitespacePattern = RegExp(r'\s+');

final class TimezoneCatalogEntry {
  const TimezoneCatalogEntry._({
    required this.identifier,
    required this.currentUtcOffsetMinutes,
    required this.isDaylightSaving,
  });

  final String identifier;
  final int currentUtcOffsetMinutes;
  final bool isDaylightSaving;

  String get cityLabel => identifier == 'UTC'
      ? identifier
      : identifier.split('/').last.replaceAll('_', ' ');

  static TimezoneCatalogEntry? tryCreate({
    required String identifier,
    required int currentUtcOffsetMinutes,
    required bool isDaylightSaving,
  }) {
    if (!_validTimezoneCatalogIdentifier(identifier) ||
        currentUtcOffsetMinutes < -14 * 60 ||
        currentUtcOffsetMinutes > 14 * 60) {
      return null;
    }
    return TimezoneCatalogEntry._(
      identifier: identifier,
      currentUtcOffsetMinutes: currentUtcOffsetMinutes,
      isDaylightSaving: isDaylightSaving,
    );
  }
}

final class TimezoneCatalog {
  TimezoneCatalog._(List<TimezoneCatalogEntry> entries)
    : entries = UnmodifiableListView<TimezoneCatalogEntry>(entries);

  static const int maximumQueryCharacters = 80;
  static const int maximumVisibleResults = 100;

  final List<TimezoneCatalogEntry> entries;

  TimezoneCatalogEntry? entryForIdentifier(String identifier) {
    for (final TimezoneCatalogEntry entry in entries) {
      if (entry.identifier == identifier) return entry;
    }
    return null;
  }

  static TimezoneCatalog? tryCreate(Iterable<TimezoneCatalogEntry> source) {
    final Map<String, TimezoneCatalogEntry> byIdentifier =
        <String, TimezoneCatalogEntry>{};
    for (final TimezoneCatalogEntry entry in source) {
      if (byIdentifier.containsKey(entry.identifier)) return null;
      byIdentifier[entry.identifier] = entry;
    }
    if (!byIdentifier.containsKey('UTC')) return null;
    final List<TimezoneCatalogEntry> sorted = byIdentifier.values.toList()
      ..sort(
        (TimezoneCatalogEntry left, TimezoneCatalogEntry right) =>
            left.identifier.compareTo(right.identifier),
      );
    return TimezoneCatalog._(sorted);
  }

  List<TimezoneCatalogEntry> search(
    String query, {
    String? selectedIdentifier,
  }) {
    if (query.length > maximumQueryCharacters ||
        _timezoneCatalogControlCharacterPattern.hasMatch(query)) {
      return const <TimezoneCatalogEntry>[];
    }
    final String normalizedQuery = _normalizeTimezoneSearchText(query);
    if (normalizedQuery.isEmpty) {
      final List<TimezoneCatalogEntry> results = <TimezoneCatalogEntry>[];
      final Set<String> included = <String>{};
      void include(String? identifier) {
        if (identifier == null || included.contains(identifier)) return;
        for (final TimezoneCatalogEntry entry in entries) {
          if (entry.identifier == identifier) {
            results.add(entry);
            included.add(identifier);
            return;
          }
        }
      }

      include(selectedIdentifier);
      include('UTC');
      for (final TimezoneCatalogEntry entry in entries) {
        if (results.length >= maximumVisibleResults) break;
        if (included.add(entry.identifier)) results.add(entry);
      }
      return UnmodifiableListView<TimezoneCatalogEntry>(results);
    }

    final List<String> tokens = normalizedQuery.split(' ');
    final List<({TimezoneCatalogEntry entry, int rank})> matches =
        entries
            .map((TimezoneCatalogEntry entry) {
              final String searchable = _normalizeTimezoneSearchText(
                entry.identifier,
              );
              if (!tokens.every(searchable.contains)) return null;
              final String city = _normalizeTimezoneSearchText(entry.cityLabel);
              final int rank = searchable == normalizedQuery
                  ? 0
                  : city.startsWith(normalizedQuery)
                  ? 1
                  : searchable.startsWith(normalizedQuery)
                  ? 2
                  : 3;
              return (entry: entry, rank: rank);
            })
            .whereType<({TimezoneCatalogEntry entry, int rank})>()
            .toList()
          ..sort((left, right) {
            final int rankOrder = left.rank.compareTo(right.rank);
            return rankOrder != 0
                ? rankOrder
                : left.entry.identifier.compareTo(right.entry.identifier);
          });
    return UnmodifiableListView<TimezoneCatalogEntry>(
      matches
          .take(maximumVisibleResults)
          .map((match) => match.entry)
          .toList(growable: false),
    );
  }
}

bool _validTimezoneCatalogIdentifier(String value) {
  return value == 'UTC' ||
      (value.length <= 100 &&
          value == value.trim() &&
          !value.startsWith('posix/') &&
          !value.startsWith('right/') &&
          _timezoneCatalogPattern.hasMatch(value));
}

String _normalizeTimezoneSearchText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[/_]'), ' ')
      .replaceAll(_timezoneCatalogWhitespacePattern, ' ');
}
