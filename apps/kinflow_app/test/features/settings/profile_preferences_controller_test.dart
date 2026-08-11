import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_controller.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';

import '../../support/fakes/fake_profile_preferences_dependencies.dart';

void main() {
  test('authoritative load applies saved locale', () async {
    final FakeProfileLocalePreferenceSink sink =
        FakeProfileLocalePreferenceSink();
    final ProfilePreferencesController controller =
        ProfilePreferencesController(FakeProfilePreferencesRepository(), sink);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, isA<ProfilePreferencesReady>());
    expect(sink.appliedLanguageCodes, <String?>['en']);
  });

  test(
    'successful atomic save applies only returned server projection',
    () async {
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
      final ProfilePreferencesController controller =
          ProfilePreferencesController(repository, sink);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.save(
        displayName: ' Adult Alpha ',
        avatar: ProfileAvatarPreset.star,
        language: ProfileLanguage.korean,
        profileTimezone: 'America/New_York',
        householdTimezone: 'Europe/London',
      );

      final ProfilePreferencesReady state =
          controller.state as ProfilePreferencesReady;
      expect(state.preferences, same(updated));
      expect(state.saveCount, 1);
      expect(repository.updateCalls.single.expectedHouseholdVersion, 4);
      expect(sink.appliedLanguageCodes, <String?>['en', 'ko']);
    },
  );

  test('version conflict preserves prior state and locale', () async {
    final FakeProfilePreferencesRepository repository =
        FakeProfilePreferencesRepository(
          updateResults: const <ProfilePreferencesResult>[
            ProfilePreferencesFailed(
              ProfilePreferencesFailure(
                ProfilePreferencesFailureKind.householdConflict,
              ),
            ),
          ],
        );
    final FakeProfileLocalePreferenceSink sink =
        FakeProfileLocalePreferenceSink();
    final ProfilePreferencesController controller =
        ProfilePreferencesController(repository, sink);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.save(
      displayName: 'Uncommitted name',
      avatar: null,
      language: ProfileLanguage.korean,
      profileTimezone: 'UTC',
      householdTimezone: 'Europe/London',
    );

    final ProfilePreferencesReady state =
        controller.state as ProfilePreferencesReady;
    expect(state.preferences.displayName, 'Adult A');
    expect(
      state.failure?.kind,
      ProfilePreferencesFailureKind.householdConflict,
    );
    expect(state.saveCount, 0);
    expect(sink.appliedLanguageCodes, <String?>['en']);
  });

  test('invalid draft never reaches repository', () async {
    final FakeProfilePreferencesRepository repository =
        FakeProfilePreferencesRepository();
    final ProfilePreferencesController controller =
        ProfilePreferencesController(
          repository,
          FakeProfileLocalePreferenceSink(),
        );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.save(
      displayName: '',
      avatar: null,
      language: ProfileLanguage.english,
      profileTimezone: 'Not/A_Real_Zone',
      householdTimezone: 'Asia/Seoul',
    );

    expect(repository.updateCalls, isEmpty);
    expect(
      (controller.state as ProfilePreferencesReady).failure?.kind,
      ProfilePreferencesFailureKind.invalidInput,
    );
  });

  test('double submit sends one command while save is pending', () async {
    final Completer<ProfilePreferencesResult> completer =
        Completer<ProfilePreferencesResult>();
    final FakeProfilePreferencesRepository repository =
        FakeProfilePreferencesRepository(updateCompleter: completer);
    final ProfilePreferencesController controller =
        ProfilePreferencesController(
          repository,
          FakeProfileLocalePreferenceSink(),
        );
    addTearDown(controller.dispose);
    await controller.load();

    final Future<void> first = controller.save(
      displayName: 'Adult Alpha',
      avatar: null,
      language: ProfileLanguage.english,
      profileTimezone: 'Asia/Seoul',
      householdTimezone: 'Asia/Seoul',
    );
    final Future<void> second = controller.save(
      displayName: 'Duplicate',
      avatar: null,
      language: ProfileLanguage.english,
      profileTimezone: 'Asia/Seoul',
      householdTimezone: 'Asia/Seoul',
    );

    expect(repository.updateCalls, hasLength(1));
    completer.complete(
      ProfilePreferencesSucceeded(
        profilePreferencesFixture(displayName: 'Adult Alpha'),
      ),
    );
    await Future.wait(<Future<void>>[first, second]);
    expect(repository.updateCalls, hasLength(1));
  });

  test('logout clears locale and ignores an old in-flight load', () async {
    final Completer<ProfilePreferencesResult> completer =
        Completer<ProfilePreferencesResult>();
    final FakeProfileLocalePreferenceSink sink =
        FakeProfileLocalePreferenceSink();
    final ProfilePreferencesController controller =
        ProfilePreferencesController(
          FakeProfilePreferencesRepository(loadCompleter: completer),
          sink,
        );
    addTearDown(controller.dispose);

    final Future<void> pending = controller.synchronize('user-a|household-a');
    await controller.synchronize(null);
    completer.complete(
      ProfilePreferencesSucceeded(
        profilePreferencesFixture(language: ProfileLanguage.korean),
      ),
    );
    await pending;

    expect(controller.state, isA<ProfilePreferencesInitial>());
    expect(sink.appliedLanguageCodes, <String?>[null]);
  });
}
