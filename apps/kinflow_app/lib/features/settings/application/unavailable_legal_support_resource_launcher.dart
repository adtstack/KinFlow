import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';

final class UnavailableLegalSupportResourceLauncher
    implements LegalSupportResourceLauncher {
  const UnavailableLegalSupportResourceLauncher();

  @override
  Future<LegalSupportResourceLaunchResult> launch(
    LegalSupportResource resource,
  ) async => LegalSupportResourceLaunchResult.unavailable;
}
