import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/providers/timezone_catalog_dependencies.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/presentation/widgets/timezone_date_time_preview.dart';
import 'package:kinflow_app/app/presentation/widgets/timezone_picker_sheet.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/domain/failures/profile_preferences_failure.dart';
import 'package:kinflow_app/features/settings/presentation/profile_preferences_failure_message.dart';
import 'package:kinflow_app/features/settings/presentation/providers/profile_preferences_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

final RegExp _settingsTimezonePattern = RegExp(
  r'^[A-Za-z0-9_+.-]+(?:/[A-Za-z0-9_+.-]+)+$',
);

class ProfilePreferencesScreen extends ConsumerStatefulWidget {
  const ProfilePreferencesScreen({super.key});

  @override
  ConsumerState<ProfilePreferencesScreen> createState() =>
      _ProfilePreferencesScreenState();
}

class _ProfilePreferencesScreenState
    extends ConsumerState<ProfilePreferencesScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _profileTimezoneController =
      TextEditingController();
  final TextEditingController _householdTimezoneController =
      TextEditingController();
  ProfileAvatarPreset? _avatar;
  ProfileLanguage _language = ProfileLanguage.english;
  String? _appliedMarker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool hasContent =
          ref.read(profilePreferencesProvider) is ProfilePreferencesReady;
      unawaited(
        ref
            .read(profilePreferencesProvider.notifier)
            .load(preserveContent: hasContent),
      );
    });
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _profileTimezoneController.dispose();
    _householdTimezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ProfilePreferencesState state = ref.watch(profilePreferencesProvider);
    final bool busy = state is ProfilePreferencesReady && state.busy;
    return AppResponsiveScaffold(
      key: const Key('profilePreferences.screen'),
      title: localizations.profilePreferencesTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('profilePreferences.refresh'),
          onPressed: busy
              ? null
              : () => unawaited(
                  ref
                      .read(profilePreferencesProvider.notifier)
                      .load(preserveContent: true),
                ),
          tooltip: localizations.retryAction,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const Key('profilePreferences.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: _body(localizations, state),
    );
  }

  Widget _body(AppLocalizations localizations, ProfilePreferencesState state) {
    return switch (state) {
      ProfilePreferencesInitial() ||
      ProfilePreferencesLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('profilePreferences.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.profilePreferencesLoadingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      ProfilePreferencesLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('profilePreferences.error'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.manage_accounts_outlined,
              size: AppIconSize.status,
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                profilePreferencesFailureMessage(localizations, failure),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('profilePreferences.retry'),
              onPressed: () => unawaited(
                ref.read(profilePreferencesProvider.notifier).load(),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      ProfilePreferencesReady() => _ready(localizations, state),
    };
  }

  Widget _ready(AppLocalizations localizations, ProfilePreferencesReady state) {
    _applyAuthoritativeState(state);
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        key: const Key('profilePreferences.content'),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayoutTokens.statusContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _introCard(localizations),
                  if (state.isRefreshing || state.isSaving) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(),
                  ],
                  if (state.failure != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _failureBanner(localizations, state.failure!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _profileCard(localizations, state),
                  const SizedBox(height: AppSpacing.md),
                  _regionalCard(localizations, state),
                  const SizedBox(height: AppSpacing.md),
                  _householdCard(localizations, state),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const Key('profilePreferences.save'),
                    onPressed: state.busy
                        ? null
                        : () => unawaited(_save(localizations, state)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        if (state.isSaving)
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.save_outlined),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            localizations.profilePreferencesSaveAction,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _introCard(AppLocalizations localizations) {
    return Card(
      key: const Key('profilePreferences.intro'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              localizations.profilePreferencesIntroHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.profilePreferencesIntroBody),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(
    AppLocalizations localizations,
    ProfilePreferencesReady state,
  ) {
    return Card(
      key: const Key('profilePreferences.profileCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.profilePreferencesProfileHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              key: const Key('profilePreferences.displayName'),
              controller: _displayNameController,
              enabled: !state.busy,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: localizations.profilePreferencesDisplayNameLabel,
              ),
              validator: (String? value) {
                final String normalized = value?.trim() ?? '';
                return normalized.isEmpty ||
                        normalized.length > 80 ||
                        RegExp(r'[\x00-\x1f\x7f]').hasMatch(normalized)
                    ? localizations.profilePreferencesDisplayNameValidation
                    : null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.profilePreferencesAvatarHeading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                _avatarChip(
                  localizations: localizations,
                  keyValue: 'none',
                  preset: null,
                  icon: Icons.person_outline,
                  label: localizations.profilePreferencesAvatarNone,
                  enabled: !state.busy,
                ),
                _avatarChip(
                  localizations: localizations,
                  keyValue: 'sun',
                  preset: ProfileAvatarPreset.sun,
                  icon: Icons.wb_sunny_outlined,
                  label: localizations.profilePreferencesAvatarSun,
                  enabled: !state.busy,
                ),
                _avatarChip(
                  localizations: localizations,
                  keyValue: 'heart',
                  preset: ProfileAvatarPreset.heart,
                  icon: Icons.favorite_outline,
                  label: localizations.profilePreferencesAvatarHeart,
                  enabled: !state.busy,
                ),
                _avatarChip(
                  localizations: localizations,
                  keyValue: 'leaf',
                  preset: ProfileAvatarPreset.leaf,
                  icon: Icons.eco_outlined,
                  label: localizations.profilePreferencesAvatarLeaf,
                  enabled: !state.busy,
                ),
                _avatarChip(
                  localizations: localizations,
                  keyValue: 'star',
                  preset: ProfileAvatarPreset.star,
                  icon: Icons.star_outline,
                  label: localizations.profilePreferencesAvatarStar,
                  enabled: !state.busy,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarChip({
    required AppLocalizations localizations,
    required String keyValue,
    required ProfileAvatarPreset? preset,
    required IconData icon,
    required String label,
    required bool enabled,
  }) {
    return ChoiceChip(
      key: Key('profilePreferences.avatar.$keyValue'),
      avatar: Icon(icon),
      label: Text(label),
      selected: _avatar == preset,
      onSelected: enabled
          ? (bool selected) {
              if (selected) setState(() => _avatar = preset);
            }
          : null,
    );
  }

  Widget _regionalCard(
    AppLocalizations localizations,
    ProfilePreferencesReady state,
  ) {
    return Card(
      key: const Key('profilePreferences.regionalCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.profilePreferencesRegionalHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            KeyedSubtree(
              key: ValueKey<String>(
                'profilePreferences.languageState.$_appliedMarker',
              ),
              child: DropdownButtonFormField<ProfileLanguage>(
                key: const Key('profilePreferences.language'),
                initialValue: _language,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: localizations.profilePreferencesLanguageLabel,
                ),
                items: <DropdownMenuItem<ProfileLanguage>>[
                  DropdownMenuItem<ProfileLanguage>(
                    value: ProfileLanguage.english,
                    child: Text(
                      localizations.profilePreferencesLanguageEnglish,
                    ),
                  ),
                  DropdownMenuItem<ProfileLanguage>(
                    value: ProfileLanguage.korean,
                    child: Text(localizations.profilePreferencesLanguageKorean),
                  ),
                ],
                onChanged: state.busy
                    ? null
                    : (ProfileLanguage? value) {
                        if (value != null) setState(() => _language = value);
                      },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TimezoneSelectionFormField(
              fieldKey: const Key('profilePreferences.profileTimezone'),
              controller: _profileTimezoneController,
              repository: ref.read(timezoneCatalogRepositoryProvider),
              pickerTitle:
                  localizations.profilePreferencesPersonalTimezonePickerTitle,
              labelText: localizations.profilePreferencesPersonalTimezoneLabel,
              helperText:
                  localizations.profilePreferencesPersonalTimezoneHelper,
              enabled: !state.busy,
              validator: (String? value) => _validTimezone(value)
                  ? null
                  : localizations.profilePreferencesTimezoneValidation,
              onSelected: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            TimezoneDateTimePreviewPanel(
              repository: ref.read(timezoneCatalogRepositoryProvider),
              clock: ref.read(timezonePreviewClockProvider),
              languageCode: _language.code,
              items: <TimezoneDateTimePreviewItem>[
                TimezoneDateTimePreviewItem(
                  keyValue: 'personal',
                  label: localizations.timezonePreviewPersonalLabel,
                  timezone: _profileTimezoneController.text.trim(),
                ),
                TimezoneDateTimePreviewItem(
                  keyValue: 'household',
                  label: localizations.timezonePreviewHouseholdLabel,
                  timezone: _householdTimezoneController.text.trim(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _householdCard(
    AppLocalizations localizations,
    ProfilePreferencesReady state,
  ) {
    final ProfilePreferences preferences = state.preferences;
    return Card(
      key: const Key('profilePreferences.householdCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.profilePreferencesHouseholdHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(preferences.householdName),
            const SizedBox(height: AppSpacing.md),
            if (preferences.canManageHouseholdTimezone)
              TimezoneSelectionFormField(
                fieldKey: const Key('profilePreferences.householdTimezone'),
                controller: _householdTimezoneController,
                repository: ref.read(timezoneCatalogRepositoryProvider),
                pickerTitle: localizations
                    .profilePreferencesHouseholdTimezonePickerTitle,
                labelText:
                    localizations.profilePreferencesHouseholdTimezoneLabel,
                helperText:
                    localizations.profilePreferencesHouseholdTimezoneHelper,
                enabled: !state.busy,
                validator: (String? value) => _validTimezone(value)
                    ? null
                    : localizations.profilePreferencesTimezoneValidation,
                onSelected: (_) => setState(() {}),
              )
            else
              ListTile(
                key: const Key('profilePreferences.householdTimezoneReadOnly'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(
                  localizations.profilePreferencesHouseholdTimezoneLabel,
                ),
                subtitle: Text(
                  localizations.profilePreferencesHouseholdTimezoneReadOnly(
                    preferences.householdTimezone,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Icon(Icons.info_outline),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            localizations.profilePreferencesImpactHeading,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(localizations.profilePreferencesImpactBody),
                    const SizedBox(height: AppSpacing.xs),
                    Text(localizations.profilePreferencesImpactPreservedBody),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failureBanner(
    AppLocalizations localizations,
    ProfilePreferencesFailure failure,
  ) {
    final bool conflict =
        failure.kind == ProfilePreferencesFailureKind.profileConflict ||
        failure.kind == ProfilePreferencesFailureKind.householdConflict;
    return Material(
      key: const Key('profilePreferences.failure'),
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              liveRegion: true,
              child: Text(
                profilePreferencesFailureMessage(localizations, failure),
              ),
            ),
            if (conflict) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('profilePreferences.reloadConflict'),
                onPressed: () => unawaited(
                  ref.read(profilePreferencesProvider.notifier).load(),
                ),
                icon: const Icon(Icons.sync),
                label: Text(localizations.retryAction),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _applyAuthoritativeState(ProfilePreferencesReady state) {
    final String marker =
        '${state.preferences.snapshotFingerprint}|${state.saveCount}';
    if (_appliedMarker == marker) return;
    final ProfilePreferences preferences = state.preferences;
    _displayNameController.text = preferences.displayName;
    _profileTimezoneController.text = preferences.profileTimezone;
    _householdTimezoneController.text = preferences.householdTimezone;
    _avatar = preferences.avatar;
    _language = preferences.language;
    _appliedMarker = marker;
  }

  Future<void> _save(
    AppLocalizations localizations,
    ProfilePreferencesReady state,
  ) async {
    if (_formKey.currentState?.validate() != true) return;
    final bool changesHousehold =
        _householdTimezoneController.text.trim() !=
        state.preferences.householdTimezone;
    if (changesHousehold &&
        !await _confirmHouseholdTimezoneChange(localizations)) {
      return;
    }
    final int before = state.saveCount;
    await ref
        .read(profilePreferencesProvider.notifier)
        .save(
          displayName: _displayNameController.text,
          avatar: _avatar,
          language: _language,
          profileTimezone: _profileTimezoneController.text,
          householdTimezone: _householdTimezoneController.text,
        );
    if (!mounted) return;
    final ProfilePreferencesState result = ref.read(profilePreferencesProvider);
    if (result is ProfilePreferencesReady && result.saveCount > before) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('profilePreferences.saved'),
          content: Text(
            AppLocalizations.of(context).profilePreferencesSavedMessage,
          ),
        ),
      );
    }
  }

  Future<bool> _confirmHouseholdTimezoneChange(
    AppLocalizations localizations,
  ) async {
    return await showAppDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              key: const Key('profilePreferences.confirmTimezone'),
              title: Text(localizations.profilePreferencesConfirmTimezoneTitle),
              content: Text(
                localizations.profilePreferencesConfirmTimezoneBody,
              ),
              actions: <Widget>[
                TextButton(
                  key: const Key('profilePreferences.confirmTimezone.cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(localizations.profilePreferencesCancelAction),
                ),
                FilledButton(
                  key: const Key('profilePreferences.confirmTimezone.submit'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(
                    localizations.profilePreferencesConfirmTimezoneAction,
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  bool _validTimezone(String? value) {
    final String normalized = value?.trim() ?? '';
    return normalized == 'UTC' ||
        (normalized.length <= 100 &&
            !normalized.startsWith('posix/') &&
            !normalized.startsWith('right/') &&
            _settingsTimezonePattern.hasMatch(normalized));
  }
}
