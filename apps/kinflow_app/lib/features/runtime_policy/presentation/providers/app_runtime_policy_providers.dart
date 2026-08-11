import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/runtime_policy/application/app_runtime_policy_controller.dart';
import 'package:kinflow_app/features/runtime_policy/application/app_runtime_policy_state.dart';
import 'package:kinflow_app/features/runtime_policy/application/ports/runtime_policy_external_link_launcher.dart';
import 'package:kinflow_app/features/runtime_policy/application/unavailable_app_runtime_policy_repository.dart';
import 'package:kinflow_app/features/runtime_policy/application/unavailable_runtime_policy_external_link_launcher.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/domain/repositories/app_runtime_policy_repository.dart';

final appRuntimePolicyRepositoryProvider = Provider<AppRuntimePolicyRepository>(
  (ref) => const UnavailableAppRuntimePolicyRepository(),
);

final runtimePolicyExternalLinkLauncherProvider =
    Provider<RuntimePolicyExternalLinkLauncher>(
      (ref) => const UnavailableRuntimePolicyExternalLinkLauncher(),
    );

final appRuntimePolicyControllerProvider = Provider<AppRuntimePolicyController>(
  (ref) {
    final AppRuntimePolicyController controller = AppRuntimePolicyController(
      ref.watch(appRuntimePolicyRepositoryProvider),
    );
    ref.onDispose(() => unawaited(controller.dispose()));
    return controller;
  },
);

final appRuntimePolicyProvider =
    NotifierProvider<AppRuntimePolicyNotifier, AppRuntimePolicyState>(
      AppRuntimePolicyNotifier.new,
    );

final appRuntimePolicyMutationsBlockedProvider = Provider<bool>((ref) {
  final AppRuntimePolicyState state = ref.watch(appRuntimePolicyProvider);
  return state is AppRuntimePolicyReady && state.snapshot.mutationsBlocked;
});

final appRuntimePolicyFeatureMutationsBlockedProvider =
    Provider.family<bool, AppRuntimeFeature>((ref, feature) {
      final AppRuntimePolicyState state = ref.watch(appRuntimePolicyProvider);
      return state is AppRuntimePolicyReady &&
          state.snapshot.mutationsBlockedFor(feature);
    });

final class AppRuntimePolicyNotifier extends Notifier<AppRuntimePolicyState> {
  @override
  AppRuntimePolicyState build() {
    final AppRuntimePolicyController controller = ref.watch(
      appRuntimePolicyControllerProvider,
    );
    final StreamSubscription<AppRuntimePolicyState> subscription = controller
        .states
        .listen((AppRuntimePolicyState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load({bool preserveContent = false}) {
    return ref
        .read(appRuntimePolicyControllerProvider)
        .load(preserveContent: preserveContent);
  }
}
