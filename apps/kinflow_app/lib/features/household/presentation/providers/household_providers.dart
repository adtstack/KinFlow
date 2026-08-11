import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_controller.dart';
import 'package:kinflow_app/features/household/application/first_household_onboarding_state.dart';
import 'package:kinflow_app/features/household/application/invite_creation_controller.dart';
import 'package:kinflow_app/features/household/application/invite_creation_state.dart';
import 'package:kinflow_app/features/household/application/invite_flow_controller.dart';
import 'package:kinflow_app/features/household/application/invite_flow_state.dart';
import 'package:kinflow_app/features/household/application/invite_sharing_controller.dart';
import 'package:kinflow_app/features/household/application/invite_sharing_state.dart';
import 'package:kinflow_app/features/household/application/household_members_controller.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_clipboard.dart';
import 'package:kinflow_app/features/household/application/ports/household_invite_share_gateway.dart';
import 'package:kinflow_app/features/household/application/ports/pending_invite_store.dart';
import 'package:kinflow_app/features/household/application/unavailable_household_invite_sharing.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/services/household_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/services/household_creation_id_generator.dart';
import 'package:kinflow_app/features/household/domain/services/invite_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_repository_provider.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

export 'package:kinflow_app/features/household/presentation/providers/household_repository_provider.dart'
    show householdRepositoryProvider;

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

final householdInviteShareGatewayProvider =
    Provider<HouseholdInviteShareGateway>(
      (ref) => const UnavailableHouseholdInviteShareGateway(),
    );

final householdInviteClipboardProvider = Provider<HouseholdInviteClipboard>(
  (ref) => const UnavailableHouseholdInviteClipboard(),
);

final householdMembersControllerProvider =
    Provider.autoDispose<HouseholdMembersController>((ref) {
      final HouseholdMembersController controller = HouseholdMembersController(
        ref.watch(householdMemberRepositoryProvider),
        ref.watch(householdCommandIdGeneratorProvider),
        ref.watch(recentAuthenticationServiceProvider),
        ref.watch(authLifecycleControllerProvider),
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
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(householdMembersControllerProvider)
        .changeRole(member, role);
  }

  Future<void> removeMember(HouseholdMember member) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(householdMembersControllerProvider).removeMember(member);
  }

  Future<void> leaveHousehold() {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(householdMembersControllerProvider).leaveHousehold();
  }

  Future<void> transferOwner(HouseholdMember member) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return Future<void>.value();
    }
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
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return Future<void>.value();
    }
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
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(inviteCreationControllerProvider)
        .create(householdId: householdId, targetEmail: targetEmail);
  }

  Future<void> revoke() {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(inviteCreationControllerProvider).revoke();
  }

  void startNewInvite() {
    ref.read(inviteCreationControllerProvider).startNewInvite();
  }
}

final inviteSharingControllerProvider =
    Provider.autoDispose<InviteSharingController>((ref) {
      final InviteSharingController controller = InviteSharingController(
        ref.watch(householdInviteShareGatewayProvider),
        ref.watch(householdInviteClipboardProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final inviteSharingProvider =
    NotifierProvider.autoDispose<InviteSharingNotifier, InviteSharingState>(
      InviteSharingNotifier.new,
    );

final class InviteSharingNotifier extends Notifier<InviteSharingState> {
  @override
  InviteSharingState build() {
    final InviteSharingController controller = ref.watch(
      inviteSharingControllerProvider,
    );
    final StreamSubscription<InviteSharingState> subscription = controller
        .states
        .listen((InviteSharingState nextState) => state = nextState);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> share(HouseholdInviteLink link, {required String chooserTitle}) {
    return ref
        .read(inviteSharingControllerProvider)
        .share(link, chooserTitle: chooserTitle);
  }

  Future<void> copyLink(HouseholdInviteLink link) {
    return ref.read(inviteSharingControllerProvider).copyLink(link);
  }

  Future<void> copyShortCode(InviteShortCode shortCode) {
    return ref.read(inviteSharingControllerProvider).copyShortCode(shortCode);
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

  bool captureShortCode(String rawShortCode) {
    return ref
        .read(inviteFlowControllerProvider)
        .captureShortCode(rawShortCode);
  }

  Future<void> loadPreview() {
    return ref.read(inviteFlowControllerProvider).loadPreview();
  }

  Future<void> accept({required bool setActiveHousehold}) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.household,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(inviteFlowControllerProvider)
        .accept(setActiveHousehold: setActiveHousehold);
  }

  void clear() {
    ref.read(inviteFlowControllerProvider).clear();
  }
}
