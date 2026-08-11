import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/chores/application/one_time_chore_trash_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/chore_failure_message.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class OneTimeChoreTrashScreen extends ConsumerStatefulWidget {
  const OneTimeChoreTrashScreen({super.key});

  @override
  ConsumerState<OneTimeChoreTrashScreen> createState() =>
      _OneTimeChoreTrashScreenState();
}

class _OneTimeChoreTrashScreenState
    extends ConsumerState<OneTimeChoreTrashScreen>
    with WidgetsBindingObserver {
  HouseholdId? _requestedHouseholdId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      unawaited(ref.read(oneTimeChoreTrashProvider.notifier).refresh());
    }
  }

  void _load({bool force = false}) {
    final HouseholdId? householdId = ref
        .read(authLifecycleProvider)
        .activeHousehold
        ?.householdId;
    if (householdId == null) {
      context.go(AppRoutes.home);
      return;
    }
    final OneTimeChoreTrashState state = ref.read(oneTimeChoreTrashProvider);
    if (force &&
        state is OneTimeChoreTrashReady &&
        state.householdId == householdId) {
      unawaited(ref.read(oneTimeChoreTrashProvider.notifier).refresh());
      return;
    }
    if (!force && _requestedHouseholdId == householdId) {
      return;
    }
    _requestedHouseholdId = householdId;
    unawaited(ref.read(oneTimeChoreTrashProvider.notifier).load(householdId));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final OneTimeChoreTrashState state = ref.watch(oneTimeChoreTrashProvider);
    final bool busy =
        state is OneTimeChoreTrashReady &&
        (state.restoringOccurrenceId != null ||
            state.refreshing ||
            state.loadingMore);
    return AppResponsiveScaffold(
      key: const Key('choreTrash.screen'),
      title: localizations.choreTrashTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('choreTrash.refresh'),
          onPressed: busy ? null : () => _load(force: true),
          tooltip: localizations.retryAction,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const Key('choreTrash.today'),
          onPressed: () => context.go(AppRoutes.today),
          tooltip: localizations.choreTrashTodayAction,
          icon: const Icon(Icons.today_outlined),
        ),
      ],
      body: _body(localizations, state),
    );
  }

  Widget _body(AppLocalizations localizations, OneTimeChoreTrashState state) {
    return switch (state) {
      OneTimeChoreTrashInitial() ||
      OneTimeChoreTrashLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('choreTrash.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(localizations.choreTrashLoading, textAlign: TextAlign.center),
          ],
        ),
      ),
      OneTimeChoreTrashLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('choreTrash.error'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.delete_sweep_outlined, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                choreFailureMessage(localizations, failure),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('choreTrash.retry'),
              onPressed: () => unawaited(
                ref.read(oneTimeChoreTrashProvider.notifier).retry(),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      OneTimeChoreTrashReady() => _ready(localizations, state),
    };
  }

  Widget _ready(AppLocalizations localizations, OneTimeChoreTrashReady state) {
    final bool mutationsBlocked = ref.watch(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    );
    final bool busy =
        state.restoringOccurrenceId != null ||
        state.refreshing ||
        state.loadingMore;
    return RefreshIndicator(
      onRefresh: () => ref.read(oneTimeChoreTrashProvider.notifier).refresh(),
      child: ListView(
        key: const Key('choreTrash.list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayoutTokens.pageContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (state.refreshing) const LinearProgressIndicator(),
                  if (state.refreshFailure != null) ...<Widget>[
                    if (!state.refreshing)
                      const SizedBox(height: AppSpacing.sm),
                    _notice(
                      key: const Key('choreTrash.refreshError'),
                      message: localizations.choreTrashRefreshFailed,
                    ),
                  ],
                  if (state.actionFailure != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _notice(
                      key: const Key('choreTrash.actionError'),
                      message: choreFailureMessage(
                        localizations,
                        state.actionFailure!,
                      ),
                      error: true,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (state.items.isEmpty)
                    _empty(localizations)
                  else
                    ...state.items.map(
                      (DeletedOneTimeChore item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _itemCard(
                          localizations,
                          state,
                          item,
                          restoreEnabled: !mutationsBlocked && !busy,
                        ),
                      ),
                    ),
                  if (state.hasMore) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('choreTrash.loadMore'),
                      onPressed: busy
                          ? null
                          : () => unawaited(
                              ref
                                  .read(oneTimeChoreTrashProvider.notifier)
                                  .loadMore(),
                            ),
                      icon: state.loadingMore
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more),
                      label: Text(localizations.choreTrashLoadMoreAction),
                    ),
                  ],
                  if (state.loadMoreFailure != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      localizations.choreTrashLoadMoreFailed,
                      key: const Key('choreTrash.loadMoreError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(AppLocalizations localizations) {
    return Semantics(
      container: true,
      child: Padding(
        key: const Key('choreTrash.empty'),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: <Widget>[
            const Icon(Icons.delete_outline, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.choreTrashEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.choreTrashEmptyBody,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemCard(
    AppLocalizations localizations,
    OneTimeChoreTrashReady state,
    DeletedOneTimeChore item, {
    required bool restoreEnabled,
  }) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final bool use24Hour = MediaQuery.alwaysUse24HourFormatOf(context);
    final DateTime deletedLocal = item.deletedAt.toLocal();
    final String deletedLabel = localizations.choreTrashDeletedAt(
      material.formatMediumDate(deletedLocal),
      material.formatTimeOfDay(
        TimeOfDay.fromDateTime(deletedLocal),
        alwaysUse24HourFormat: use24Hour,
      ),
    );
    final String dueDate = material.formatMediumDate(
      item.dueLocalDate.toDateTime(),
    );
    final ChoreLocalTime? dueTime = item.dueLocalTime;
    final String dueLabel = dueTime == null
        ? localizations.choreTrashDueDate(dueDate)
        : localizations.choreTrashDueDateTime(
            dueDate,
            material.formatTimeOfDay(
              TimeOfDay(hour: dueTime.hour, minute: dueTime.minute),
              alwaysUse24HourFormat: use24Hour,
            ),
          );
    final bool restoring = state.restoringOccurrenceId == item.occurrenceId;
    return Card(
      key: Key('choreTrash.item.${item.occurrenceId.value}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            if (item.description != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(item.description!),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(dueLabel),
            Text(localizations.choreTrashAssignee(item.assigneeDisplayName)),
            Text(deletedLabel),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              key: Key('choreTrash.restore.${item.occurrenceId.value}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppTouchTarget.minimum),
              ),
              onPressed: restoreEnabled
                  ? () => unawaited(_restore(state.householdId, item))
                  : null,
              icon: restoring
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.restore_from_trash_outlined),
              label: Text(
                restoring
                    ? localizations.choreTrashRestoringAction
                    : localizations.choreTrashRestoreAction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notice({
    required Key key,
    required String message,
    bool error = false,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        key: key,
        color: error ? colors.errorContainer : colors.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            message,
            style: error ? TextStyle(color: colors.onErrorContainer) : null,
          ),
        ),
      ),
    );
  }

  Future<void> _restore(
    HouseholdId householdId,
    DeletedOneTimeChore item,
  ) async {
    await ref
        .read(oneTimeChoreTrashProvider.notifier)
        .restore(householdId: householdId, occurrenceId: item.occurrenceId);
    if (!mounted) {
      return;
    }
    final OneTimeChoreTrashState state = ref.read(oneTimeChoreTrashProvider);
    if (state is OneTimeChoreTrashReady &&
        state.restoredOccurrenceId == item.occurrenceId) {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: const Key('choreTrash.restore.succeeded'),
          content: Text(
            AppLocalizations.of(context).choreTrashRestoreSucceeded,
          ),
        ),
      );
    }
  }
}
