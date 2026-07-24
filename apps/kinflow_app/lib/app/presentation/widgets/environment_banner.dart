import 'package:flutter/material.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({
    required this.child,
    required this.environment,
    super.key,
  });

  final Widget child;
  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    if (environment.isProduction) {
      return child;
    }

    return Banner(
      key: const Key('environment.banner'),
      color: Theme.of(context).colorScheme.error,
      location: BannerLocation.topEnd,
      message: AppLocalizations.of(context).developmentBanner,
      textStyle: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
          .copyWith(
            color: Theme.of(context).colorScheme.onError,
            fontWeight: FontWeight.w700,
          ),
      child: child,
    );
  }
}
