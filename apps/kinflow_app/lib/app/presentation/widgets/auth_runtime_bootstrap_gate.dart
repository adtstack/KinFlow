import 'package:flutter/material.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';
import 'package:kinflow_app/app/presentation/screens/startup_failure_screen.dart';
import 'package:kinflow_app/app/presentation/screens/startup_loading_screen.dart';
import 'package:kinflow_app/app/presentation/widgets/environment_banner.dart';
import 'package:kinflow_app/app/providers/auth_dependencies.dart';
import 'package:kinflow_app/app/theme/app_theme.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

typedef AuthDependenciesLoader = Future<AuthDependencies> Function();
typedef AuthDependenciesBuilder =
    Widget Function(BuildContext context, AuthDependencies dependencies);

class AuthRuntimeBootstrapGate extends StatefulWidget {
  const AuthRuntimeBootstrapGate({
    required this.builder,
    required this.environment,
    required this.loader,
    required this.logger,
    super.key,
  });

  final AuthDependenciesBuilder builder;
  final AppEnvironment environment;
  final AuthDependenciesLoader loader;
  final AppLogger logger;

  @override
  State<AuthRuntimeBootstrapGate> createState() {
    return _AuthRuntimeBootstrapGateState();
  }
}

final class _AuthRuntimeBootstrapGateState
    extends State<AuthRuntimeBootstrapGate> {
  late Future<AuthDependencies> _initialization;
  var _attempt = 0;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<AuthDependencies> _initialize() async {
    _attempt += 1;
    widget.logger.info(
      'authentication.runtime.initialization.started',
      attributes: <String, Object?>{
        'capability': 'authentication',
        'operation': 'runtime_initialization',
        'result': 'started',
        'retry_count': _attempt - 1,
      },
    );
    try {
      final AuthDependencies dependencies = await widget.loader();
      widget.logger.info(
        'authentication.runtime.initialization.succeeded',
        attributes: <String, Object?>{
          'capability': 'authentication',
          'operation': 'runtime_initialization',
          'result': 'succeeded',
          'retry_count': _attempt - 1,
        },
      );
      return dependencies;
    } on Object {
      widget.logger.error(
        'authentication.runtime.initialization.failed',
        code: 'auth_runtime_initialization_failed',
        attributes: <String, Object?>{
          'capability': 'authentication',
          'operation': 'runtime_initialization',
          'result': 'failed',
          'retry_count': _attempt - 1,
        },
      );
      rethrow;
    }
  }

  void _retry() {
    setState(() {
      _initialization = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthDependencies>(
      future: _initialization,
      builder:
          (BuildContext context, AsyncSnapshot<AuthDependencies> snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _startupShell(
                const TickerMode(enabled: false, child: StartupLoadingScreen()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _startupShell(StartupFailureScreen(onRetry: _retry));
            }

            return widget.builder(context, snapshot.requireData);
          },
    );
  }

  Widget _startupShell(Widget home) {
    return MaterialApp(
      builder: (BuildContext context, Widget? child) {
        return EnvironmentBanner(
          environment: widget.environment,
          child: child ?? const SizedBox.shrink(),
        );
      },
      darkTheme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      home: home,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      onGenerateTitle: (BuildContext context) {
        return AppLocalizations.of(context).appTitle;
      },
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      themeMode: ThemeMode.system,
    );
  }
}
