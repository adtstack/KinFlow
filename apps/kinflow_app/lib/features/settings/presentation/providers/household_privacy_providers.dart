import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/settings/application/household_privacy_controller.dart';
import 'package:kinflow_app/features/settings/application/household_privacy_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/repositories/household_privacy_repository.dart';
import 'package:kinflow_app/features/settings/presentation/providers/data_export_providers.dart';

final householdPrivacyRepositoryProvider = Provider<HouseholdPrivacyRepository>(
  (ref) {
    throw StateError('HouseholdPrivacyRepository override is required.');
  },
);

final householdPrivacyOwnerVisibilityProvider =
    FutureProvider.autoDispose<bool>((ref) async {
      final householdId = ref
          .watch(authLifecycleProvider)
          .activeHousehold
          ?.householdId;
      if (householdId == null) {
        return false;
      }
      try {
        final result = await ref
            .watch(householdPrivacyRepositoryProvider)
            .loadPreflight(householdId);
        return result is HouseholdPrivacySucceeded<HouseholdPrivacyPreflight>;
      } on Object {
        return false;
      }
    });

final householdPrivacyControllerProvider =
    Provider.autoDispose<HouseholdPrivacyController>((ref) {
      final HouseholdPrivacyController controller = HouseholdPrivacyController(
        ref.watch(householdPrivacyRepositoryProvider),
        ref.watch(householdCommandIdGeneratorProvider),
        ref.watch(recentAuthenticationServiceProvider),
        ref.watch(dataExportDownloadLauncherProvider),
        ref.watch(authLifecycleProvider).activeHousehold?.householdId,
        () => ref.read(authLifecycleProvider.notifier).refresh(),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final householdPrivacyProvider =
    NotifierProvider.autoDispose<
      HouseholdPrivacyNotifier,
      HouseholdPrivacyState
    >(HouseholdPrivacyNotifier.new);

final class HouseholdPrivacyNotifier extends Notifier<HouseholdPrivacyState> {
  @override
  HouseholdPrivacyState build() {
    final HouseholdPrivacyController controller = ref.watch(
      householdPrivacyControllerProvider,
    );
    final StreamSubscription<HouseholdPrivacyState> subscription = controller
        .states
        .listen((HouseholdPrivacyState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load({bool preserveContent = false}) => ref
      .read(householdPrivacyControllerProvider)
      .load(preserveContent: preserveContent);

  Future<void> requestExport() =>
      ref.read(householdPrivacyControllerProvider).requestExport();

  Future<void> requestDeletion({
    required String confirmationName,
    required bool acknowledgeMemberAccessLoss,
    required bool acknowledgeSharedDataRedaction,
    required bool acknowledgeSubscriptionNotCancelled,
  }) => ref
      .read(householdPrivacyControllerProvider)
      .requestDeletion(
        confirmationName: confirmationName,
        acknowledgeMemberAccessLoss: acknowledgeMemberAccessLoss,
        acknowledgeSharedDataRedaction: acknowledgeSharedDataRedaction,
        acknowledgeSubscriptionNotCancelled:
            acknowledgeSubscriptionNotCancelled,
      );

  Future<void> cancel() =>
      ref.read(householdPrivacyControllerProvider).cancel();

  Future<void> revokeExport() =>
      ref.read(householdPrivacyControllerProvider).revokeExport();

  Future<void> download(HouseholdExportFormat format) =>
      ref.read(householdPrivacyControllerProvider).download(format);
}
