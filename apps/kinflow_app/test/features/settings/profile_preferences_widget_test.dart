import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/providers/timezone_catalog_dependencies.dart';
import 'package:kinflow_app/app/presentation/widgets/timezone_picker_sheet.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_controller.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/entities/timezone_catalog.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/domain/repositories/timezone_catalog_repository.dart';
import 'package:kinflow_app/features/settings/presentation/providers/profile_preferences_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/profile_preferences_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

import '../../support/fakes/fake_profile_preferences_dependencies.dart';

void main() {
  testWidgets('Owner confirms and saves profile plus household timezone', (
    WidgetTester tester,
  ) async {
    final ProfilePreferences updated = profilePreferencesFixture(
      displayName: 'Adult Alpha',
      avatar: ProfileAvatarPreset.star,
      language: ProfileLanguage.korean,
      profileTimezone: 'America/New_York',
      profileVersion: 2,
      householdTimezone: 'Europe/London',
      householdVersion: 5,
    );
    final FakeProfilePreferencesRepository repository =
        FakeProfilePreferencesRepository(
          updateResults: <ProfilePreferencesResult>[
            ProfilePreferencesSucceeded(updated),
          ],
        );
    final FakeProfileLocalePreferenceSink sink =
        FakeProfileLocalePreferenceSink();
    await _pumpScreen(tester, repository, sink: sink);

    await tester.enterText(
      find.byKey(const Key('profilePreferences.displayName')),
      'Adult Alpha',
    );
    await tester.tap(find.byKey(const Key('profilePreferences.avatar.star')));
    final Finder language = find.byKey(
      const Key('profilePreferences.language'),
    );
    await tester.ensureVisible(language);
    await tester.pumpAndSettle();
    await tester.tap(language);
    await tester.pumpAndSettle();
    await tester.tap(find.text('한국어').last);
    await tester.pumpAndSettle();
    await _selectTimezone(
      tester,
      fieldKey: 'profilePreferences.profileTimezone',
      query: 'new york',
      identifier: 'America/New_York',
    );
    await _selectTimezone(
      tester,
      fieldKey: 'profilePreferences.householdTimezone',
      query: 'london',
      identifier: 'Europe/London',
    );

    final Finder save = find.byKey(const Key('profilePreferences.save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(repository.updateCalls, isEmpty);
    expect(
      find.byKey(const Key('profilePreferences.confirmTimezone')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Existing repeating items keep'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('profilePreferences.confirmTimezone.submit')),
    );
    await tester.pumpAndSettle();

    final ProfilePreferencesUpdate command = repository.updateCalls.single;
    expect(command.displayName, 'Adult Alpha');
    expect(command.avatar, ProfileAvatarPreset.star);
    expect(command.language, ProfileLanguage.korean);
    expect(command.profileTimezone, 'America/New_York');
    expect(command.householdTimezone, 'Europe/London');
    expect(command.expectedHouseholdVersion, 4);
    expect(sink.appliedLanguageCodes, <String?>['en', 'ko']);
    expect(find.byKey(const Key('profilePreferences.saved')), findsOneWidget);
  });

  testWidgets('Member sees household timezone read-only and saves self only', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(800, 2200), textScaleFactor: 1);
    final ProfilePreferences member = profilePreferencesFixture(
      role: ProfileHouseholdRole.member,
    );
    final ProfilePreferences updated = profilePreferencesFixture(
      displayName: 'Adult Beta',
      profileVersion: 2,
      role: ProfileHouseholdRole.member,
    );
    final FakeProfilePreferencesRepository repository =
        FakeProfilePreferencesRepository(
          loadResult: ProfilePreferencesSucceeded(member),
          updateResults: <ProfilePreferencesResult>[
            ProfilePreferencesSucceeded(updated),
          ],
        );
    await _pumpScreen(tester, repository);

    expect(
      find.byKey(const Key('profilePreferences.householdTimezone')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('profilePreferences.householdTimezoneReadOnly')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('profilePreferences.displayName')),
      'Adult Beta',
    );
    final Finder save = find.byKey(const Key('profilePreferences.save'));
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profilePreferences.confirmTimezone')),
      findsNothing,
    );
    expect(repository.updateCalls.single.householdTimezone, isNull);
    expect(repository.updateCalls.single.expectedHouseholdVersion, isNull);
  });

  testWidgets('version conflict keeps draft and offers authoritative reload', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(800, 2200), textScaleFactor: 1);
    final FakeProfilePreferencesRepository repository =
        FakeProfilePreferencesRepository(
          updateResults: const <ProfilePreferencesResult>[
            ProfilePreferencesFailed(
              ProfilePreferencesFailure(
                ProfilePreferencesFailureKind.profileConflict,
              ),
            ),
          ],
        );
    await _pumpScreen(tester, repository);
    await tester.enterText(
      find.byKey(const Key('profilePreferences.displayName')),
      'Unsaved draft',
    );
    final Finder save = find.byKey(const Key('profilePreferences.save'));
    await tester.scrollUntilVisible(
      save,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profilePreferences.reloadConflict')),
      findsOneWidget,
    );
    expect(find.text('Unsaved draft'), findsOneWidget);
  });

  testWidgets('authoritative refresh replaces the displayed language', (
    WidgetTester tester,
  ) async {
    final FakeProfilePreferencesRepository repository =
        FakeProfilePreferencesRepository();
    final FakeProfileLocalePreferenceSink sink =
        FakeProfileLocalePreferenceSink();
    await _pumpScreen(tester, repository, sink: sink);

    final Finder language = find.byKey(
      const Key('profilePreferences.language'),
    );
    expect(
      tester.state<FormFieldState<ProfileLanguage>>(language).value,
      ProfileLanguage.english,
    );

    repository.loadResult = ProfilePreferencesSucceeded(
      profilePreferencesFixture(
        language: ProfileLanguage.korean,
        profileVersion: 2,
      ),
    );
    await tester.tap(find.byKey(const Key('profilePreferences.refresh')));
    await tester.pumpAndSettle();

    expect(
      tester.state<FormFieldState<ProfileLanguage>>(language).value,
      ProfileLanguage.korean,
    );
    expect(sink.appliedLanguageCodes, <String?>['en', 'ko']);
  });

  testWidgets('regional draft updates preview before any save mutation', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(800, 1600), textScaleFactor: 1);
    final FakeProfilePreferencesRepository repository =
        FakeProfilePreferencesRepository();
    final FakeProfileLocalePreferenceSink sink =
        FakeProfileLocalePreferenceSink();
    final _QueuedTimezoneCatalogRepository catalogRepository =
        _QueuedTimezoneCatalogRepository(<TimezoneCatalogResult>[
          TimezoneCatalogSucceeded(_testTimezoneCatalog()),
        ]);
    await _pumpScreen(
      tester,
      repository,
      sink: sink,
      timezoneCatalogRepository: catalogRepository,
      timezonePreviewClock: () => DateTime.utc(2026, 8, 9, 6, 30),
    );

    expect(find.byKey(const Key('timezonePreview.panel')), findsOneWidget);
    expect(_textForKey(tester, 'timezonePreview.personal.time'), '3:30 PM');
    expect(_textForKey(tester, 'timezonePreview.household.time'), '3:30 PM');

    await _selectTimezone(
      tester,
      fieldKey: 'profilePreferences.profileTimezone',
      query: 'new york',
      identifier: 'America/New_York',
    );
    await _selectTimezone(
      tester,
      fieldKey: 'profilePreferences.householdTimezone',
      query: 'london',
      identifier: 'Europe/London',
    );
    final Finder language = find.byKey(
      const Key('profilePreferences.language'),
    );
    await tester.ensureVisible(language);
    await tester.tap(language);
    await tester.pumpAndSettle();
    await tester.tap(find.text('한국어').last);
    await tester.pumpAndSettle();

    expect(_textForKey(tester, 'timezonePreview.personal.time'), '오전 2:30');
    expect(_textForKey(tester, 'timezonePreview.household.time'), '오전 7:30');
    expect(
      _textForKey(tester, 'timezonePreview.personal.date'),
      contains('2026년'),
    );
    expect(repository.updateCalls, isEmpty);
    expect(sink.appliedLanguageCodes, <String?>['en']);
  });

  testWidgets('controls remain usable at 200 percent pseudo text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpScreen(
      tester,
      FakeProfilePreferencesRepository(),
      locale: const Locale('en', 'XA'),
    );

    final Finder save = find.byKey(const Key('profilePreferences.save'));
    await tester.ensureVisible(save);
    await tester.pump();
    expect(tester.getSize(save).height, greaterThanOrEqualTo(48));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'XA'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return TimezonePickerSheet(
                repository: _QueuedTimezoneCatalogRepository(
                  <TimezoneCatalogResult>[
                    TimezoneCatalogSucceeded(_testTimezoneCatalog()),
                  ],
                ),
                selectedTimezone: 'Asia/Seoul',
                title: AppLocalizations.of(
                  context,
                ).profilePreferencesPersonalTimezonePickerTitle,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('timezonePicker.sheet')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('timezonePicker.close'))).height,
      greaterThanOrEqualTo(48),
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('timezonePicker.search')),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const Key('timezonePicker.search')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'catalog failure preserves selection and retry restores results',
    (WidgetTester tester) async {
      final _QueuedTimezoneCatalogRepository catalogRepository =
          _QueuedTimezoneCatalogRepository(<TimezoneCatalogResult>[
            const TimezoneCatalogFailed(TimezoneCatalogFailureKind.unavailable),
            const TimezoneCatalogFailed(TimezoneCatalogFailureKind.unavailable),
            TimezoneCatalogSucceeded(_testTimezoneCatalog()),
          ]);
      await _pumpScreen(
        tester,
        FakeProfilePreferencesRepository(),
        timezoneCatalogRepository: catalogRepository,
      );

      final Finder field = find.byKey(
        const Key('profilePreferences.profileTimezone'),
      );
      await tester.ensureVisible(field);
      await tester.pumpAndSettle();
      await tester.tap(field);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('timezonePicker.failure')), findsOneWidget);
      expect(find.text('Asia/Seoul'), findsWidgets);
      await tester.tap(find.byKey(const Key('timezonePicker.retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('timezonePicker.results')), findsOneWidget);
      expect(catalogRepository.loadCount, 3);

      await tester.tap(find.byKey(const Key('timezonePicker.close')));
      await tester.pumpAndSettle();
      final EditableText editable = tester.widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      );
      expect(editable.readOnly, isTrue);
      expect(editable.controller.text, 'Asia/Seoul');
    },
  );
}

