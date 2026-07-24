import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Scaffold(
      key: const Key('route.notFound'),
      body: SafeArea(
        child: ScrollableStatusLayout(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  localizations.pageNotFoundTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(localizations.pageNotFoundBody, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                key: const Key('route.goHome'),
                onPressed: () => context.go(AppRoutes.home),
                child: Text(localizations.goHomeAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
