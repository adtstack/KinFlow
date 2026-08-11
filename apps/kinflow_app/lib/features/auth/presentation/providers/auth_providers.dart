import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_controller.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/application/unavailable_auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_email_otp_service.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_repository_provider.dart';
import 'package:kinflow_app/features/offline/application/active_household_transition_local_state.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  throw StateError('AuthSessionRepository override is required.');
});

final authSignInLauncherProvider = Provider<AuthSignInLauncher>((ref) {
  throw StateError('AuthSignInLauncher override is required.');
});

final authEmailOtpServiceProvider = Provider<AuthEmailOtpService>((ref) {
  return const UnavailableAuthEmailOtpService();
});

final sensitiveLocalStatePurgerProvider = Provider<SensitiveLocalStatePurger>((
  ref,
) {
  throw StateError('SensitiveLocalStatePurger override is required.');
});

final activeHouseholdSnapshotWriterProvider =
    Provider<ActiveHouseholdSnapshotWriter>((ref) {
      throw StateError('ActiveHouseholdSnapshotWriter override is required.');
    });

final activeHouseholdTransitionLocalStateProvider =
    Provider<ActiveHouseholdTransitionLocalState>((ref) {
      return const UnavailableActiveHouseholdTransitionLocalState();
    });

final authLifecycleControllerProvider = Provider<AuthLifecycleController>((
  ref,
) {
  final AuthLifecycleController controller = AuthLifecycleController(
    repository: ref.watch(authSessionRepositoryProvider),
    signInLauncher: ref.watch(authSignInLauncherProvider),
    localStatePurger: ref.watch(sensitiveLocalStatePurgerProvider),
    householdRepository: ref.watch(householdRepositoryProvider),
    activeHouseholdSnapshotWriter: ref.watch(
      activeHouseholdSnapshotWriterProvider,
    ),
    activeHouseholdTransitionLocalState: ref.watch(
      activeHouseholdTransitionLocalStateProvider,
    ),
  );
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});

final authLifecycleProvider =
    NotifierProvider<AuthLifecycleNotifier, AuthLifecycleState>(
      AuthLifecycleNotifier.new,
    );

final class AuthLifecycleNotifier extends Notifier<AuthLifecycleState> {
  @override
  AuthLifecycleState build() {
    final AuthLifecycleController controller = ref.watch(
      authLifecycleControllerProvider,
    );
    final StreamSubscription<AuthLifecycleState> subscription = controller
        .states
        .listen((AuthLifecycleState nextState) {
          state = nextState;
        });
    ref.onDispose(() => unawaited(subscription.cancel()));
    unawaited(controller.start());
    return controller.state;
  }

  bool get isSignInAvailable {
    return ref.read(authLifecycleControllerProvider).isSignInAvailable;
  }

  bool get canRequestSignIn {
    return ref.read(authLifecycleControllerProvider).canRequestSignIn;
  }

  Future<void> requestSignIn() {
    return ref.read(authLifecycleControllerProvider).requestSignIn();
  }

  Future<void> refresh() {
    return ref.read(authLifecycleControllerProvider).refresh();
  }

  Future<void> revalidateOnResume() {
    return ref.read(authLifecycleControllerProvider).revalidateOnResume();
  }

  Future<void> logout() {
    return ref.read(authLifecycleControllerProvider).logout();
  }

  Future<void> markActiveHousehold(ActiveHousehold household) {
    return ref
        .read(authLifecycleControllerProvider)
        .markActiveHousehold(household);
  }

  Future<void> retryHouseholdResolution() {
    return ref.read(authLifecycleControllerProvider).retryHouseholdResolution();
  }
}
