import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/presentation/widgets/timezone_date_time_preview.dart';
import 'package:kinflow_app/features/settings/domain/entities/timezone_catalog.dart';
import 'package:kinflow_app/features/settings/domain/repositories/timezone_catalog_repository.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'same instant uses exact timezone offsets and draft locale formatting',
    (WidgetTester tester) async {
      final _PreviewRepository repository = _PreviewRepository(
        <TimezoneCatalogResult>[TimezoneCatalogSucceeded(_catalog())],
      );
      final DateTime instant = DateTime.utc(2026, 8, 9, 6, 30);

      await _pumpPreview(
        tester,
        repository: repository,
        languageCode: 'en',
        clock: () => instant,
      );

      expect(_text(tester, 'timezonePreview.personal.date'), contains('2026'));
      expect(
        _text(tester, 'timezonePreview.personal.date'),
        contains('August'),
      );
      expect(_text(tester, 'timezonePreview.personal.time'), '3:30 PM');
      expect(_text(tester, 'timezonePreview.household.time'), '7:30 AM');
      expect(
        _text(tester, 'timezonePreview.personal.metadata'),
        contains('UTC+09:00'),
      );
      expect(
        _text(tester, 'timezonePreview.household.metadata'),
        contains('UTC+01:00'),
      );
      expect(repository.loadCount, 1);

      await _pumpPreview(
        tester,
        repository: repository,
        languageCode: 'ko',
        clock: () => instant,
      );

      expect(_text(tester, 'timezonePreview.personal.date'), contains('2026년'));
      expect(_text(tester, 'timezonePreview.personal.time'), '오후 3:30');
      expect(repository.loadCount, 1);
    },
  );

  testWidgets('explicit refresh captures one new instant for every row', (
    WidgetTester tester,
  ) async {
    final _PreviewRepository repository = _PreviewRepository(
      <TimezoneCatalogResult>[
        TimezoneCatalogSucceeded(_catalog()),
        TimezoneCatalogSucceeded(_catalog()),
      ],
    );
    final List<DateTime> instants = <DateTime>[
      DateTime.utc(2026, 8, 9, 6, 30),
      DateTime.utc(2026, 8, 9, 7, 31),
    ];
    var clockIndex = 0;

    await _pumpPreview(
      tester,
      repository: repository,
      languageCode: 'en',
      clock: () => instants[clockIndex++],
    );
    expect(_text(tester, 'timezonePreview.personal.time'), '3:30 PM');
    expect(_text(tester, 'timezonePreview.household.time'), '7:30 AM');

    await tester.tap(find.byKey(const Key('timezonePreview.refresh')));
    await tester.pumpAndSettle();

    expect(_text(tester, 'timezonePreview.personal.time'), '4:31 PM');
    expect(_text(tester, 'timezonePreview.household.time'), '8:31 AM');
    expect(repository.loadCount, 2);
  });

  testWidgets('failure retry and missing identifier fail closed', (
    WidgetTester tester,
  ) async {
    final _PreviewRepository repository =
        _PreviewRepository(<TimezoneCatalogResult>[
          const TimezoneCatalogFailed(TimezoneCatalogFailureKind.unavailable),
          TimezoneCatalogSucceeded(_catalog()),
        ]);

    await _pumpPreview(
      tester,
      repository: repository,
      languageCode: 'en',
      clock: () => DateTime.utc(2026, 8, 9, 6, 30),
      personalTimezone: 'Area/Current',
    );
    expect(find.byKey(const Key('timezonePreview.failure')), findsOneWidget);

    await tester.tap(find.byKey(const Key('timezonePreview.retry')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('timezonePreview.personal.unavailable')),
      findsOneWidget,
    );
    expect(find.textContaining('Area/Current'), findsWidgets);
    expect(
      find.byKey(const Key('timezonePreview.personal.time')),
      findsNothing,
    );
    expect(_text(tester, 'timezonePreview.household.time'), '7:30 AM');
    expect(repository.loadCount, 2);
  });

  testWidgets('failed refresh preserves the last complete snapshot', (
    WidgetTester tester,
  ) async {
    final _PreviewRepository repository =
        _PreviewRepository(<TimezoneCatalogResult>[
          TimezoneCatalogSucceeded(_catalog()),
          const TimezoneCatalogFailed(TimezoneCatalogFailureKind.unavailable),
        ]);
    final List<DateTime> instants = <DateTime>[
      DateTime.utc(2026, 8, 9, 6, 30),
      DateTime.utc(2026, 8, 9, 7, 31),
    ];
    var clockIndex = 0;
    await _pumpPreview(
      tester,
      repository: repository,
      languageCode: 'en',
      clock: () => instants[clockIndex++],
    );

    await tester.tap(find.byKey(const Key('timezonePreview.refresh')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('timezonePreview.refreshFailure')),
      findsOneWidget,
    );
    expect(_text(tester, 'timezonePreview.personal.time'), '3:30 PM');
    expect(_text(tester, 'timezonePreview.household.time'), '7:30 AM');
  });

  testWidgets('system 24-hour preference controls preview time style', (
    WidgetTester tester,
  ) async {
    await _pumpPreview(
      tester,
      repository: _PreviewRepository(<TimezoneCatalogResult>[
        TimezoneCatalogSucceeded(_catalog()),
      ]),
      languageCode: 'en',
      clock: () => DateTime.utc(2026, 8, 9, 6, 30),
      alwaysUse24HourFormat: true,
    );

    expect(_text(tester, 'timezonePreview.personal.time'), '15:30');
    expect(_text(tester, 'timezonePreview.household.time'), '07:30');
  });

  testWidgets('expanded pseudo copy remains scrollable at 200 percent', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final _PreviewRepository repository = _PreviewRepository(
      <TimezoneCatalogResult>[TimezoneCatalogSucceeded(_catalog())],
    );
    final DateTime instant = DateTime.utc(2026, 8, 9, 6, 30);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'XA'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            key: const Key('timezonePreview.testScroll'),
            child: Builder(
              builder: (BuildContext context) {
                final AppLocalizations localizations = AppLocalizations.of(
                  context,
                );
                return TimezoneDateTimePreviewPanel(
                  repository: repository,
                  languageCode: 'en',
                  clock: () => instant,
                  items: <TimezoneDateTimePreviewItem>[
                    TimezoneDateTimePreviewItem(
                      keyValue: 'personal',
                      label: localizations.timezonePreviewPersonalLabel,
                      timezone: 'Asia/Seoul',
                    ),
                    TimezoneDateTimePreviewItem(
                      keyValue: 'household',
                      label: localizations.timezonePreviewHouseholdLabel,
                      timezone: 'Europe/London',
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('timezonePreview.refresh'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('timezonePreview.household.metadata')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const Key('timezonePreview.household.metadata')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPreview(
  WidgetTester tester, {
  required TimezoneCatalogRepository repository,
  required String languageCode,
  required DateTime Function() clock,
  String personalTimezone = 'Asia/Seoul',
  String householdTimezone = 'Europe/London',
  bool alwaysUse24HourFormat = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(alwaysUse24HourFormat: alwaysUse24HourFormat),
        child: Scaffold(
          body: TimezoneDateTimePreviewPanel(
            repository: repository,
            languageCode: languageCode,
            clock: clock,
            items: <TimezoneDateTimePreviewItem>[
              TimezoneDateTimePreviewItem(
                keyValue: 'personal',
                label: 'Personal preview',
                timezone: personalTimezone,
              ),
              TimezoneDateTimePreviewItem(
                keyValue: 'household',
                label: 'Household preview',
                timezone: householdTimezone,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(Key(key))).data!;
}

TimezoneCatalog _catalog() {
  return TimezoneCatalog.tryCreate(<TimezoneCatalogEntry>[
    _entry('UTC', 0),
    _entry('Asia/Seoul', 9 * 60),
    _entry('Europe/London', 60, daylightSaving: true),
    _entry('America/New_York', -4 * 60, daylightSaving: true),
  ])!;
}

TimezoneCatalogEntry _entry(
  String identifier,
  int offsetMinutes, {
  bool daylightSaving = false,
}) {
  return TimezoneCatalogEntry.tryCreate(
    identifier: identifier,
    currentUtcOffsetMinutes: offsetMinutes,
    isDaylightSaving: daylightSaving,
  )!;
}

final class _PreviewRepository implements TimezoneCatalogRepository {
  _PreviewRepository(this._results);

  final List<TimezoneCatalogResult> _results;
  int loadCount = 0;

  @override
  String get databaseVersion => 'test';

  @override
  Future<TimezoneCatalogResult> load() async {
    final int index = loadCount < _results.length
        ? loadCount
        : _results.length - 1;
    loadCount += 1;
    return _results[index];
  }
}