Future<void> _pumpScreen(
  WidgetTester tester,
  FakeProfilePreferencesRepository repository, {
  FakeProfileLocalePreferenceSink? sink,
  TimezoneCatalogRepository? timezoneCatalogRepository,
  TimezonePreviewClock? timezonePreviewClock,
  Locale locale = const Locale('en'),
}) async {
  final ProfilePreferencesController controller = ProfilePreferencesController(
    repository,
    sink ?? FakeProfileLocalePreferenceSink(),
  );
  final ProviderContainer container = ProviderContainer(
    overrides: [
      profilePreferencesControllerProvider.overrideWithValue(controller),
      if (timezoneCatalogRepository != null)
        timezoneCatalogRepositoryProvider.overrideWithValue(
          timezoneCatalogRepository,
        ),
      if (timezonePreviewClock != null)
        timezonePreviewClockProvider.overrideWithValue(timezonePreviewClock),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    unawaited(controller.dispose());
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ProfilePreferencesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _selectTimezone(
  WidgetTester tester, {
  required String fieldKey,
  required String query,
  required String identifier,
}) async {
  final Finder field = find.byKey(Key(fieldKey));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('timezonePicker.sheet')), findsOneWidget);

  await tester.enterText(find.byKey(const Key('timezonePicker.search')), query);
  await tester.pumpAndSettle();
  final Finder result = find.byKey(Key('timezonePicker.result.$identifier'));
  await tester.ensureVisible(result);
  await tester.tap(result);
  await tester.pumpAndSettle();
}

final class _QueuedTimezoneCatalogRepository
    implements TimezoneCatalogRepository {
  _QueuedTimezoneCatalogRepository(this._results);

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

TimezoneCatalog _testTimezoneCatalog() {
  return TimezoneCatalog.tryCreate(<TimezoneCatalogEntry>[
    TimezoneCatalogEntry.tryCreate(
      identifier: 'UTC',
      currentUtcOffsetMinutes: 0,
      isDaylightSaving: false,
    )!,
    TimezoneCatalogEntry.tryCreate(
      identifier: 'Asia/Seoul',
      currentUtcOffsetMinutes: 9 * 60,
      isDaylightSaving: false,
    )!,
    TimezoneCatalogEntry.tryCreate(
      identifier: 'America/New_York',
      currentUtcOffsetMinutes: -4 * 60,
      isDaylightSaving: true,
    )!,
    TimezoneCatalogEntry.tryCreate(
      identifier: 'Europe/London',
      currentUtcOffsetMinutes: 60,
      isDaylightSaving: true,
    )!,
  ])!;
}

String _textForKey(WidgetTester tester, String key) {
  return tester.widget<Text>(find.byKey(Key(key))).data!;
}

void _configureView(
  WidgetTester tester, {
  required Size size,
  required double textScaleFactor,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
