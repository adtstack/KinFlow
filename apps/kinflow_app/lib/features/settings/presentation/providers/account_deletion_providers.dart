import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/settings/application/account_deletion_controller.dart';
import 'package:kinflow_app/features/settings/application/account_deletion_state.dart';
import 'package:kinflow_app/features/settings/domain/repositories/account_deletion_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/account_deletion_command_id_generator.dart';

typedef AccountDeletionAcceptedHandler = Future<void> Function();

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>((
  ref,
) {
  throw StateError('AccountDeletionRepository override is required.');
});

final accountDeletionCommandIdGeneratorProvider =
    Provider<AccountDeletionCommandIdGenerator>((ref) {
      throw StateError(
        'AccountDeletionCommandIdGenerator override is required.',
      );
    });

final accountDeletionAcceptedHandlerProvider =
    Provider<AccountDeletionAcceptedHandler>((ref) {
      return () => ref.read(authLifecycleProvider.notifier).logout();
    });

final accountDeletionControllerProvider =
    Provider.autoDispose<AccountDeletionController>((ref) {
      final AccountDeletionController controller = AccountDeletionController(
        ref.watch(accountDeletionRepositoryProvider),
        ref.watch(accountDeletionCommandIdGeneratorProvider),
        ref.watch(recentAuthenticationServiceProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final accountDeletionProvider =
    NotifierProvider.autoDispose<AccountDeletionNotifier, AccountDeletionState>(
      AccountDeletionNotifier.new,
    );

final class AccountDeletionNotifier extends Notifier<AccountDeletionState> {
  @override
  AccountDeletionState build() {
    final AccountDeletionController controller = ref.watch(
      accountDeletionControllerProvider,
    );
    final StreamSubscription<AccountDeletionState> subscription = controller
        .states
        .listen((AccountDeletionState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load({bool preserveContent = false}) {
    return ref
        .read(accountDeletionControllerProvider)
        .load(preserveContent: preserveContent);
  }

  Future<void> requestDeletion({required bool subscriptionAcknowledged}) {
    return ref
        .read(accountDeletionControllerProvider)
        .requestDeletion(subscriptionAcknowledged: subscriptionAcknowledged);
  }

  Future<void> cancel() {
    return ref.read(accountDeletionControllerProvider).cancel();
  }

  void acknowledgeLogoutRequest() {
    ref.read(accountDeletionControllerProvider).acknowledgeLogoutRequest();
  }
}
