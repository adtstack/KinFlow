import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_recovery_plan.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_registry.dart';

void main() {
  test('ready Android snapshot reports one intentional limitation', () {
    final PlatformCapabilityRecoveryPlan plan =
        PlatformCapabilityRecoveryPlan.fromSnapshot(
          const PlatformCapabilityRegistry.android(
            notificationAdapterComposed: true,
            billingPortAvailable: true,
            secureLocalStorageComposed: true,
            externalUriLauncherComposed: true,
          ).resolve(
            notificationSignal: PlatformNotificationCapabilitySignal.authorized,
          ),
        );

    expect(platformCapabilitySelfCheckContractVersion, '2026-08-09-wp01-09');
    expect(plan.readyCount, 4);
    expect(plan.attentionCount, 0);
    expect(plan.alternativeCount, 1);
    expect(plan.hasAttentionItems, isFalse);
    expect(plan.steps, hasLength(1));
    expect(
      plan.steps.single.status.id,
      PlatformCapabilityId.backgroundDelivery,
    );
    expect(
      plan.steps.single.status.state,
      PlatformCapabilitySupportState.limited,
    );
  });

  test('non-ready entries use severity then registry order', () {
    final PlatformCapabilitySnapshot snapshot =
        PlatformCapabilitySnapshot.tryCreate(const <PlatformCapabilityStatus>[
          PlatformCapabilityStatus(
            id: PlatformCapabilityId.notificationDelivery,
            provider: PlatformCapabilityProvider.firebaseMessagingAndroid,
            fallback: PlatformCapabilityFallback.inAppInbox,
            state: PlatformCapabilitySupportState.temporaryIssue,
            reason: PlatformCapabilityReason.providerTemporarilyUnavailable,
            action: PlatformCapabilityAction.openNotificationCenter,
          ),
          PlatformCapabilityStatus(
            id: PlatformCapabilityId.storeBilling,
            provider: PlatformCapabilityProvider.unavailable,
            fallback: PlatformCapabilityFallback.serverEntitlementReadOnly,
            state: PlatformCapabilitySupportState.fallbackOnly,
            reason: PlatformCapabilityReason.providerNotConfigured,
            action: PlatformCapabilityAction.openSubscriptionSettings,
          ),
          PlatformCapabilityStatus(
            id: PlatformCapabilityId.secureLocalStorage,
            provider: PlatformCapabilityProvider.androidKeystore,
            fallback:
                PlatformCapabilityFallback.reauthenticateWithoutPersistentCache,
            state: PlatformCapabilitySupportState.actionRequired,
            reason: PlatformCapabilityReason.permissionDenied,
            action: PlatformCapabilityAction.openDiagnostics,
          ),
          PlatformCapabilityStatus(
            id: PlatformCapabilityId.externalLinks,
            provider: PlatformCapabilityProvider.androidSystemUriLauncher,
            fallback: PlatformCapabilityFallback.onScreenGuidanceAndDiagnostics,
            state: PlatformCapabilitySupportState.available,
            reason: PlatformCapabilityReason.providerReady,
            action: PlatformCapabilityAction.none,
          ),
          PlatformCapabilityStatus(
            id: PlatformCapabilityId.backgroundDelivery,
            provider:
                PlatformCapabilityProvider.firebaseBackgroundMessageHandler,
            fallback: PlatformCapabilityFallback
                .serverNotificationPipelineAndInAppInbox,
            state: PlatformCapabilitySupportState.limited,
            reason: PlatformCapabilityReason.serverAuthoritative,
            action: PlatformCapabilityAction.openNotificationCenter,
          ),
        ])!;

    final PlatformCapabilityRecoveryPlan plan =
        PlatformCapabilityRecoveryPlan.fromSnapshot(snapshot);

    expect(
      plan.steps.map((PlatformCapabilityRecoveryStep step) => step.status.id),
      <PlatformCapabilityId>[
        PlatformCapabilityId.notificationDelivery,
        PlatformCapabilityId.secureLocalStorage,
        PlatformCapabilityId.storeBilling,
        PlatformCapabilityId.backgroundDelivery,
      ],
    );
    expect(
      plan.steps.map((PlatformCapabilityRecoveryStep step) => step.position),
      <int>[1, 2, 3, 4],
    );
    expect(plan.readyCount, 1);
    expect(plan.attentionCount, 2);
    expect(plan.alternativeCount, 2);
    expect(plan.hasAttentionItems, isTrue);
  });

  test('unavailable snapshot keeps every named fallback in exact order', () {
    final PlatformCapabilityRecoveryPlan plan =
        PlatformCapabilityRecoveryPlan.fromSnapshot(
          const PlatformCapabilityRegistry.unavailable().resolve(
            notificationSignal:
                PlatformNotificationCapabilitySignal.unavailable,
          ),
        );

    expect(plan.readyCount, 0);
    expect(plan.attentionCount, 0);
    expect(plan.alternativeCount, 5);
    expect(
      plan.steps.map((PlatformCapabilityRecoveryStep step) => step.status.id),
      PlatformCapabilityId.values,
    );
    expect(
      plan.steps.every(
        (PlatformCapabilityRecoveryStep step) =>
            step.status.provider == PlatformCapabilityProvider.unavailable &&
            step.status.action != PlatformCapabilityAction.none,
      ),
      isTrue,
    );
  });

  test('summary exactly partitions entries and steps are immutable', () {
    final PlatformCapabilityRecoveryPlan plan =
        PlatformCapabilityRecoveryPlan.fromSnapshot(
          const PlatformCapabilityRegistry.android(
            notificationAdapterComposed: true,
            billingPortAvailable: false,
            secureLocalStorageComposed: true,
            externalUriLauncherComposed: false,
          ).resolve(
            notificationSignal: PlatformNotificationCapabilitySignal.denied,
          ),
        );

    expect(plan.readyCount + plan.attentionCount + plan.alternativeCount, 5);
    expect(plan.steps, hasLength(plan.attentionCount + plan.alternativeCount));
    expect(() => plan.steps.add(plan.steps.first), throwsUnsupportedError);
  });
}
