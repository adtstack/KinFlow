import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

    return Scaffold(
      key: const Key('foundation.home'),
      appBar: AppBar(title: Text(localizations.appTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
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
          ),
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
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Column(
      key: const Key('foundation.ready'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.home_outlined,
          color: Theme.of(context).colorScheme.primary,
          size: 56,
        ),
        const SizedBox(height: 16),
        Text(
          localizations.foundationReadyTitle,
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(localizations.foundationReadyBody, textAlign: TextAlign.center),
      ],
    );
  }
}

class _FoundationLoadingContent extends StatelessWidget {
  const _FoundationLoadingContent();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Column(
      key: const Key('foundation.loading'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(localizations.foundationLoadingLabel, textAlign: TextAlign.center),
      ],
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

    return Column(
      key: const Key('foundation.failure'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(
          Icons.error_outline,
          color: Theme.of(context).colorScheme.error,
          size: 56,
        ),
        const SizedBox(height: 16),
        Text(
          localizations.foundationErrorTitle,
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(localizations.foundationErrorBody, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('foundation.retry'),
          onPressed: onRetry,
          child: Text(localizations.retryAction),
        ),
      ],
    );
  }
}
