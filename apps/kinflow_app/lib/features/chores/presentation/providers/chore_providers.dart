import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/chores/application/chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_controller.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_state.dart';
import 'package:kinflow_app/features/chores/application/household_activation_progress_controller.dart';
import 'package:kinflow_app/features/chores/application/household_activation_progress_state.dart';
import 'package:kinflow_app/features/chores/application/household_weekly_report_controller.dart';
import 'package:kinflow_app/features/chores/application/household_weekly_report_state.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_creation_controller.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_creation_state.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_trash_controller.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_trash_state.dart';
import 'package:kinflow_app/features/chores/application/recurring_chore_creation_controller.dart';
import 'package:kinflow_app/features/chores/application/recurring_chore_creation_state.dart';
import 'package:kinflow_app/features/chores/application/today_chores_controller.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_sync_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

final choreRepositoryProvider = Provider<ChoreRepository>((ref) {
  throw StateError('ChoreRepository override is required.');
});

final choreSyncRepositoryProvider = Provider<ChoreSyncRepository?>(
  (ref) => null,
);

final choreCommandIdGeneratorProvider = Provider<ChoreCommandIdGenerator>((
  ref,
) {
  throw StateError('ChoreCommandIdGenerator override is required.');
});

final guidedChoreSetupResumeStoreProvider =
    Provider<GuidedChoreSetupResumeStore>((ref) {
      return const UnavailableGuidedChoreSetupResumeStore();
    });

final choreCompletionOutboxProvider = Provider<ChoreCompletionOutbox>((ref) {
  return const UnavailableChoreCompletionOutbox();
});

