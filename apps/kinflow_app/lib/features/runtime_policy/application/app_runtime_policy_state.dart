import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/failures/app_runtime_policy_failure.dart';

sealed class AppRuntimePolicyState {
  const AppRuntimePolicyState();
}

final class AppRuntimePolicyInitial extends AppRuntimePolicyState {
  const AppRuntimePolicyInitial();
}

final class AppRuntimePolicyLoading extends AppRuntimePolicyState {
  const AppRuntimePolicyLoading();
}

final class AppRuntimePolicyReady extends AppRuntimePolicyState {
  const AppRuntimePolicyReady({
    required this.snapshot,
    this.isRefreshing = false,
    this.refreshFailure,
  });

  final AppRuntimePolicySnapshot snapshot;
  final bool isRefreshing;
  final AppRuntimePolicyFailure? refreshFailure;
}

final class AppRuntimePolicyLoadFailed extends AppRuntimePolicyState {
  const AppRuntimePolicyLoadFailed(this.failure);

  final AppRuntimePolicyFailure failure;
}
