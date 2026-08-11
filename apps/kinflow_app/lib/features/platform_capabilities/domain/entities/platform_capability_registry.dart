const String platformCapabilityRegistryContractVersion = '2026-08-09-wp01-08';

enum PlatformCapabilityId {
  notificationDelivery('notification_delivery'),
  storeBilling('store_billing'),
  secureLocalStorage('secure_local_storage'),
  externalLinks('external_links'),
  backgroundDelivery('background_delivery');

  const PlatformCapabilityId(this.wireValue);

  final String wireValue;
}

enum PlatformCapabilityProvider {
  firebaseMessagingAndroid,
  revenueCatGooglePlay,
  androidKeystore,
  androidSystemUriLauncher,
  browserExternalUriLauncher,
  firebaseBackgroundMessageHandler,
  unavailable,
}

enum PlatformCapabilityFallback {
  inAppInbox,
  inAppInboxAndConfiguredEmail,
  serverEntitlementReadOnly,
  reauthenticateWithoutPersistentCache,
  onScreenGuidanceAndDiagnostics,
  serverNotificationPipelineAndInAppInbox,
}

enum PlatformCapabilitySupportState {
  available,
  actionRequired,
  limited,
  fallbackOnly,
  temporaryIssue,
}

enum PlatformCapabilityReason {
  providerReady,
  permissionNotDetermined,
  permissionDenied,
  runtimeUnavailable,
  providerTemporarilyUnavailable,
  providerNotConfigured,
  serverAuthoritative,
}

enum PlatformCapabilityAction {
  none,
  openNotificationCenter,
  openSubscriptionSettings,
  openDiagnostics,
}

enum PlatformNotificationCapabilitySignal {
  unavailable,
  notDetermined,
  denied,
  authorized,
  temporaryFailure,
}

final class PlatformCapabilityStatus {
  const PlatformCapabilityStatus({
    required this.id,
    required this.provider,
    required this.fallback,
    required this.state,
    required this.reason,
    required this.action,
  });

  final PlatformCapabilityId id;
  final PlatformCapabilityProvider provider;
  final PlatformCapabilityFallback fallback;
  final PlatformCapabilitySupportState state;
  final PlatformCapabilityReason reason;
  final PlatformCapabilityAction action;
}

final class PlatformCapabilitySnapshot {
  PlatformCapabilitySnapshot._(List<PlatformCapabilityStatus> entries)
    : entries = List<PlatformCapabilityStatus>.unmodifiable(entries);

  final List<PlatformCapabilityStatus> entries;

  static PlatformCapabilitySnapshot? tryCreate(
    Iterable<PlatformCapabilityStatus> entries,
  ) {
    final List<PlatformCapabilityStatus> values = entries.toList(
      growable: false,
    );
    if (values.length != PlatformCapabilityId.values.length) return null;
    for (int index = 0; index < PlatformCapabilityId.values.length; index++) {
      if (values[index].id != PlatformCapabilityId.values[index]) return null;
    }
    return PlatformCapabilitySnapshot._(values);
  }

