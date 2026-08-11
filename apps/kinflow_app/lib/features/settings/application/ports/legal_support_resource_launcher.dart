enum LegalSupportResource { terms, privacy, support }

enum LegalSupportResourceLaunchResult { opened, unavailable, failed }

abstract interface class LegalSupportResourceLauncher {
  Future<LegalSupportResourceLaunchResult> launch(
    LegalSupportResource resource,
  );
}
