import 'package:flutter/material.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
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
        child: ScrollableStatusLayout(
          maxWidth: AppLayoutTokens.dialogContentMaxWidth,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const ExcludeSemantics(
                  child: Icon(
                    Icons.error_outline,
                    size: AppTouchTarget.minimum,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  header: true,
                  child: Text(
                    localizations.startupErrorTitle,
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.startupErrorBody,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  key: const Key('startup.retry'),
                  button: true,
                  enabled: true,
                  hint: localizations.retryActionHint,
                  label: localizations.retryAction,
                  onTap: onRetry,
                  child: ExcludeSemantics(
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(localizations.retryAction),
                    ),
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
