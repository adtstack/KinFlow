import 'package:kinflow_app/features/runtime_policy/domain/failures/app_runtime_policy_failure.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';

final class UnavailableAppRuntimePolicyRepository
    implements AppRuntimePolicyRepository {
  const UnavailableAppRuntimePolicyRepository();

  @override
  Future<AppRuntimePolicyResult> load() async {
    return const AppRuntimePolicyFailed(
      AppRuntimePolicyFailure(AppRuntimePolicyFailureKind.unavailable),
    );
  }
}
