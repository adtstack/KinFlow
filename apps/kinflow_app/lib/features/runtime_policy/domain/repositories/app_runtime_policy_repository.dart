import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/failures/app_runtime_policy_failure.dart';

abstract interface class AppRuntimePolicyRepository {
  Future<AppRuntimePolicyResult> load();
}

sealed class AppRuntimePolicyResult {
  const AppRuntimePolicyResult();
}

final class AppRuntimePolicySucceeded extends AppRuntimePolicyResult {
  const AppRuntimePolicySucceeded(this.snapshot);

  final AppRuntimePolicySnapshot snapshot;
}

final class AppRuntimePolicyFailed extends AppRuntimePolicyResult {
  const AppRuntimePolicyFailed(this.failure);

  final AppRuntimePolicyFailure failure;
}