  PlatformCapabilityStatus? find(PlatformCapabilityId id) {
    for (final PlatformCapabilityStatus entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}

final class PlatformCapabilityRegistry {
  const PlatformCapabilityRegistry.android({
    required this.notificationAdapterComposed,
    required this.billingPortAvailable,
    required this.secureLocalStorageComposed,
    required this.externalUriLauncherComposed,
  }) : _runtime = _PlatformCapabilityRuntime.android;

  const PlatformCapabilityRegistry.web({
    required this.externalUriLauncherComposed,
  }) : _runtime = _PlatformCapabilityRuntime.web,
       notificationAdapterComposed = false,
       billingPortAvailable = false,
       secureLocalStorageComposed = false;

  const PlatformCapabilityRegistry.unavailable()
    : _runtime = _PlatformCapabilityRuntime.unavailable,
      notificationAdapterComposed = false,
      billingPortAvailable = false,
      secureLocalStorageComposed = false,
      externalUriLauncherComposed = false;

  final bool notificationAdapterComposed;
  final bool billingPortAvailable;
  final bool secureLocalStorageComposed;
  final bool externalUriLauncherComposed;
  final _PlatformCapabilityRuntime _runtime;

  PlatformCapabilitySnapshot resolve({
    required PlatformNotificationCapabilitySignal notificationSignal,
  }) {
    if (_runtime == _PlatformCapabilityRuntime.web) {
      return _resolveWeb();
    }
    return PlatformCapabilitySnapshot.tryCreate(<PlatformCapabilityStatus>[
      _notificationStatus(notificationSignal),
      _fixedStatus(
        id: PlatformCapabilityId.storeBilling,
        available: billingPortAvailable,
        availableProvider: PlatformCapabilityProvider.revenueCatGooglePlay,
        fallback: PlatformCapabilityFallback.serverEntitlementReadOnly,
        unavailableAction: PlatformCapabilityAction.openSubscriptionSettings,
      ),
      _fixedStatus(
        id: PlatformCapabilityId.secureLocalStorage,
        available: secureLocalStorageComposed,
        availableProvider: PlatformCapabilityProvider.androidKeystore,
        fallback:
            PlatformCapabilityFallback.reauthenticateWithoutPersistentCache,
        unavailableAction: PlatformCapabilityAction.openDiagnostics,
      ),
      _fixedStatus(
        id: PlatformCapabilityId.externalLinks,
        available: externalUriLauncherComposed,
        availableProvider: PlatformCapabilityProvider.androidSystemUriLauncher,
        fallback: PlatformCapabilityFallback.onScreenGuidanceAndDiagnostics,
        unavailableAction: PlatformCapabilityAction.openDiagnostics,
      ),
      PlatformCapabilityStatus(
        id: PlatformCapabilityId.backgroundDelivery,
        provider: notificationAdapterComposed
            ? PlatformCapabilityProvider.firebaseBackgroundMessageHandler
            : PlatformCapabilityProvider.unavailable,
        fallback:
            PlatformCapabilityFallback.serverNotificationPipelineAndInAppInbox,
        state: notificationAdapterComposed
            ? PlatformCapabilitySupportState.limited
            : PlatformCapabilitySupportState.fallbackOnly,
        reason: notificationAdapterComposed
            ? PlatformCapabilityReason.serverAuthoritative
            : PlatformCapabilityReason.providerNotConfigured,
        action: PlatformCapabilityAction.openNotificationCenter,
      ),
    ])!;
  }

  PlatformCapabilitySnapshot _resolveWeb() {
    return PlatformCapabilitySnapshot.tryCreate(<PlatformCapabilityStatus>[
      const PlatformCapabilityStatus(
        id: PlatformCapabilityId.notificationDelivery,
        provider: PlatformCapabilityProvider.unavailable,
        fallback: PlatformCapabilityFallback.inAppInboxAndConfiguredEmail,
        state: PlatformCapabilitySupportState.fallbackOnly,
        reason: PlatformCapabilityReason.providerNotConfigured,
        action: PlatformCapabilityAction.openNotificationCenter,
      ),
      const PlatformCapabilityStatus(
        id: PlatformCapabilityId.storeBilling,
        provider: PlatformCapabilityProvider.unavailable,
        fallback: PlatformCapabilityFallback.serverEntitlementReadOnly,
        state: PlatformCapabilitySupportState.fallbackOnly,
        reason: PlatformCapabilityReason.providerNotConfigured,
        action: PlatformCapabilityAction.openSubscriptionSettings,
      ),
      const PlatformCapabilityStatus(
        id: PlatformCapabilityId.secureLocalStorage,
        provider: PlatformCapabilityProvider.unavailable,
        fallback:
            PlatformCapabilityFallback.reauthenticateWithoutPersistentCache,
        state: PlatformCapabilitySupportState.fallbackOnly,
        reason: PlatformCapabilityReason.providerNotConfigured,
        action: PlatformCapabilityAction.openDiagnostics,
      ),
      PlatformCapabilityStatus(
        id: PlatformCapabilityId.externalLinks,
        provider: externalUriLauncherComposed
            ? PlatformCapabilityProvider.browserExternalUriLauncher
            : PlatformCapabilityProvider.unavailable,
        fallback: PlatformCapabilityFallback.onScreenGuidanceAndDiagnostics,
        state: externalUriLauncherComposed
            ? PlatformCapabilitySupportState.available
            : PlatformCapabilitySupportState.fallbackOnly,
        reason: externalUriLauncherComposed
            ? PlatformCapabilityReason.providerReady
            : PlatformCapabilityReason.providerNotConfigured,
        action: externalUriLauncherComposed
            ? PlatformCapabilityAction.none
            : PlatformCapabilityAction.openDiagnostics,
      ),
      const PlatformCapabilityStatus(
        id: PlatformCapabilityId.backgroundDelivery,
        provider: PlatformCapabilityProvider.unavailable,
        fallback:
            PlatformCapabilityFallback.serverNotificationPipelineAndInAppInbox,
        state: PlatformCapabilitySupportState.fallbackOnly,
        reason: PlatformCapabilityReason.providerNotConfigured,
        action: PlatformCapabilityAction.openNotificationCenter,
      ),
    ])!;
  }

  PlatformCapabilityStatus _notificationStatus(
    PlatformNotificationCapabilitySignal signal,
  ) {
    if (!notificationAdapterComposed) {
      return const PlatformCapabilityStatus(
        id: PlatformCapabilityId.notificationDelivery,
        provider: PlatformCapabilityProvider.unavailable,
        fallback: PlatformCapabilityFallback.inAppInbox,
        state: PlatformCapabilitySupportState.fallbackOnly,
        reason: PlatformCapabilityReason.providerNotConfigured,
        action: PlatformCapabilityAction.openNotificationCenter,
      );
    }

    final ({
      PlatformCapabilityAction action,
      PlatformCapabilityReason reason,
      PlatformCapabilitySupportState state,
    })
    resolution = switch (signal) {
      PlatformNotificationCapabilitySignal.unavailable => (
        action: PlatformCapabilityAction.openNotificationCenter,
        reason: PlatformCapabilityReason.runtimeUnavailable,
        state: PlatformCapabilitySupportState.fallbackOnly,
      ),
      PlatformNotificationCapabilitySignal.notDetermined => (
        action: PlatformCapabilityAction.openNotificationCenter,
        reason: PlatformCapabilityReason.permissionNotDetermined,
        state: PlatformCapabilitySupportState.actionRequired,
      ),
      PlatformNotificationCapabilitySignal.denied => (
        action: PlatformCapabilityAction.openNotificationCenter,
        reason: PlatformCapabilityReason.permissionDenied,
        state: PlatformCapabilitySupportState.actionRequired,
      ),
      PlatformNotificationCapabilitySignal.authorized => (
        action: PlatformCapabilityAction.none,
        reason: PlatformCapabilityReason.providerReady,
        state: PlatformCapabilitySupportState.available,
      ),
      PlatformNotificationCapabilitySignal.temporaryFailure => (
        action: PlatformCapabilityAction.openNotificationCenter,
        reason: PlatformCapabilityReason.providerTemporarilyUnavailable,
        state: PlatformCapabilitySupportState.temporaryIssue,
      ),
    };
    return PlatformCapabilityStatus(
      id: PlatformCapabilityId.notificationDelivery,
      provider: PlatformCapabilityProvider.firebaseMessagingAndroid,
      fallback: PlatformCapabilityFallback.inAppInbox,
      state: resolution.state,
      reason: resolution.reason,
      action: resolution.action,
    );
  }

  PlatformCapabilityStatus _fixedStatus({
    required PlatformCapabilityId id,
    required bool available,
    required PlatformCapabilityProvider availableProvider,
    required PlatformCapabilityFallback fallback,
    required PlatformCapabilityAction unavailableAction,
  }) {
    return PlatformCapabilityStatus(
      id: id,
      provider: available
          ? availableProvider
          : PlatformCapabilityProvider.unavailable,
      fallback: fallback,
      state: available
          ? PlatformCapabilitySupportState.available
          : PlatformCapabilitySupportState.fallbackOnly,
      reason: available
          ? PlatformCapabilityReason.providerReady
          : PlatformCapabilityReason.providerNotConfigured,
      action: available ? PlatformCapabilityAction.none : unavailableAction,
    );
  }
}

enum _PlatformCapabilityRuntime { android, web, unavailable }
