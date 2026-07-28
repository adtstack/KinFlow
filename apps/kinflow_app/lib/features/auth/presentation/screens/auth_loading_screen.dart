import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class AuthLoadingScreen extends ConsumerWidget {
  const AuthLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AuthLifecycleState authState = ref.watch(authLifecycleProvider);
    final bool householdResolutionFailed =
        authState is AuthHouseholdResolutionFailed;

    return Scaffold(
      key: const Key('auth.loading'),
      body: SafeArea(
        child: ScrollableStatusLayout(
          maxWidth: AppLayoutTokens.dialogContentMaxWidth,
          child: householdResolutionFailed
              ? Semantics(
                  container: true,
                  explicitChildNodes: true,
                  liveRegion: true,
                  child: Column(
                    key: const Key('household.resolutionFailure'),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ExcludeSemantics(
                        child: Icon(
                          Icons.cloud_off_outlined,
                          color: Theme.of(context).colorScheme.error,
                          size: AppIconSize.status,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        header: true,
                        child: Text(
                          localizations.householdLookupErrorTitle,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        localizations.householdLookupErrorBody,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Semantics(
                        key: const Key('household.resolutionRetry'),
                        button: true,
                        enabled: true,
                        hint: localizations.retryActionHint,
                        label: localizations.retryAction,
                        onTap: () => unawaited(
                          ref
                              .read(authLifecycleProvider.notifier)
                              .retryHouseholdResolution(),
                        ),
                        child: ExcludeSemantics(
                          child: FilledButton(
                            onPressed: () => unawaited(
                              ref
                                  .read(authLifecycleProvider.notifier)
                                  .retryHouseholdResolution(),
                            ),
                            child: Text(localizations.retryAction),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        key: const Key('household.resolutionLogout'),
                        onPressed: () => unawaited(
                          ref.read(authLifecycleProvider.notifier).logout(),
                        ),
                        child: Text(localizations.authLogoutAction),
                      ),
                    ],
                  ),
                )
              : Semantics(
                  container: true,
                  label: localizations.authLoadingLabel,
                  liveRegion: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const ExcludeSemantics(
                        child: CircularProgressIndicator(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ExcludeSemantics(
                        child: Text(
                          localizations.authLoadingLabel,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
