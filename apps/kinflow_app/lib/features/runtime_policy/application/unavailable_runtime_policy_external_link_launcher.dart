import 'package:kinflow_app/features/runtime_policy/application/ports/runtime_policy_external_link_launcher.dart';

final class UnavailableRuntimePolicyExternalLinkLauncher
    implements RuntimePolicyExternalLinkLauncher {
  const UnavailableRuntimePolicyExternalLinkLauncher();

  @override
  Future<bool> launchUpdate() async => false;
}
