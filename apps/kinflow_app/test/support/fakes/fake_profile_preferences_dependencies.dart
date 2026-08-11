import 'dart:async';

import 'package:kinflow_app/features/settings/application/ports/profile_locale_preference_sink.dart';
import 'package:kinflow_app/features/settings/data/datasources/profile_preferences_data_source.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';

const String profilePreferencesProfileId =
    '71000000-0000-4000-8000-000000000001';
const String profilePreferencesHouseholdId =
    '72000000-0000-4000-8000-000000000001';

ProfilePreferences profilePreferencesFixture({
  String displayName = 'Adult A',
  ProfileAvatarPreset? avatar,
  ProfileLanguage language = ProfileLanguage.english,
  String profileTimezone = 'Asia/Seoul',
  int profileVersion = 1,
  String householdName = 'Kim family',
  String householdTimezone = 'Asia/Seoul',
  int householdVersion = 4,
  ProfileHouseholdRole role = ProfileHouseholdRole.owner,
}) {
  return ProfilePreferences.tryCreate(
    profileId: profilePreferencesProfileId,
    displayName: displayName,
    avatarKey: avatar?.key,
    locale: language.code,
    profileTimezone: profileTimezone,
    profileVersion: profileVersion,
    householdId: profilePreferencesHouseholdId,
    householdName: householdName,
    householdTimezone: householdTimezone,
    householdVersion: householdVersion,
    householdRole: role.name,
    canManageHouseholdTimezone:
        role == ProfileHouseholdRole.owner ||
        role == ProfileHouseholdRole.admin,
  )!;
}

ProfilePreferencesDataRecord profilePreferencesRecordFixture({
  String displayName = 'Adult A',
  String? avatarKey,
  String locale = 'en',
  String profileTimezone = 'Asia/Seoul',
  int profileVersion = 1,
  String householdTimezone = 'Asia/Seoul',
  int householdVersion = 4,
  String householdRole = 'owner',
  bool canManageHouseholdTimezone = true,
}) {
  return ProfilePreferencesDataRecord(
    profileId: profilePreferencesProfileId,
    displayName: displayName,
    avatarKey: avatarKey,
    locale: locale,
    profileTimezone: profileTimezone,
    profileVersion: profileVersion,
    householdId: profilePreferencesHouseholdId,
    householdName: 'Kim family',
    householdTimezone: householdTimezone,
    householdVersion: householdVersion,
    householdRole: householdRole,
    canManageHouseholdTimezone: canManageHouseholdTimezone,
  );
}

final class FakeProfilePreferencesRepository
    implements ProfilePreferencesRepository {
  FakeProfilePreferencesRepository({
    ProfilePreferencesResult? loadResult,
    List<ProfilePreferencesResult>? updateResults,
    this.loadCompleter,
    this.updateCompleter,
  }) : loadResult =
           loadResult ??
           ProfilePreferencesSucceeded(profilePreferencesFixture()),
       updateResults = List<ProfilePreferencesResult>.of(
         updateResults ?? <ProfilePreferencesResult>[],
       );

  ProfilePreferencesResult loadResult;
  final List<ProfilePreferencesResult> updateResults;
  final Completer<ProfilePreferencesResult>? loadCompleter;
  final Completer<ProfilePreferencesResult>? updateCompleter;
  final List<ProfilePreferencesUpdate> updateCalls =
      <ProfilePreferencesUpdate>[];
  var loadCount = 0;

  @override
  Future<ProfilePreferencesResult> load() async {
    loadCount += 1;
    final Completer<ProfilePreferencesResult>? completer = loadCompleter;
    return completer == null ? loadResult : completer.future;
  }

  @override
  Future<ProfilePreferencesResult> update(
    ProfilePreferencesUpdate update,
  ) async {
    updateCalls.add(update);
    final Completer<ProfilePreferencesResult>? completer = updateCompleter;
    if (completer != null) return completer.future;
    return updateResults.isEmpty ? loadResult : updateResults.removeAt(0);
  }
}

final class FakeProfilePreferencesDataSource
    implements ProfilePreferencesDataSource {
  FakeProfilePreferencesDataSource({
    ProfilePreferencesDataResult? loadResult,
    ProfilePreferencesDataResult? updateResult,
  }) : loadResult =
           loadResult ??
           ProfilePreferencesDataSucceeded(profilePreferencesRecordFixture()),
       updateResult =
           updateResult ??
           ProfilePreferencesDataSucceeded(profilePreferencesRecordFixture());

  ProfilePreferencesDataResult loadResult;
  ProfilePreferencesDataResult updateResult;
  final List<Map<String, Object?>> updateCalls = <Map<String, Object?>>[];

  @override
  Future<ProfilePreferencesDataResult> load() async => loadResult;

  @override
  Future<ProfilePreferencesDataResult> update({
    required String displayName,
    required String? avatarKey,
    required String locale,
    required String profileTimezone,
    required int expectedProfileVersion,
    required String? householdTimezone,
    required int? expectedHouseholdVersion,
  }) async {
    updateCalls.add(<String, Object?>{
      'displayName': displayName,
      'avatarKey': avatarKey,
      'locale': locale,
      'profileTimezone': profileTimezone,
      'expectedProfileVersion': expectedProfileVersion,
      'householdTimezone': householdTimezone,
      'expectedHouseholdVersion': expectedHouseholdVersion,
    });
    return updateResult;
  }
}

final class FakeProfileLocalePreferenceSink
    implements ProfileLocalePreferenceSink {
  final List<String?> appliedLanguageCodes = <String?>[];

  @override
  void apply(String? languageCode) {
    appliedLanguageCodes.add(languageCode);
  }
}
