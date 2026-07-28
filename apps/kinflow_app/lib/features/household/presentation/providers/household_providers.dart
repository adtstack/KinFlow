import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_controller.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_state.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/services/household_creation_id_generator.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  throw StateError('HouseholdRepository override is required.');
});

final householdCreationIdGeneratorProvider =
    Provider<HouseholdCreationIdGenerator>((ref) {
      throw StateError('HouseholdCreationIdGenerator override is required.');
    });

final firstHouseholdOnboardingControllerProvider =
    Provider.autoDispose<FirstHouseholdOnboardingController>((ref) {
      final FirstHouseholdOnboardingController controller =
          FirstHouseholdOnboardingController(
            repository: ref.watch(householdRepositoryProvider),
            idGenerator: ref.watch(householdCreationIdGeneratorProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final firstHouseholdOnboardingProvider =
    NotifierProvider.autoDispose<
      FirstHouseholdOnboardingNotifier,
      FirstHouseholdOnboardingState
    >(FirstHouseholdOnboardingNotifier.new);

final class FirstHouseholdOnboardingNotifier
    extends Notifier<FirstHouseholdOnboardingState> {
  @override
  FirstHouseholdOnboardingState build() {
    final FirstHouseholdOnboardingController controller = ref.watch(
      firstHouseholdOnboardingControllerProvider,
    );
    final StreamSubscription<FirstHouseholdOnboardingState> subscription =
        controller.states.listen((FirstHouseholdOnboardingState nextState) {
          state = nextState;
        });
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> submit({
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  }) {
    return ref
        .read(firstHouseholdOnboardingControllerProvider)
        .submit(
          householdName: householdName,
          ownerDisplayName: ownerDisplayName,
          locale: locale,
          timezone: timezone,
        );
  }
}
