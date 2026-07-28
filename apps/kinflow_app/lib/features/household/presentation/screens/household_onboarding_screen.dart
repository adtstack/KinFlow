import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_state.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class HouseholdOnboardingScreen extends ConsumerStatefulWidget {
  const HouseholdOnboardingScreen({super.key});

  @override
  ConsumerState<HouseholdOnboardingScreen> createState() =>
      _HouseholdOnboardingScreenState();
}

class _HouseholdOnboardingScreenState
    extends ConsumerState<HouseholdOnboardingScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _ownerDisplayNameController =
      TextEditingController();
  final TextEditingController _householdNameController =
      TextEditingController();
  final TextEditingController _timezoneController = TextEditingController(
    text: 'Asia/Seoul',
  );
  String? _localeCode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localeCode ??= _supportedLocale(
      Localizations.localeOf(context).languageCode,
    );
  }

  @override
  void dispose() {
    _ownerDisplayNameController.dispose();
    _householdNameController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final FirstHouseholdOnboardingState state = ref.watch(
      firstHouseholdOnboardingProvider,
    );
    final bool submitting = state is FirstHouseholdOnboardingSubmitting;
    final HouseholdFailure? failure = switch (state) {
      FirstHouseholdOnboardingFailed(:final failure) => failure,
      _ => null,
    };

    return Scaffold(
      key: const Key('household.onboarding'),
      appBar: AppBar(
        title: Text(localizations.householdOnboardingTitle),
        actions: <Widget>[
          IconButton(
            key: const Key('auth.logout'),
            onPressed: submitting
                ? null
                : () => unawaited(
                    ref.read(authLifecycleProvider.notifier).logout(),
                  ),
            tooltip: localizations.authLogoutAction,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              key: const Key('household.onboardingScroll'),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayoutTokens.dialogContentMaxWidth,
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            localizations.householdOnboardingHeading,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          localizations.householdOnboardingBody,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        TextFormField(
                          key: const Key('household.ownerDisplayName'),
                          controller: _ownerDisplayNameController,
                          enabled: !submitting,
                          maxLength: 80,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: localizations.ownerDisplayNameLabel,
                          ),
                          validator: (String? value) => _validateName(
                            value,
                            localizations.householdNameValidation,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          key: const Key('household.name'),
                          controller: _householdNameController,
                          enabled: !submitting,
                          maxLength: 80,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: localizations.householdNameLabel,
                          ),
                          validator: (String? value) => _validateName(
                            value,
                            localizations.householdNameValidation,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        DropdownButtonFormField<String>(
                          key: const Key('household.locale'),
                          initialValue: _localeCode,
                          decoration: InputDecoration(
                            labelText: localizations.householdLocaleLabel,
                          ),
                          items: const <DropdownMenuItem<String>>[
                            DropdownMenuItem<String>(
                              value: 'ko',
                              child: Text('한국어'),
                            ),
                            DropdownMenuItem<String>(
                              value: 'en',
                              child: Text('English'),
                            ),
                          ],
                          onChanged: submitting
                              ? null
                              : (String? value) {
                                  setState(() => _localeCode = value);
                                },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          key: const Key('household.timezone'),
                          controller: _timezoneController,
                          enabled: !submitting,
                          maxLength: 100,
                          textInputAction: TextInputAction.done,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: localizations.householdTimezoneLabel,
                            helperText: localizations.householdTimezoneHint,
                          ),
                          validator: (String? value) {
                            final String normalized = value?.trim() ?? '';
                            return normalized.isEmpty
                                ? localizations.householdTimezoneValidation
                                : null;
                          },
                          onFieldSubmitted: submitting
                              ? null
                              : (_) => unawaited(_submit()),
                        ),
                        if (failure != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          Semantics(
                            key: const Key('household.onboardingError'),
                            container: true,
                            liveRegion: true,
                            child: Text(
                              _failureMessage(localizations, failure.kind),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          key: const Key('household.create'),
                          onPressed: submitting ? null : _submit,
                          child: submitting
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    const SizedBox.square(
                                      dimension: AppIconSize.inline,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(localizations.householdCreatingAction),
                                  ],
                                )
                              : Text(localizations.householdCreateAction),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(firstHouseholdOnboardingProvider.notifier)
        .submit(
          householdName: _householdNameController.text,
          ownerDisplayName: _ownerDisplayNameController.text,
          locale: _localeCode ?? 'en',
          timezone: _timezoneController.text,
        );
    if (!mounted) {
      return;
    }
    final FirstHouseholdOnboardingState state = ref.read(
      firstHouseholdOnboardingProvider,
    );
    if (state is FirstHouseholdOnboardingSucceeded) {
      await ref
          .read(authLifecycleProvider.notifier)
          .markActiveHousehold(state.household);
    }
  }

  String? _validateName(String? value, String message) {
    final String normalized = value?.trim() ?? '';
    if (normalized.isEmpty ||
        normalized.length > 80 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(normalized)) {
      return message;
    }
    return null;
  }

  String _supportedLocale(String languageCode) {
    return languageCode == 'ko' ? 'ko' : 'en';
  }

  String _failureMessage(
    AppLocalizations localizations,
    HouseholdFailureKind kind,
  ) {
    return switch (kind) {
      HouseholdFailureKind.invalidInput =>
        localizations.householdInvalidInputError,
      HouseholdFailureKind.activeHouseholdExists =>
        localizations.householdAlreadyExistsError,
      HouseholdFailureKind.idempotencyConflict =>
        localizations.householdRequestConflictError,
      HouseholdFailureKind.unauthenticated =>
        localizations.authSessionExpiredBody,
      HouseholdFailureKind.profileUnavailable ||
      HouseholdFailureKind.temporarilyUnavailable ||
      HouseholdFailureKind.invalidPayload ||
      HouseholdFailureKind.internal => localizations.householdCreateError,
    };
  }
}
