import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_controller.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_state.dart';
import 'package:kinflow_app/features/notifications/application/notification_endpoint_lifecycle.dart';
import 'package:kinflow_app/features/notifications/application/notification_push_coordinator.dart';
import 'package:kinflow_app/features/notifications/application/unavailable_notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/application/unavailable_notification_repository.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_sync_repository.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return const UnavailableNotificationRepository();
});

final notificationSyncRepositoryProvider =
    Provider<NotificationSyncRepository?>((ref) => null);

final notificationEndpointRepositoryProvider =
    Provider<NotificationEndpointRepository>((ref) {
      return const UnavailableNotificationEndpointRepository();
    });

final notificationEndpointLifecycleProvider =
    Provider<NotificationEndpointLifecycleService>((ref) {
      return const UnavailableNotificationEndpointLifecycle();
    });

final notificationPushCoordinatorProvider =
    Provider<NotificationPushCoordinatorService>((ref) {
      return const UnavailableNotificationPushCoordinator();
    });

final notificationPushStateProvider =
    NotifierProvider<NotificationPushNotifier, NotificationPushState>(
      NotificationPushNotifier.new,
    );

final class NotificationPushNotifier extends Notifier<NotificationPushState> {
  @override
  NotificationPushState build() {
    final NotificationPushCoordinatorService coordinator = ref.watch(
      notificationPushCoordinatorProvider,
    );
    final StreamSubscription<NotificationPushState> subscription = coordinator
        .states
        .listen((NotificationPushState next) => state = next);
    ref.onDispose(() {
      unawaited(subscription.cancel());
      unawaited(coordinator.dispose());
    });
    unawaited(coordinator.start());
    return coordinator.state;
  }

  Future<void> synchronize({
    required ActiveHousehold? activeHousehold,
    required String? locale,
  }) {
    if (activeHousehold != null &&
        ref.read(
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.notifications,
          ),
        )) {
      return Future<void>.value();
    }
    return ref
        .read(notificationPushCoordinatorProvider)
        .synchronize(activeHousehold: activeHousehold, locale: locale);
  }

  void updatePresentationContent(NotificationPushPresentationContent content) {
    ref
        .read(notificationPushCoordinatorProvider)
        .updatePresentationContent(content);
  }

  Future<void> requestPermission() {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.notifications,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(notificationPushCoordinatorProvider).requestPermission();
  }

  Future<void> refreshPermission() {
    return ref.read(notificationPushCoordinatorProvider).refreshPermission();
  }

  Future<bool> openSystemSettings() {
    return ref.read(notificationPushCoordinatorProvider).openSystemSettings();
  }
}

final notificationCenterControllerProvider =
    Provider<NotificationCenterController>((ref) {
      final NotificationCenterController controller =
          NotificationCenterController(
            ref.watch(notificationRepositoryProvider),
            authUserId: ref.watch(
              authLifecycleProvider.select((state) => state.session?.userId),
            ),
            syncRepository: ref.watch(notificationSyncRepositoryProvider),
            snoozeIdFactory: () => NotificationSnoozeCommandId.tryParse(
              ref.read(calendarCommandIdGeneratorProvider).generate().value,
            )!,
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final notificationCenterProvider =
    NotifierProvider<NotificationCenterNotifier, NotificationCenterState>(
      NotificationCenterNotifier.new,
    );

final class NotificationCenterNotifier
    extends Notifier<NotificationCenterState> {
  @override
  NotificationCenterState build() {
    final NotificationCenterController controller = ref.watch(
      notificationCenterControllerProvider,
    );
    final StreamSubscription<NotificationCenterState> subscription = controller
        .states
        .listen((NotificationCenterState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load(HouseholdId householdId, {bool preserveContent = false}) {
    return ref
        .read(notificationCenterControllerProvider)
        .load(householdId, preserveContent: preserveContent);
  }

  Future<void> ensureLoaded(HouseholdId householdId) {
    return ref
        .read(notificationCenterControllerProvider)
        .ensureLoaded(householdId);
  }

  Future<void> deactivate() {
    return ref.read(notificationCenterControllerProvider).deactivate();
  }

  Future<void> refresh() {
    return ref.read(notificationCenterControllerProvider).refresh();
  }

  Future<void> resume() {
    return ref.read(notificationCenterControllerProvider).resume();
  }

  Future<void> reconnect() {
    return ref.read(notificationCenterControllerProvider).reconnect();
  }

  Future<void> loadMore() {
    return ref.read(notificationCenterControllerProvider).loadMore();
  }

  Future<void> updatePreference(NotificationPreference preference) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.notifications,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(notificationCenterControllerProvider)
        .updatePreference(preference);
  }

  Future<void> markRead(NotificationInboxItemId itemId) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.notifications,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(notificationCenterControllerProvider).markRead(itemId);
  }

  Future<void> markAllRead() {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.notifications,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(notificationCenterControllerProvider).markAllRead();
  }

  Future<bool> snoozeCalendar(
    NotificationInboxItemId itemId,
    int snoozeMinutes,
  ) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.notifications,
      ),
    )) {
      return Future<bool>.value(false);
    }
    return ref
        .read(notificationCenterControllerProvider)
        .snoozeCalendar(itemId, snoozeMinutes);
  }
}
