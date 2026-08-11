import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_registry.dart';
import 'package:kinflow_app/features/platform_capabilities/presentation/providers/platform_capability_providers.dart';

void main() {
  test('registry emits the exact five capabilities in contract order', () {
    const PlatformCapabilityRegistry registry =
        PlatformCapabilityRegistry.android(
          notificationAdapterComposed: true,
          billingPortAvailable: true,
          secureLocalStorageComposed: true,
          externalUriLauncherComposed: true,
        );

    final PlatformCapabilitySnapshot snapshot = registry.resolve(
      notificationSignal: PlatformNotificationCapabilitySignal.authorized,
    );

    expect(
      snapshot.entries.map((PlatformCapabilityStatus value) => value.id),
      PlatformCapabilityId.values,
    );
    expect(snapshot.entries, hasLength(5));
    expect(
      snapshot.find(PlatformCapabilityId.notificationDelivery)?.provider,
      PlatformCapabilityProvider.firebaseMessagingAndroid,
    );
    expect(
      snapshot.find(PlatformCapabilityId.storeBilling)?.provider,
      PlatformCapabilityProvider.revenueCatGooglePlay,
    );
    expect(
      snapshot.find(PlatformCapabilityId.secureLocalStorage)?.provider,
      PlatformCapabilityProvider.androidKeystore,
    );
    expect(
      snapshot.find(PlatformCapabilityId.externalLinks)?.provider,
      PlatformCapabilityProvider.androidSystemUriLauncher,
    );
    expect(
      snapshot.find(PlatformCapabilityId.backgroundDelivery)?.state,
      PlatformCapabilitySupportState.limited,
    );
    expect(
      () => snapshot.entries.add(snapshot.entries.first),
      throwsUnsupportedError,
    );
  });

  test('notification signals resolve to stable reason state and action', () {
    const PlatformCapabilityRegistry registry =
        PlatformCapabilityRegistry.android(
          notificationAdapterComposed: true,
          billingPortAvailable: true,
          secureLocalStorageComposed: true,
          externalUriLauncherComposed: true,
        );
    const Map<
      PlatformNotificationCapabilitySignal,
      ({
        PlatformCapabilityAction action,
        PlatformCapabilityReason reason,
        PlatformCapabilitySupportState state,
      })
    >
    expectations =
        <
          PlatformNotificationCapabilitySignal,
          ({
            PlatformCapabilityAction action,
            PlatformCapabilityReason reason,
            PlatformCapabilitySupportState state,
          })
        >{
          PlatformNotificationCapabilitySignal.unavailable: (
            action: PlatformCapabilityAction.openNotificationCenter,
            reason: PlatformCapabilityReason.runtimeUnavailable,
            state: PlatformCapabilitySupportState.fallbackOnly,
          ),
          PlatformNotificationCapabilitySignal.notDetermined: (
            action: PlatformCapabilityAction.openNotificationCenter,
            reason: PlatformCapabilityReason.permissionNotDetermined,
            state: PlatformCapabilitySupportState.actionRequired,
          ),
          PlatformNotificationCapabilitySignal.denied: (
            action: PlatformCapabilityAction.openNotificationCenter,
            reason: PlatformCapabilityReason.permissionDenied,
            state: PlatformCapabilitySupportState.actionRequired,
          ),
          PlatformNotificationCapabilitySignal.authorized: (
            action: PlatformCapabilityAction.none,
            reason: PlatformCapabilityReason.providerReady,
            state: PlatformCapabilitySupportState.available,
          ),
          PlatformNotificationCapabilitySignal.temporaryFailure: (
            action: PlatformCapabilityAction.openNotificationCenter,
            reason: PlatformCapabilityReason.providerTemporarilyUnavailable,
            state: PlatformCapabilitySupportState.temporaryIssue,
          ),
        };

    for (final MapEntry<
          PlatformNotificationCapabilitySignal,
          ({
            PlatformCapabilityAction action,
            PlatformCapabilityReason reason,
            PlatformCapabilitySupportState state,
          })
        >
        expectation
        in expectations.entries) {
      final PlatformCapabilityStatus notification = registry
          .resolve(notificationSignal: expectation.key)
          .find(PlatformCapabilityId.notificationDelivery)!;
      expect(notification.state, expectation.value.state);
      expect(notification.reason, expectation.value.reason);
      expect(notification.action, expectation.value.action);
    }
  });

  test('unavailable composition fails closed with named fallbacks', () {
    const PlatformCapabilityRegistry registry =
        PlatformCapabilityRegistry.unavailable();

    final PlatformCapabilitySnapshot snapshot = registry.resolve(
      notificationSignal: PlatformNotificationCapabilitySignal.authorized,
    );

    for (final PlatformCapabilityStatus entry in snapshot.entries) {
      expect(entry.provider, PlatformCapabilityProvider.unavailable);
      expect(entry.state, PlatformCapabilitySupportState.fallbackOnly);
      expect(entry.reason, PlatformCapabilityReason.providerNotConfigured);
      expect(entry.action, isNot(PlatformCapabilityAction.none));
    }
    expect(
      snapshot.find(PlatformCapabilityId.notificationDelivery)?.fallback,
      PlatformCapabilityFallback.inAppInbox,
    );
    expect(
      snapshot.find(PlatformCapabilityId.storeBilling)?.fallback,
      PlatformCapabilityFallback.serverEntitlementReadOnly,
    );
  });

  test('web composition exposes browser-only links and named fallbacks', () {
    const PlatformCapabilityRegistry registry = PlatformCapabilityRegistry.web(
      externalUriLauncherComposed: true,
    );

    final PlatformCapabilitySnapshot snapshot = registry.resolve(
      notificationSignal: PlatformNotificationCapabilitySignal.authorized,
    );

    expect(snapshot.entries, hasLength(5));
    expect(
      snapshot.find(PlatformCapabilityId.notificationDelivery),
      isA<PlatformCapabilityStatus>()
          .having(
            (PlatformCapabilityStatus value) => value.provider,
            'provider',
            PlatformCapabilityProvider.unavailable,
          )
          .having(
            (PlatformCapabilityStatus value) => value.fallback,
            'fallback',
            PlatformCapabilityFallback.inAppInboxAndConfiguredEmail,
          )
          .having(
            (PlatformCapabilityStatus value) => value.state,
            'state',
            PlatformCapabilitySupportState.fallbackOnly,
          ),
    );
    expect(
      snapshot.find(PlatformCapabilityId.storeBilling)?.fallback,
      PlatformCapabilityFallback.serverEntitlementReadOnly,
    );
    expect(
      snapshot.find(PlatformCapabilityId.secureLocalStorage)?.fallback,
      PlatformCapabilityFallback.reauthenticateWithoutPersistentCache,
    );
    expect(
      snapshot.find(PlatformCapabilityId.externalLinks),
      isA<PlatformCapabilityStatus>()
          .having(
            (PlatformCapabilityStatus value) => value.provider,
            'provider',
            PlatformCapabilityProvider.browserExternalUriLauncher,
          )
          .having(
            (PlatformCapabilityStatus value) => value.state,
            'state',
            PlatformCapabilitySupportState.available,
          )
          .having(
            (PlatformCapabilityStatus value) => value.action,
            'action',
            PlatformCapabilityAction.none,
          ),
    );
    expect(
      snapshot.find(PlatformCapabilityId.backgroundDelivery)?.fallback,
      PlatformCapabilityFallback.serverNotificationPipelineAndInAppInbox,
    );
  });

  test('snapshot rejects missing duplicate and out-of-order entries', () {
    final List<PlatformCapabilityStatus> valid =
        const PlatformCapabilityRegistry.unavailable()
            .resolve(
              notificationSignal:
                  PlatformNotificationCapabilitySignal.unavailable,
            )
            .entries;

    expect(PlatformCapabilitySnapshot.tryCreate(valid.take(4)), isNull);
    expect(
      PlatformCapabilitySnapshot.tryCreate(<PlatformCapabilityStatus>[
        valid[0],
        valid[0],
        ...valid.skip(2),
      ]),
      isNull,
    );
    expect(
      PlatformCapabilitySnapshot.tryCreate(<PlatformCapabilityStatus>[
        valid[1],
        valid[0],
        ...valid.skip(2),
      ]),
      isNull,
    );
  });

  test('notification presentation signal hides provider failure details', () {
    const NotificationPushState authorized = NotificationPushState(
      permission: NotificationPushPermission.authorized,
      busy: false,
      permissionRequestAttempted: true,
      endpointRegistered: true,
      failure: null,
    );
    const NotificationPushState temporary = NotificationPushState(
      permission: NotificationPushPermission.authorized,
      busy: false,
      permissionRequestAttempted: true,
      endpointRegistered: false,
      failure: NotificationPushFailureKind.registrationUnavailable,
    );
    const NotificationPushState denied = NotificationPushState(
      permission: NotificationPushPermission.denied,
      busy: false,
      permissionRequestAttempted: true,
      endpointRegistered: false,
      failure: NotificationPushFailureKind.tokenUnavailable,
    );

    expect(
      platformNotificationSignalFor(authorized),
      PlatformNotificationCapabilitySignal.authorized,
    );
    expect(
      platformNotificationSignalFor(temporary),
      PlatformNotificationCapabilitySignal.temporaryFailure,
    );
    expect(
      platformNotificationSignalFor(denied),
      PlatformNotificationCapabilitySignal.denied,
    );
    expect(
      platformNotificationSignalFor(const NotificationPushState.unavailable()),
      PlatformNotificationCapabilitySignal.unavailable,
    );
  });
}
