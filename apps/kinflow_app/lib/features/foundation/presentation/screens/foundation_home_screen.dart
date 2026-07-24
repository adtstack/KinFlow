import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/foundation/domain/repositories/foundation_repository.dart';
import 'package:kinflow_app/features/foundation/presentation/providers/foundation_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class FoundationHomeScreen extends ConsumerWidget {
  const FoundationHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<LoadFoundationResult> status = ref.watch(
      foundationStatusProvider,
    );

    return AppResponsiveScaffold(
      key: const Key('foundation.home'),
      title: localizations.appTitle,
      body: ScrollableStatusLayout(
        child: status.when(
          data: (LoadFoundationResult result) {
            return switch (result) {
              FoundationLoaded() => const _FoundationReadyContent(),
              FoundationLoadFailed() => _FoundationFailureContent(
                onRetry: () => ref.invalidate(foundationStatusProvider),
              ),
            };
          },
          error: (Object error, StackTrace stackTrace) {
            return _FoundationFailureContent(
              onRetry: () => ref.invalidate(foundationStatusProvider),
            );
          },
          loading: () => const _FoundationLoadingContent(),
        ),
      ),
    );
  }
}

class _FoundationReadyContent extends StatelessWidget {
  const _FoundationReadyContent();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppSemanticColors semanticColors = Theme.of(
      context,
    ).extension<AppSemanticColors>()!;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      key: const Key('foundation.ready'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            Icons.check_circle_outline,
            color: semanticColors.ready,
            size: AppIconSize.status,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(
            localizations.foundationReadyTitle,
            style: textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(localizations.foundationReadyBody, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          localizations.foundationLayoutCount(AppWindowSizeClass.values.length),
          style: textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _FoundationLoadingContent extends StatelessWidget {
  const _FoundationLoadingContent();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      child: Column(
        key: const Key('foundation.loading'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const ExcludeSemantics(child: CircularProgressIndicator()),
          const SizedBox(height: AppSpacing.md),
          Text(
            localizations.foundationLoadingLabel,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FoundationFailureContent extends StatelessWidget {
  const _FoundationFailureContent({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      child: Column(
        key: const Key('foundation.failure'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ExcludeSemantics(
            child: Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: AppIconSize.status,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              localizations.foundationErrorTitle,
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(localizations.foundationErrorBody, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            key: const Key('foundation.retry'),
            button: true,
            enabled: true,
            hint: localizations.retryActionHint,
            label: localizations.retryAction,
            onTap: onRetry,
            child: ExcludeSemantics(
              child: FilledButton(
                onPressed: onRetry,
                child: Text(localizations.retryAction),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
