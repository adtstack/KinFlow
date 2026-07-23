import 'package:flutter/material.dart';
import 'package:kinflow_app/app/app_environment.dart';

void bootstrap(AppEnvironment environment) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KinFlowFoundationApp(environment: environment));
}

class KinFlowFoundationApp extends StatelessWidget {
  const KinFlowFoundationApp({required this.environment, super.key});

  final AppEnvironment environment;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: !environment.isProduction,
      home: const Scaffold(body: SizedBox.expand()),
    );
  }
}
