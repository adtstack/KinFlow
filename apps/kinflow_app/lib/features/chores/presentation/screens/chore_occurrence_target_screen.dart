import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/chores/application/chore_occurrence_target_controller.dart';
import 'package:kinflow_app/features/chores/application/chore_occurrence_target_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/chore_failure_message.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/chores/presentation/screens/chore_occurrence_history_sheet.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class ChoreOccurrenceTargetScreen extends ConsumerStatefulWidget {
  const ChoreOccurrenceTargetScreen({required this.occurrenceId, super.key});

  final ChoreOccurrenceId occurrenceId;

  @override
  ConsumerState<ChoreOccurrenceTargetScreen> createState() =>
      _ChoreOccurrenceTargetScreenState();
}

class _ChoreOccurrenceTargetScreenState
    extends ConsumerState<ChoreOccurrenceTargetScreen>
    with WidgetsBindingObserver {
  late final ChoreOccurrenceTargetController _controller;
  late final StreamSubscription<ChoreOccurrenceTargetState> _subscription;
  ChoreOccurrenceTargetState _state = const ChoreOccurrenceTargetInitial();
  HouseholdId? _requestedHouseholdId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = ChoreOccurrenceTargetController(
      repository: ref.read(choreRepositoryProvider),
      idGenerator: ref.read(choreCommandIdGeneratorProvider),
    );
    _subscription = _controller.states.listen((
      ChoreOccurrenceTargetState next,
    ) {
      if (mounted) setState(() => _state = next);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _load(force: true);
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
    if (!force && _requestedHouseholdId == householdId) return;
    _requestedHouseholdId = householdId;
    unawaited(
      _controller.load(
        householdId: householdId,
        occurrenceId: widget.occurrenceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    ref.listen<AuthLifecycleState>(authLifecycleProvider, (
      AuthLifecycleState? previous,
      AuthLifecycleState next,
    ) {
      if (previous?.activeHousehold?.householdId !=
              next.activeHousehold?.householdId &&
          next.activeHousehold != null) {
        _load(force: true);
      }
    });
    return AppResponsiveScaffold(
      key: const Key('chore.target.screen'),
      title: localizations.choreDetailsTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('chore.target.notifications'),
          onPressed: () => context.go(AppRoutes.notifications),
          tooltip: localizations.choreTargetNotificationsAction,
          icon: const Icon(Icons.notifications_outlined),
        ),
        IconButton(
          key: const Key('chore.target.close'),
          onPressed: () => context.go(AppRoutes.chores),
          tooltip: localizations.choreTargetChoresAction,
          icon: const Icon(Icons.close),
        ),
      ],
      body: _body(localizations),
    );
  }

  Widget _body(AppLocalizations localizations) {
    final ChoreOccurrenceTargetState state = _state;
    return switch (state) {
      ChoreOccurrenceTargetInitial() ||
      ChoreOccurrenceTargetLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('chore.target.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(localizations.choreTargetLoading, textAlign: TextAlign.center),
          ],
        ),
      ),
      ChoreOccurrenceTargetReady() => _ready(localizations, state),
      ChoreOccurrenceTargetLoadFailed(:final failure) => _failure(
        localizations,
        failure,
      ),
    };
  }

  Widget _ready(
    AppLocalizations localizations,
    ChoreOccurrenceTargetReady state,
  ) {
    final ChoreOccurrence occurrence = state.occurrence;
    return ChoreOccurrenceHistorySheet(
      key: ValueKey<String>(
        '${state.householdId.value}:${occurrence.id.value}:${occurrence.version}',
      ),
      repository: ref.read(choreRepositoryProvider),
      householdId: state.householdId,
      occurrence: occurrence,
      embedded: true,
      actions: _targetActions(localizations, state),
    );
  }

  Widget? _targetActions(
    AppLocalizations localizations,
    ChoreOccurrenceTargetReady state,
  ) {
    final bool mutationsBlocked = ref.watch(
      appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.chores),
    );
    final ChoreOccurrence occurrence = state.occurrence;
    final bool completed = occurrence.status == ChoreOccurrenceStatus.completed;
    final List<Widget> children = <Widget>[];

    if (state.actionFailure != null) {
      children.add(
        _notice(
          key: const Key('chore.target.actionError'),
          message: choreFailureMessage(localizations, state.actionFailure!),
          error: true,
        ),
      );
    }
    if (state.refreshFailure != null) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.sm));
      }
      children.add(
        _notice(
          key: const Key('chore.target.refreshError'),
          message: localizations.choreTargetLoadFailedBody,
          action: TextButton.icon(
            key: const Key('chore.target.refreshRetry'),
            onPressed: state.actionInFlight ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh),
            label: Text(localizations.retryAction),
          ),
        ),
      );
    }
    if (occurrence.canSetCompletion) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: AppSpacing.md));
      }
      final VoidCallback? onPressed = state.actionInFlight || mutationsBlocked
          ? null
          : () => unawaited(_controller.setCompleted(completed: !completed));
      final Widget icon = state.actionInFlight
          ? const SizedBox.square(
              dimension: AppSpacing.md,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(completed ? Icons.refresh : Icons.check_circle_outline);
      children.add(
        SizedBox(
          width: double.infinity,
          child: completed
              ? OutlinedButton.icon(
                  key: const Key('chore.target.completionAction'),
                  onPressed: onPressed,
                  icon: icon,
                  label: Text(localizations.choreReopenAction),
                )
              : FilledButton.icon(
                  key: const Key('chore.target.completionAction'),
                  onPressed: onPressed,
                  icon: icon,
                  label: Text(localizations.choreMarkCompleteAction),
                ),
        ),
      );
    }
    return children.isEmpty
        ? null
        : Column(
            key: const Key('chore.target.actions'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
  }

  Widget _notice({
    required Key key,
    required String message,
    bool error = false,
    Widget? action,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      key: key,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: error ? colors.errorContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                message,
                style: TextStyle(
                  color: error
                      ? colors.onErrorContainer
                      : colors.onSurfaceVariant,
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _failure(AppLocalizations localizations, ChoreFailure failure) {
    final bool unavailable = switch (failure.kind) {
      ChoreFailureKind.unauthenticated ||
      ChoreFailureKind.invalidInput ||
      ChoreFailureKind.notFoundOrForbidden => true,
      _ => false,
    };
    return ScrollableStatusLayout(
      child: Column(
        key: Key(
          unavailable ? 'chore.target.unavailable' : 'chore.target.error',
        ),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            unavailable ? Icons.event_busy_outlined : Icons.sync_problem,
            size: AppIconSize.status,
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              unavailable
                  ? localizations.choreTargetUnavailableTitle
                  : localizations.choreTargetLoadFailedTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            unavailable
                ? localizations.choreTargetUnavailableBody
                : localizations.choreTargetLoadFailedBody,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!unavailable) ...<Widget>[
            FilledButton.icon(
              key: const Key('chore.target.retry'),
              onPressed: () => unawaited(_controller.retry()),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          OutlinedButton.icon(
            key: const Key('chore.target.openNotifications'),
            onPressed: () => context.go(AppRoutes.notifications),
            icon: const Icon(Icons.notifications_outlined),
            label: Text(localizations.choreTargetNotificationsAction),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            key: const Key('chore.target.openChores'),
            onPressed: () => context.go(AppRoutes.chores),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(localizations.choreTargetChoresAction),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }
}
