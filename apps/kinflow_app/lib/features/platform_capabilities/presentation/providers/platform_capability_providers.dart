import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_recovery_plan.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_registry.dart';

final platformCapabilityRegistryProvider = Provider<PlatformCapabilityRegistry>(
  (ref) => const PlatformCapabilityRegistry.unavailable(),
);

final platformCapabilitySnapshotProvider = Provider<PlatformCapabilitySnapshot>(
  (ref) {
    final PlatformCapabilityRegistry registry = ref.watch(
      platformCapabilityRegistryProvider,
    );
    final NotificationPushState notificationState = ref.watch(
      notificationPushStateProvider,
    );
    return registry.resolve(
      notificationSignal: platformNotificationSignalFor(notificationState),
    );
  },
);

final platformCapabilityRecoveryPlanProvider =
    Provider<PlatformCapabilityRecoveryPlan>((ref) {
      return PlatformCapabilityRecoveryPlan.fromSnapshot(
        ref.watch(platformCapabilitySnapshotProvider),
      );
    });

PlatformNotificationCapabilitySignal platformNotificationSignalFor(
  NotificationPushState state,
) {
  if (state.permission == NotificationPushPermission.unavailable) {
    return PlatformNotificationCapabilitySignal.unavailable;
  }
  if (state.permission == NotificationPushPermission.denied) {
    return PlatformNotificationCapabilitySignal.denied;
  }
  if (state.failure != null) {
    return PlatformNotificationCapabilitySignal.temporaryFailure;
  }
  return switch (state.permission) {
    NotificationPushPermission.unavailable =>
      PlatformNotificationCapabilitySignal.unavailable,
    NotificationPushPermission.notDetermined =>
      PlatformNotificationCapabilitySignal.notDetermined,
    NotificationPushPermission.denied =>
      PlatformNotificationCapabilitySignal.denied,
    NotificationPushPermission.authorized =>
      PlatformNotificationCapabilitySignal.authorized,
  };
}
