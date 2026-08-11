enum BillingExternalLink {
  googlePlaySubscriptions,
  appleAppStoreSubscriptions,
  terms,
  privacy,
  support,
}

enum BillingExternalLinkLaunchResult { opened, unavailable, failed }

abstract interface class BillingExternalLinkLauncher {
  Future<BillingExternalLinkLaunchResult> launch(BillingExternalLink link);
}
