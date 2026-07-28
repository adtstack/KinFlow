import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AuthLifecycleState state = ref.watch(authLifecycleProvider);
    final AuthLifecycleNotifier notifier = ref.read(
      authLifecycleProvider.notifier,
    );
    final bool canRequestSignIn = notifier.canRequestSignIn;
    final bool isSignInAvailable = notifier.isSignInAvailable;
    final bool isAuthenticating = state is AuthAuthenticating;
    final String? statusMessage = _statusMessage(
      localizations,
      state,
      isSignInAvailable: isSignInAvailable,
    );

    return Scaffold(
      key: const Key('auth.signIn'),
      body: SafeArea(
        child: ScrollableStatusLayout(
          maxWidth: AppLayoutTokens.dialogContentMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ExcludeSemantics(
                child: Icon(
                  Icons.family_restroom,
                  color: Theme.of(context).colorScheme.primary,
                  size: AppIconSize.status,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  localizations.authSignInTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(localizations.authSignInBody, textAlign: TextAlign.center),
              if (statusMessage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    statusMessage,
                    key: const Key('auth.signIn.status'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                key: const Key('auth.signIn.google'),
                button: true,
                enabled: canRequestSignIn,
                hint: localizations.authGoogleSignInHint,
                label: localizations.authGoogleSignInAction,
                onTap: canRequestSignIn
                    ? () => unawaited(notifier.requestSignIn())
                    : null,
                child: ExcludeSemantics(
                  child: FilledButton.icon(
                    onPressed: canRequestSignIn
                        ? () => unawaited(notifier.requestSignIn())
                        : null,
                    icon: isAuthenticating
                        ? const SizedBox.square(
                            dimension: AppSpacing.md,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(
                      isAuthenticating
                          ? localizations.authSigningInLabel
                          : localizations.authGoogleSignInAction,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _statusMessage(
    AppLocalizations localizations,
    AuthLifecycleState state, {
    required bool isSignInAvailable,
  }) {
    if (state is AuthAuthenticating) {
      return localizations.authSigningInLabel;
    }
    final AuthFailure? failure = state.failure;
    if (failure == null) {
      return isSignInAvailable
          ? null
          : localizations.authProviderUnavailableBody;
    }
    return switch (failure.kind) {
      AuthFailureKind.sessionExpired ||
      AuthFailureKind.sessionRevoked => localizations.authSessionExpiredBody,
      AuthFailureKind.localPurgeFailed =>
        localizations.authLocalStateLockedBody,
      _ => localizations.authProviderUnavailableBody,
    };
  }
}
