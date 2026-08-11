import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/application/household_selection_controller.dart';
import 'package:kinflow_app/features/household/application/household_selection_state.dart';
import 'package:kinflow_app/features/household/application/unavailable_household_selection_repository.dart';
import 'package:kinflow_app/features/household/domain/failures/household_selection_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_selection_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

final householdSelectionRepositoryProvider =
    Provider<HouseholdSelectionRepository>((ref) {
      return const UnavailableHouseholdSelectionRepository();
    });

final householdSelectionControllerProvider =
    Provider.autoDispose<HouseholdSelectionController>((ref) {
      final HouseholdSelectionController controller =
          HouseholdSelectionController(
            repository: ref.watch(householdSelectionRepositoryProvider),
            committer: ref.watch(authLifecycleControllerProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final householdSelectionProvider =
    NotifierProvider.autoDispose<
      HouseholdSelectionNotifier,
      HouseholdSelectionState
    >(HouseholdSelectionNotifier.new);

final class HouseholdSelectionNotifier
    extends Notifier<HouseholdSelectionState> {
  @override
  HouseholdSelectionState build() {
    final HouseholdSelectionController controller = ref.watch(
      householdSelectionControllerProvider,
    );
    final StreamSubscription<HouseholdSelectionState> subscription = controller
        .states
        .listen((HouseholdSelectionState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load() {
    return ref.read(householdSelectionControllerProvider).load();
  }

  Future<bool> switchActiveHousehold(HouseholdId householdId) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return ref
          .read(householdSelectionControllerProvider)
          .rejectSwitch(HouseholdSelectionFailureKind.featureDisabled);
    }
    return ref
        .read(householdSelectionControllerProvider)
        .switchActiveHousehold(householdId);
  }
}
