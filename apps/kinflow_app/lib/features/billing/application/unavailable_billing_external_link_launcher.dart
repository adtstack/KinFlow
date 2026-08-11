import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';

final class UnavailableBillingExternalLinkLauncher
    implements BillingExternalLinkLauncher {
  const UnavailableBillingExternalLinkLauncher();

  @override
  Future<BillingExternalLinkLaunchResult> launch(
    BillingExternalLink link,
  ) async => BillingExternalLinkLaunchResult.unavailable;
}
