import 'dart:async';

import 'package:kinflow_app/features/settings/application/ports/profile_locale_preference_sink.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';

final class ProfilePreferencesController {
  ProfilePreferencesController(this._repository, this._localeSink);

  final ProfilePreferencesRepository _repository;
  final ProfileLocalePreferenceSink _localeSink;
  final StreamController<ProfilePreferencesState> _states =
      StreamController<ProfilePreferencesState>.broadcast(sync: true);

  ProfilePreferencesState _state = const ProfilePreferencesInitial();
  Future<void> _pending = Future<void>.value();
  String? _scopeKey;
  var _scopeGeneration = 0;
  bool _busy = false;
  bool _disposed = false;

  ProfilePreferencesState get state => _state;

  Stream<ProfilePreferencesState> get states => _states.stream;

  Future<void> synchronize(String? scopeKey) {
    if (_disposed) return Future<void>.value();
    if (scopeKey == null) {
      _scopeKey = null;
      _scopeGeneration += 1;
      _localeSink.apply(null);
      _emit(const ProfilePreferencesInitial());
      return Future<void>.value();
    }
    if (_scopeKey == scopeKey && (_state is ProfilePreferencesReady || _busy)) {
      return _pending;
    }
    _scopeKey = scopeKey;
    _scopeGeneration += 1;
    if (_busy) {
      final int generation = _scopeGeneration;
      return _pending.whenComplete(() {
        if (!_disposed && generation == _scopeGeneration) {
          return load();
        }
      });
    }
    return load();
  }

  Future<void> load({bool preserveContent = false}) {
    if (_busy || _disposed) return _pending;
    _busy = true;
    final ProfilePreferencesReady? fallback =
        preserveContent && _state is ProfilePreferencesReady
        ? _state as ProfilePreferencesReady
        : null;
    _emit(
      fallback == null
          ? const ProfilePreferencesLoading()
          : ProfilePreferencesReady(
              preferences: fallback.preferences,
              isRefreshing: true,
              saveCount: fallback.saveCount,
            ),
    );
    final int generation = _scopeGeneration;
    _pending = _load(fallback, generation).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> save({
    required String displayName,
    required ProfileAvatarPreset? avatar,
    required ProfileLanguage language,
    required String profileTimezone,
    required String householdTimezone,
  }) {
    if (_busy || _disposed || _state is! ProfilePreferencesReady) {
      return _pending;
    }
    final ProfilePreferencesReady ready = _state as ProfilePreferencesReady;
    final ProfilePreferencesUpdate? update = ProfilePreferencesUpdate.tryCreate(
      current: ready.preferences,
      displayName: displayName,
      avatar: avatar,
      language: language,
      profileTimezone: profileTimezone,
      householdTimezone: householdTimezone,
    );
    if (update == null) {
      _emit(
        ProfilePreferencesReady(
          preferences: ready.preferences,
          failure: const ProfilePreferencesFailure(
            ProfilePreferencesFailureKind.invalidInput,
          ),
          saveCount: ready.saveCount,
        ),
      );
      return Future<void>.value();
    }
    _busy = true;
    _emit(
      ProfilePreferencesReady(
        preferences: ready.preferences,
        isSaving: true,
        saveCount: ready.saveCount,
      ),
    );
    final int generation = _scopeGeneration;
    _pending = _save(
      ready,
      update,
      generation,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _load(ProfilePreferencesReady? fallback, int generation) async {
    final ProfilePreferencesResult result;
    try {
      result = await _repository.load();
    } on Object {
      if (generation != _scopeGeneration) return;
      _loadFailure(fallback, ProfilePreferencesFailureKind.internal);
      return;
    }
    if (generation != _scopeGeneration) return;
    switch (result) {
      case ProfilePreferencesSucceeded(:final preferences):
        _localeSink.apply(preferences.language.code);
        _emit(
          ProfilePreferencesReady(
            preferences: preferences,
            saveCount: fallback?.saveCount ?? 0,
          ),
        );
      case ProfilePreferencesFailed(:final failure):
        _loadFailure(fallback, failure.kind);
    }
  }

  Future<void> _save(
    ProfilePreferencesReady previous,
    ProfilePreferencesUpdate update,
    int generation,
  ) async {
    final ProfilePreferencesResult result;
    try {
      result = await _repository.update(update);
    } on Object {
      if (generation != _scopeGeneration) return;
      _saveFailure(previous, ProfilePreferencesFailureKind.internal);
      return;
    }
    if (generation != _scopeGeneration) return;
    switch (result) {
      case ProfilePreferencesSucceeded(:final preferences):
        _localeSink.apply(preferences.language.code);
        _emit(
          ProfilePreferencesReady(
            preferences: preferences,
            saveCount: previous.saveCount + 1,
          ),
        );
      case ProfilePreferencesFailed(:final failure):
        _saveFailure(previous, failure.kind);
    }
  }

  void _loadFailure(
    ProfilePreferencesReady? fallback,
    ProfilePreferencesFailureKind kind,
  ) {
    final ProfilePreferencesFailure failure = ProfilePreferencesFailure(kind);
    _emit(
      fallback == null
          ? ProfilePreferencesLoadFailed(failure)
          : ProfilePreferencesReady(
              preferences: fallback.preferences,
              failure: failure,
              saveCount: fallback.saveCount,
            ),
    );
  }

  void _saveFailure(
    ProfilePreferencesReady previous,
    ProfilePreferencesFailureKind kind,
  ) {
    _emit(
      ProfilePreferencesReady(
        preferences: previous.preferences,
        failure: ProfilePreferencesFailure(kind),
        saveCount: previous.saveCount,
      ),
    );
  }

  void _emit(ProfilePreferencesState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }
}
