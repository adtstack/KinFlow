import 'package:flutter/material.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class StartupLoadingScreen extends StatelessWidget {
  const StartupLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Scaffold(
      key: const Key('startup.loading'),
      body: SafeArea(
        child: Center(
          child: Semantics(
            label: localizations.startupLoadingLabel,
            liveRegion: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(localizations.startupLoadingLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
