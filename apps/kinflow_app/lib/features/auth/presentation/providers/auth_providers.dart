import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_controller.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  throw StateError('AuthSessionRepository override is required.');
});

final authSignInLauncherProvider = Provider<AuthSignInLauncher>((ref) {
  throw StateError('AuthSignInLauncher override is required.');
});

final sensitiveLocalStatePurgerProvider = Provider<SensitiveLocalStatePurger>((
  ref,
) {
  throw StateError('SensitiveLocalStatePurger override is required.');
});

final authLifecycleControllerProvider = Provider<AuthLifecycleController>((
  ref,
) {
  final AuthLifecycleController controller = AuthLifecycleController(
    repository: ref.watch(authSessionRepositoryProvider),
    signInLauncher: ref.watch(authSignInLauncherProvider),
    localStatePurger: ref.watch(sensitiveLocalStatePurgerProvider),
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

  Future<void> logout() {
    return ref.read(authLifecycleControllerProvider).logout();
  }
}
