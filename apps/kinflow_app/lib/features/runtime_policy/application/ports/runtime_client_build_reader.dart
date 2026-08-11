import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';

abstract interface class RuntimeClientBuildReader {
  Future<RuntimeClientBuild?> read();
}
