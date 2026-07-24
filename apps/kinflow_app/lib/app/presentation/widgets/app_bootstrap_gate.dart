import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/presentation/screens/startup_failure_screen.dart';
import 'package:kinflow_app/app/presentation/screens/startup_loading_screen.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';

class AppBootstrapGate extends ConsumerStatefulWidget {
  const AppBootstrapGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends ConsumerState<AppBootstrapGate> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() {
    return Future<void>.sync(ref.read(appInitializerProvider));
  }

  void _retry() {
    setState(() {
      _initialization = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const StartupLoadingScreen();
        }

        if (snapshot.hasError) {
          return StartupFailureScreen(onRetry: _retry);
        }

        return widget.child;
      },
    );
  }
}
