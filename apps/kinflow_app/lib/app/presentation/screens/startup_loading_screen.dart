import 'package:flutter/material.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Scaffold(
      key: const Key('startup.loading'),
      body: SafeArea(
        child: ScrollableStatusLayout(
          child: Semantics(
            container: true,
            label: localizations.startupLoadingLabel,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const ExcludeSemantics(child: CircularProgressIndicator()),
                const SizedBox(height: AppSpacing.lg),
                ExcludeSemantics(
                  child: Text(
                    localizations.startupLoadingLabel,
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
