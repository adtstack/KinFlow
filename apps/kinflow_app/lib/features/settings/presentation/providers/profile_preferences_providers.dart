import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/features/settings/application/ports/profile_locale_preference_sink.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_controller.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_state.dart';
import 'package:kinflow_app/features/settings/application/unavailable_profile_preferences_repository.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/repositories/profile_preferences_repository.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

final profilePreferencesRepositoryProvider =
    Provider<ProfilePreferencesRepository>((ref) {
      return const UnavailableProfilePreferencesRepository();
    });

final profileLocalePreferenceSinkProvider =
    Provider<ProfileLocalePreferenceSink>((ref) {
      return _RiverpodProfileLocalePreferenceSink(ref);
    });

final profilePreferencesControllerProvider =
    Provider<ProfilePreferencesController>((ref) {
      final ProfilePreferencesController controller =
          ProfilePreferencesController(
            ref.watch(profilePreferencesRepositoryProvider),
            ref.watch(profileLocalePreferenceSinkProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final profilePreferencesProvider =
    NotifierProvider<ProfilePreferencesNotifier, ProfilePreferencesState>(
      ProfilePreferencesNotifier.new,
    );

final class ProfilePreferencesNotifier
    extends Notifier<ProfilePreferencesState> {
  @override
  ProfilePreferencesState build() {
    final ProfilePreferencesController controller = ref.watch(
      profilePreferencesControllerProvider,
    );
    final StreamSubscription<ProfilePreferencesState> subscription = controller
        .states
        .listen((ProfilePreferencesState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> synchronize(String? scopeKey) {
    return ref.read(profilePreferencesControllerProvider).synchronize(scopeKey);
  }

  Future<void> load({bool preserveContent = false}) {
    return ref
        .read(profilePreferencesControllerProvider)
        .load(preserveContent: preserveContent);
  }

  Future<void> save({
    required String displayName,
    required ProfileAvatarPreset? avatar,
    required ProfileLanguage language,
    required String profileTimezone,
    required String householdTimezone,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.profile,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(profilePreferencesControllerProvider)
        .save(
          displayName: displayName,
          avatar: avatar,
          language: language,
          profileTimezone: profileTimezone,
          householdTimezone: householdTimezone,
        );
  }
}

final class _RiverpodProfileLocalePreferenceSink
    implements ProfileLocalePreferenceSink {
  const _RiverpodProfileLocalePreferenceSink(this._ref);

  final Ref _ref;

  @override
  void apply(String? languageCode) {
    _ref
        .read(appLocaleControllerProvider.notifier)
        .applyLanguageCode(languageCode);
  }
}
