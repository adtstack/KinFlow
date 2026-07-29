import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_controller.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_state.dart';
import 'package:kinflow_app/features/household/application/invite_creation_controller.dart';
import 'package:kinflow_app/features/household/application/invite_creation_state.dart';
import 'package:kinflow_app/features/household/application/invite_flow_controller.dart';
import 'package:kinflow_app/features/household/application/invite_flow_state.dart';
import 'package:kinflow_app/features/household/application/household_members_controller.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/application/ports/pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/services/household_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/services/household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/domain/services/invite_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  throw StateError('HouseholdRepository override is required.');
});

final householdMemberRepositoryProvider = Provider<HouseholdMemberRepository>((
  ref,
) {
  throw StateError('HouseholdMemberRepository override is required.');
});

final householdCommandIdGeneratorProvider =
    Provider<HouseholdCommandIdGenerator>((ref) {
      throw StateError('HouseholdCommandIdGenerator override is required.');
    });

final householdCreationIdGeneratorProvider =
    Provider<HouseholdCreationIdGenerator>((ref) {
      throw StateError('HouseholdCreationIdGenerator override is required.');
    });

final inviteRepositoryProvider = Provider<InviteRepository>((ref) {
  throw StateError('InviteRepository override is required.');
});

final inviteCommandIdGeneratorProvider = Provider<InviteCommandIdGenerator>((
  ref,
) {
  throw StateError('InviteCommandIdGenerator override is required.');
});

final pendingInviteStoreProvider = Provider<PendingInviteStore>((ref) {
  throw StateError('PendingInviteStore override is required.');
});

final householdMembersControllerProvider =
    Provider.autoDispose<HouseholdMembersController>((ref) {
      final HouseholdMembersController controller = HouseholdMembersController(
        repository: ref.watch(householdMemberRepositoryProvider),
        idGenerator: ref.watch(householdCommandIdGeneratorProvider),
        recentAuthenticationService: ref.watch(
          recentAuthenticationServiceProvider,
        ),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final householdMembersProvider =
    NotifierProvider.autoDispose<
      HouseholdMembersNotifier,
      HouseholdMembersState
    >(HouseholdMembersNotifier.new);

final class HouseholdMembersNotifier extends Notifier<HouseholdMembersState> {
  @override
  HouseholdMembersState build() {
    final HouseholdMembersController controller = ref.watch(
      householdMembersControllerProvider,
    );
    final StreamSubscription<HouseholdMembersState> subscription = controller
        .states
        .listen((HouseholdMembersState nextState) => state = nextState);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load(HouseholdId householdId) {
    return ref.read(householdMembersControllerProvider).load(householdId);
  }

  Future<void> changeRole(HouseholdMember member, HouseholdMemberRole role) {
    return ref
        .read(householdMembersControllerProvider)
        .changeRole(member, role);
  }

  Future<void> removeMember(HouseholdMember member) {
    return ref.read(householdMembersControllerProvider).removeMember(member);
  }

  Future<void> leaveHousehold() {
    return ref.read(householdMembersControllerProvider).leaveHousehold();
  }

  Future<void> transferOwner(HouseholdMember member) {
    return ref.read(householdMembersControllerProvider).transferOwner(member);
  }
}

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

final inviteCreationControllerProvider =
    Provider.autoDispose<InviteCreationController>((ref) {
      final InviteCreationController controller = InviteCreationController(
        repository: ref.watch(inviteRepositoryProvider),
        idGenerator: ref.watch(inviteCommandIdGeneratorProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final inviteCreationProvider =
    NotifierProvider.autoDispose<InviteCreationNotifier, InviteCreationState>(
      InviteCreationNotifier.new,
    );

final class InviteCreationNotifier extends Notifier<InviteCreationState> {
  @override
  InviteCreationState build() {
    final InviteCreationController controller = ref.watch(
      inviteCreationControllerProvider,
    );
    final StreamSubscription<InviteCreationState> subscription = controller
        .states
        .listen((InviteCreationState nextState) => state = nextState);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> create({
    required HouseholdId householdId,
    required String targetEmail,
  }) {
    return ref
        .read(inviteCreationControllerProvider)
        .create(householdId: householdId, targetEmail: targetEmail);
  }

  Future<void> revoke() {
    return ref.read(inviteCreationControllerProvider).revoke();
  }

  void startNewInvite() {
    ref.read(inviteCreationControllerProvider).startNewInvite();
  }
}

final inviteFlowControllerProvider = Provider.autoDispose<InviteFlowController>(
  (ref) {
    final InviteFlowController controller = InviteFlowController(
      repository: ref.watch(inviteRepositoryProvider),
      idGenerator: ref.watch(inviteCommandIdGeneratorProvider),
      pendingInviteStore: ref.watch(pendingInviteStoreProvider),
    );
    ref.onDispose(() => unawaited(controller.dispose()));
    return controller;
  },
);

final inviteFlowProvider =
    NotifierProvider.autoDispose<InviteFlowNotifier, InviteFlowState>(
      InviteFlowNotifier.new,
    );

final class InviteFlowNotifier extends Notifier<InviteFlowState> {
  @override
  InviteFlowState build() {
    final InviteFlowController controller = ref.watch(
      inviteFlowControllerProvider,
    );
    final StreamSubscription<InviteFlowState> subscription = controller.states
        .listen((InviteFlowState nextState) => state = nextState);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  bool capture(String rawToken) {
    return ref.read(inviteFlowControllerProvider).capture(rawToken);
  }

  Future<void> loadPreview() {
    return ref.read(inviteFlowControllerProvider).loadPreview();
  }

  Future<void> accept({required bool setActiveHousehold}) {
    return ref
        .read(inviteFlowControllerProvider)
        .accept(setActiveHousehold: setActiveHousehold);
  }

  void clear() {
    ref.read(inviteFlowControllerProvider).clear();
  }
}