final householdActivationProgressControllerProvider =
    Provider.autoDispose<HouseholdActivationProgressController>((ref) {
      final HouseholdActivationProgressController controller =
          HouseholdActivationProgressController(
            repository: ref.watch(choreRepositoryProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final householdActivationProgressProvider =
    NotifierProvider.autoDispose<
      HouseholdActivationProgressNotifier,
      HouseholdActivationProgressState
    >(HouseholdActivationProgressNotifier.new);

final class HouseholdActivationProgressNotifier
    extends Notifier<HouseholdActivationProgressState> {
  @override
  HouseholdActivationProgressState build() {
    final HouseholdActivationProgressController controller = ref.watch(
      householdActivationProgressControllerProvider,
    );
    final StreamSubscription<HouseholdActivationProgressState> subscription =
        controller.states.listen(
          (HouseholdActivationProgressState nextState) => state = nextState,
        );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load(HouseholdId householdId, {bool preserveContent = false}) {
    return ref
        .read(householdActivationProgressControllerProvider)
        .load(householdId, preserveContent: preserveContent);
  }
}

final householdWeeklyReportControllerProvider =
    Provider.autoDispose<HouseholdWeeklyReportController>((ref) {
      final HouseholdWeeklyReportController controller =
          HouseholdWeeklyReportController(
            repository: ref.watch(choreRepositoryProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final householdWeeklyReportProvider =
    NotifierProvider.autoDispose<
      HouseholdWeeklyReportNotifier,
      HouseholdWeeklyReportState
    >(HouseholdWeeklyReportNotifier.new);

final class HouseholdWeeklyReportNotifier
    extends Notifier<HouseholdWeeklyReportState> {
  @override
  HouseholdWeeklyReportState build() {
    final HouseholdWeeklyReportController controller = ref.watch(
      householdWeeklyReportControllerProvider,
    );
    final StreamSubscription<HouseholdWeeklyReportState> subscription =
        controller.states.listen(
          (HouseholdWeeklyReportState nextState) => state = nextState,
        );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load(
    HouseholdWeeklyReportRequest request, {
    bool preserveContent = false,
    bool force = false,
  }) {
    return ref
        .read(householdWeeklyReportControllerProvider)
        .load(request, preserveContent: preserveContent, force: force);
  }
}

final guidedChoreSetupControllerProvider =
    Provider.autoDispose<GuidedChoreSetupController>((ref) {
      final GuidedChoreSetupController controller = GuidedChoreSetupController(
        repository: ref.watch(choreRepositoryProvider),
        idGenerator: ref.watch(choreCommandIdGeneratorProvider),
        resumeStore: ref.watch(guidedChoreSetupResumeStoreProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final guidedChoreSetupProvider =
    NotifierProvider.autoDispose<
      GuidedChoreSetupNotifier,
      GuidedChoreSetupState
    >(GuidedChoreSetupNotifier.new);

final class GuidedChoreSetupNotifier extends Notifier<GuidedChoreSetupState> {
  @override
  GuidedChoreSetupState build() {
    final GuidedChoreSetupController controller = ref.watch(
      guidedChoreSetupControllerProvider,
    );
    final StreamSubscription<GuidedChoreSetupState> subscription = controller
        .states
        .listen((GuidedChoreSetupState nextState) => state = nextState);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load({
    required HouseholdId householdId,
    required HouseholdMemberId assigneeMemberId,
  }) {
    return ref
        .read(guidedChoreSetupControllerProvider)
        .load(householdId: householdId, assigneeMemberId: assigneeMemberId);
  }

  Future<void> submit(List<GuidedChoreSetupInput> inputs) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref.read(guidedChoreSetupControllerProvider).submit(inputs);
  }

  Future<bool> discard() {
    return ref.read(guidedChoreSetupControllerProvider).discard();
  }
}

final todayChoresControllerProvider =
    Provider.autoDispose<TodayChoresController>((ref) {
      final TodayChoresController controller = TodayChoresController(
        repository: ref.watch(choreRepositoryProvider),
        idGenerator: ref.watch(choreCommandIdGeneratorProvider),
        completionOutbox: ref.watch(choreCompletionOutboxProvider),
        syncRepository: ref.watch(choreSyncRepositoryProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final todayChoresProvider =
    NotifierProvider.autoDispose<TodayChoresNotifier, TodayChoresState>(
      TodayChoresNotifier.new,
    );

final oneTimeChoreTrashControllerProvider =
    Provider.autoDispose<OneTimeChoreTrashController>((ref) {
      final OneTimeChoreTrashController controller =
          OneTimeChoreTrashController(
            repository: ref.watch(choreRepositoryProvider),
            idGenerator: ref.watch(choreCommandIdGeneratorProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final oneTimeChoreTrashProvider =
    NotifierProvider.autoDispose<
      OneTimeChoreTrashNotifier,
      OneTimeChoreTrashState
    >(OneTimeChoreTrashNotifier.new);

final class OneTimeChoreTrashNotifier extends Notifier<OneTimeChoreTrashState> {
  @override
  OneTimeChoreTrashState build() {
    final OneTimeChoreTrashController controller = ref.watch(
      oneTimeChoreTrashControllerProvider,
    );
    final StreamSubscription<OneTimeChoreTrashState> subscription = controller
        .states
        .listen((OneTimeChoreTrashState nextState) => state = nextState);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load(HouseholdId householdId, {int limit = 30}) {
    final DeletedOneTimeChoreListRequest? request =
        DeletedOneTimeChoreListRequest.tryCreate(
          householdId: householdId,
          limit: limit,
        );
    return request == null
        ? Future<void>.value()
        : ref.read(oneTimeChoreTrashControllerProvider).load(request);
  }

  Future<void> retry() {
    return ref.read(oneTimeChoreTrashControllerProvider).retry();
  }

  Future<void> refresh() {
    return ref.read(oneTimeChoreTrashControllerProvider).refresh();
  }

  Future<void> loadMore() {
    return ref.read(oneTimeChoreTrashControllerProvider).loadMore();
  }

  Future<void> restore({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(oneTimeChoreTrashControllerProvider)
        .restore(householdId: householdId, occurrenceId: occurrenceId);
  }
}

final todayOverdueChoresControllerProvider =
    Provider.autoDispose<TodayChoresController>((ref) {
      final TodayChoresController controller = TodayChoresController(
        repository: ref.watch(choreRepositoryProvider),
        idGenerator: ref.watch(choreCommandIdGeneratorProvider),
        completionOutbox: ref.watch(choreCompletionOutboxProvider),
        syncRepository: ref.watch(choreSyncRepositoryProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final todayOverdueChoresProvider =
    NotifierProvider.autoDispose<TodayOverdueChoresNotifier, TodayChoresState>(
      TodayOverdueChoresNotifier.new,
    );

final class TodayChoresNotifier extends Notifier<TodayChoresState> {
  @override
  TodayChoresState build() {
    final TodayChoresController controller = ref.watch(
      todayChoresControllerProvider,
    );
    final StreamSubscription<TodayChoresState> subscription = controller.states
        .listen((TodayChoresState nextState) => state = nextState);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load(HouseholdId householdId) {
    return ref.read(todayChoresControllerProvider).load(householdId);
  }

  Future<void> loadQuery(
    ChoreListRequest request, {
    HouseholdMemberId? actorMemberId,
  }) {
    return ref
        .read(todayChoresControllerProvider)
        .loadQuery(request, actorMemberId: actorMemberId);
  }

  Future<void> refresh() {
    return ref.read(todayChoresControllerProvider).refresh();
  }

  Future<void> resume() {
    return ref.read(todayChoresControllerProvider).resume();
  }

  Future<void> reconnect() {
    return ref.read(todayChoresControllerProvider).reconnect();
  }

  Future<void> loadMore() {
    return ref.read(todayChoresControllerProvider).loadMore();
  }

  Future<void> prepareCompletionOutbox({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
  }) {
    final bool blocked = ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    );
    return ref
        .read(todayChoresControllerProvider)
        .prepareCompletionOutbox(
          householdId: householdId,
          actorMemberId: actorMemberId,
          allowReplay: !blocked,
        );
  }

  Future<bool> discardCompletionOutbox() {
    return ref.read(todayChoresControllerProvider).discardCompletionOutbox();
  }

  Future<void> setCompleted({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required bool completed,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .setCompleted(
          householdId: householdId,
          occurrenceId: occurrenceId,
          completed: completed,
        );
  }

  Future<void> skipOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .skipOccurrence(householdId: householdId, occurrenceId: occurrenceId);
  }

  Future<void> restoreSkippedOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .restoreSkippedOccurrence(
          householdId: householdId,
          occurrenceId: occurrenceId,
        );
  }

  Future<void> rescheduleOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .rescheduleOccurrence(
          householdId: householdId,
          occurrenceId: occurrenceId,
          dueLocalDate: dueLocalDate,
          dueLocalTime: dueLocalTime,
        );
  }

  Future<void> reassignOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required HouseholdMemberId assigneeMemberId,
    required String assigneeDisplayName,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .reassignOccurrence(
          householdId: householdId,
          occurrenceId: occurrenceId,
          assigneeMemberId: assigneeMemberId,
          assigneeDisplayName: assigneeDisplayName,
        );
  }

  Future<void> updateOneTimeChore({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalDate dueLocalDate,
    required ChoreLocalTime? dueLocalTime,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .updateOneTimeChore(
          householdId: householdId,
          occurrenceId: occurrenceId,
          title: title,
          description: description,
          assigneeMemberId: assigneeMemberId,
          dueLocalDate: dueLocalDate,
          dueLocalTime: dueLocalTime,
        );
  }

  Future<void> deleteOneTimeChore({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .deleteOneTimeChore(
          householdId: householdId,
          occurrenceId: occurrenceId,
        );
  }

  Future<void> undoDeleteOneTimeChore({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .undoDeleteOneTimeChore(
          householdId: householdId,
          occurrenceId: occurrenceId,
        );
  }

  void dismissDeleteOneTimeChoreUndo(ChoreOccurrenceId occurrenceId) {
    ref
        .read(todayChoresControllerProvider)
        .dismissDeleteOneTimeChoreUndo(occurrenceId);
  }

  Future<void> updateRepeatingSeries({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalTime? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .updateRepeatingSeries(
          householdId: householdId,
          occurrenceId: occurrenceId,
          title: title,
          description: description,
          assigneeMemberId: assigneeMemberId,
          dueLocalTime: dueLocalTime,
          recurrenceRule: recurrenceRule,
        );
  }

  Future<void> updateRepeatingSeriesFromOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required ChoreLocalTime? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .updateRepeatingSeriesFromOccurrence(
          householdId: householdId,
          occurrenceId: occurrenceId,
          title: title,
          description: description,
          assigneeMemberId: assigneeMemberId,
          dueLocalTime: dueLocalTime,
          recurrenceRule: recurrenceRule,
        );
  }

  Future<void> cancelRepeatingSeries({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .cancelRepeatingSeries(
          householdId: householdId,
          occurrenceId: occurrenceId,
        );
  }

  Future<void> cancelRepeatingSeriesFromOccurrence({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .cancelRepeatingSeriesFromOccurrence(
          householdId: householdId,
          occurrenceId: occurrenceId,
        );
  }

  Future<void> resumeRepeatingSeriesCancellation({
    required HouseholdId householdId,
    required ChoreSeriesId seriesId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayChoresControllerProvider)
        .resumeRepeatingSeriesCancellation(
          householdId: householdId,
          seriesId: seriesId,
        );
  }
}

final class TodayOverdueChoresNotifier extends Notifier<TodayChoresState> {
  @override
  TodayChoresState build() {
    final TodayChoresController controller = ref.watch(
      todayOverdueChoresControllerProvider,
    );
    final StreamSubscription<TodayChoresState> subscription = controller.states
        .listen((TodayChoresState nextState) => state = nextState);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> loadQuery(
    ChoreListRequest request, {
    HouseholdMemberId? actorMemberId,
  }) {
    return ref
        .read(todayOverdueChoresControllerProvider)
        .loadQuery(request, actorMemberId: actorMemberId);
  }

  Future<void> refresh() {
    return ref.read(todayOverdueChoresControllerProvider).refresh();
  }

  Future<void> resume() {
    return ref.read(todayOverdueChoresControllerProvider).resume();
  }

  Future<void> reconnect() {
    return ref.read(todayOverdueChoresControllerProvider).reconnect();
  }

  Future<void> loadMore() {
    return ref.read(todayOverdueChoresControllerProvider).loadMore();
  }

  Future<void> setCompleted({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    required bool completed,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(todayOverdueChoresControllerProvider)
        .setCompleted(
          householdId: householdId,
          occurrenceId: occurrenceId,
          completed: completed,
        );
  }
}

final oneTimeChoreCreationControllerProvider =
    Provider.autoDispose<OneTimeChoreCreationController>((ref) {
      final OneTimeChoreCreationController controller =
          OneTimeChoreCreationController(
            repository: ref.watch(choreRepositoryProvider),
            idGenerator: ref.watch(choreCommandIdGeneratorProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final oneTimeChoreCreationProvider =
    NotifierProvider.autoDispose<
      OneTimeChoreCreationNotifier,
      OneTimeChoreCreationState
    >(OneTimeChoreCreationNotifier.new);

final class OneTimeChoreCreationNotifier
    extends Notifier<OneTimeChoreCreationState> {
  @override
  OneTimeChoreCreationState build() {
    final OneTimeChoreCreationController controller = ref.watch(
      oneTimeChoreCreationControllerProvider,
    );
    final StreamSubscription<OneTimeChoreCreationState> subscription =
        controller.states.listen(
          (OneTimeChoreCreationState nextState) => state = nextState,
        );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> create({
    required HouseholdId householdId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required String dueLocalDate,
    required String? dueLocalTime,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(oneTimeChoreCreationControllerProvider)
        .create(
          householdId: householdId,
          title: title,
          description: description,
          assigneeMemberId: assigneeMemberId,
          dueLocalDate: dueLocalDate,
          dueLocalTime: dueLocalTime,
        );
  }

  void reset() {
    ref.read(oneTimeChoreCreationControllerProvider).reset();
  }
}

final recurringChoreCreationControllerProvider =
    Provider.autoDispose<RecurringChoreCreationController>((ref) {
      final RecurringChoreCreationController controller =
          RecurringChoreCreationController(
            repository: ref.watch(choreRepositoryProvider),
            idGenerator: ref.watch(choreCommandIdGeneratorProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final recurringChoreCreationProvider =
    NotifierProvider.autoDispose<
      RecurringChoreCreationNotifier,
      RecurringChoreCreationState
    >(RecurringChoreCreationNotifier.new);

final class RecurringChoreCreationNotifier
    extends Notifier<RecurringChoreCreationState> {
  @override
  RecurringChoreCreationState build() {
    final RecurringChoreCreationController controller = ref.watch(
      recurringChoreCreationControllerProvider,
    );
    final StreamSubscription<RecurringChoreCreationState> subscription =
        controller.states.listen(
          (RecurringChoreCreationState nextState) => state = nextState,
        );
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> create({
    required HouseholdId householdId,
    required String title,
    required String description,
    required HouseholdMemberId assigneeMemberId,
    required String startLocalDate,
    required String? dueLocalTime,
    required ChoreRecurrenceRule recurrenceRule,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(recurringChoreCreationControllerProvider)
        .create(
          householdId: householdId,
          title: title,
          description: description,
          assigneeMemberId: assigneeMemberId,
          startLocalDate: startLocalDate,
          dueLocalTime: dueLocalTime,
          recurrenceRule: recurrenceRule,
        );
  }

  void reset() {
    ref.read(recurringChoreCreationControllerProvider).reset();
  }
}
