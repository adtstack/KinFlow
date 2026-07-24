import 'package:flutter/material.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class StartupFailureScreen extends StatelessWidget {
  const StartupFailureScreen({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: const Key('startup.failure'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    localizations.startupErrorTitle,
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.startupErrorBody,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('startup.retry'),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: Text(localizations.retryAction),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
