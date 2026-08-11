import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_primary_destination.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/chores/application/household_activation_progress_state.dart';
import 'package:kinflow_app/features/chores/application/household_weekly_report_state.dart';
import 'package:kinflow_app/features/chores/application/today_chores_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_sync_signal.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/chores/presentation/chore_failure_message.dart';
import 'package:kinflow_app/features/chores/presentation/providers/chore_providers.dart';
import 'package:kinflow_app/features/chores/presentation/screens/chore_occurrence_history_sheet.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/chore_recurrence_editor.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/household_activation_progress_card.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/household_weekly_report_card.dart';
import 'package:kinflow_app/features/chores/presentation/widgets/household_weekly_report_sheet.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/notifications/presentation/widgets/notification_app_shell_action.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/today/application/today_calendar_state.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';
import 'package:kinflow_app/features/today/presentation/providers/today_providers.dart';
import 'package:kinflow_app/features/today/presentation/widgets/today_calendar_section.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

enum _TodayOccurrenceAction {
  editOneTime,
  deleteOneTime,
  reschedule,
  reassign,
  skip,
  editSeries,
  editSeriesFromOccurrence,
  cancelSeriesFromOccurrence,
  cancelSeries,
}

final class _OneTimeUpdateSelection {
  const _OneTimeUpdateSelection({
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalDate,
    required this.dueLocalTime,
  });

  final String title;
  final String description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
}

enum _TodayChoreSource { primary, overdue }

final class _OccurrenceScheduleSelection {
  const _OccurrenceScheduleSelection({
    required this.dueLocalDate,
    required this.dueLocalTime,
  });

  final ChoreLocalDate dueLocalDate;
  final ChoreLocalTime? dueLocalTime;
}

final class _SeriesUpdateSelection {
  const _SeriesUpdateSelection({
    required this.title,
    required this.description,
    required this.assigneeMemberId,
    required this.dueLocalTime,
    required this.recurrenceRule,
  });

  final String title;
  final String description;
  final HouseholdMemberId assigneeMemberId;
  final ChoreLocalTime? dueLocalTime;
  final ChoreRecurrenceRule recurrenceRule;
}

bool _sameChoreWeekdaySet(
  Iterable<ChoreWeekday> left,
  Iterable<ChoreWeekday> right,
) {
  final Set<ChoreWeekday> leftSet = left.toSet();
  final Set<ChoreWeekday> rightSet = right.toSet();
  return leftSet.length == rightSet.length && leftSet.containsAll(rightSet);
}

enum _TodayCompactAction { chores, weeklyReport, trash, refresh }

class TodayChoresScreen extends ConsumerStatefulWidget {
  const TodayChoresScreen({super.key}) : _isChoresHub = false;

  const TodayChoresScreen.chores({super.key}) : _isChoresHub = true;

  final bool _isChoresHub;

  @override
  ConsumerState<TodayChoresScreen> createState() => _TodayChoresScreenState();
}

class _TodayChoresScreenState extends ConsumerState<TodayChoresScreen>
    with WidgetsBindingObserver {
  String? _requestedQuery;
  late ChoreListView _selectedView;
  var _meOnly = false;
  var _reassignmentRosterBusy = false;
  var _completedExpanded = false;
  late bool _guidedResumePreflightComplete;
  var _guidedResumePreflightPending = false;
  var _loadEpoch = 0;

  List<ChoreListView> get _availableViews => widget._isChoresHub
      ? const <ChoreListView>[
          ChoreListView.upcoming,
          ChoreListView.overdue,
          ChoreListView.completed,
        ]
      : ChoreListView.values;

  @override
  void initState() {
    super.initState();
    _selectedView = widget._isChoresHub
        ? ChoreListView.upcoming
        : ChoreListView.today;
    _guidedResumePreflightComplete = widget._isChoresHub;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadToday());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadToday(force: true);
      unawaited(ref.read(todayChoresProvider.notifier).resume());
      if (_selectedView == ChoreListView.today) {
        unawaited(ref.read(todayOverdueChoresProvider.notifier).resume());
      }
    }
  }

  void _loadToday({bool force = false}) {
    if (!mounted) {
      return;
    }
    final activeHousehold = ref.read(authLifecycleProvider).activeHousehold;
    final HouseholdId? householdId = activeHousehold?.householdId;
    final HouseholdMemberId? actorMemberId = activeHousehold?.memberId;
    if (householdId == null || actorMemberId == null) {
      context.go(AppRoutes.home);
      return;
    }
    if (!_guidedResumePreflightComplete) {
      if (!_guidedResumePreflightPending) {
        unawaited(
          _preflightGuidedResume(
            householdId: householdId,
            actorMemberId: actorMemberId,
            force: force,
          ),
        );
      }
      return;
    }
    final HouseholdMemberId? assigneeMemberId = _meOnly ? actorMemberId : null;
    final ChoreListRequest request = ChoreListRequest.tryCreate(
      householdId: householdId,
      view: _selectedView,
      assigneeMemberId: assigneeMemberId,
    )!;
    final String query =
        '${householdId.value}:${_selectedView.wireName}:'
        '${assigneeMemberId?.value ?? 'everyone'}';
    if (!force && _requestedQuery == query) {
      return;
    }
    _requestedQuery = query;
    final int epoch = ++_loadEpoch;
    unawaited(
      _loadTodayAfterCompletionPreflight(
        epoch: epoch,
        householdId: householdId,
        actorMemberId: actorMemberId,
        assigneeMemberId: assigneeMemberId,
        request: request,
        force: force,
      ),
    );
  }

  Future<void> _loadTodayAfterCompletionPreflight({
    required int epoch,
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required HouseholdMemberId? assigneeMemberId,
    required ChoreListRequest request,
    required bool force,
  }) async {
    await ref
        .read(todayChoresProvider.notifier)
        .prepareCompletionOutbox(
          householdId: householdId,
          actorMemberId: actorMemberId,
        );
    if (!mounted || epoch != _loadEpoch) {
      return;
    }
    final TodayChoresState state = ref.read(todayChoresProvider);
    final bool sameReadyQuery =
        state is TodayChoresReady &&
        state.today.householdId == householdId &&
        state.today.view == _selectedView &&
        state.today.assigneeFilterMemberId == assigneeMemberId;
    final Future<void> choreLoad = force && sameReadyQuery
        ? ref.read(todayChoresProvider.notifier).refresh()
        : ref
              .read(todayChoresProvider.notifier)
              .loadQuery(request, actorMemberId: actorMemberId);
    final ChoreListRequest? overdueRequest =
        _selectedView == ChoreListView.today
        ? ChoreListRequest.tryCreate(
            householdId: householdId,
            view: ChoreListView.overdue,
            assigneeMemberId: assigneeMemberId,
          )
        : null;
    final TodayChoresState overdueState = ref.read(todayOverdueChoresProvider);
    final bool sameReadyOverdueQuery =
        overdueState is TodayChoresReady &&
        overdueState.today.householdId == householdId &&
        overdueState.today.view == ChoreListView.overdue &&
        overdueState.today.assigneeFilterMemberId == assigneeMemberId;
    final Future<void>? overdueLoad = overdueRequest == null
        ? null
        : force && sameReadyOverdueQuery
        ? ref.read(todayOverdueChoresProvider.notifier).refresh()
        : ref
              .read(todayOverdueChoresProvider.notifier)
              .loadQuery(overdueRequest, actorMemberId: actorMemberId);
    await Future.wait<void>(<Future<void>>[
      choreLoad,
      ref.read(notificationCenterProvider.notifier).ensureLoaded(householdId),
      if (_selectedView == ChoreListView.today)
        ref
            .read(todayCalendarProvider.notifier)
            .load(
              TodayCalendarRequest(
                householdId: householdId,
                participantMemberId: assigneeMemberId,
              ),
            ),
      if (_selectedView == ChoreListView.today)
        ref
            .read(householdActivationProgressProvider.notifier)
            .load(householdId, preserveContent: force),
      if (_selectedView == ChoreListView.today)
        ref
            .read(householdWeeklyReportProvider.notifier)
            .load(
              HouseholdWeeklyReportRequest.tryCreate(
                householdId: householdId,
                weekOffset: HouseholdWeeklyReportRequest.latestWeekOffset,
              )!,
              preserveContent: force,
              force: force,
            ),
      ?overdueLoad,
    ]);
  }

  void _retryOverdue() {
    if (!mounted) {
      return;
    }
    final activeHousehold = ref.read(authLifecycleProvider).activeHousehold;
    final HouseholdId? householdId = activeHousehold?.householdId;
    final HouseholdMemberId? actorMemberId = activeHousehold?.memberId;
    if (householdId == null || actorMemberId == null) {
      context.go(AppRoutes.home);
      return;
    }
    final HouseholdMemberId? assigneeMemberId = _meOnly ? actorMemberId : null;
    final ChoreListRequest overdueRequest = ChoreListRequest.tryCreate(
      householdId: householdId,
      view: ChoreListView.overdue,
      assigneeMemberId: assigneeMemberId,
    )!;
    final int epoch = ++_loadEpoch;
    unawaited(
      _retryOverdueAfterCompletionPreflight(
        epoch: epoch,
        householdId: householdId,
        actorMemberId: actorMemberId,
        assigneeMemberId: assigneeMemberId,
        overdueRequest: overdueRequest,
      ),
    );
  }

  Future<void> _retryOverdueAfterCompletionPreflight({
    required int epoch,
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required HouseholdMemberId? assigneeMemberId,
    required ChoreListRequest overdueRequest,
  }) async {
    final TodayChoreCompletionSync? completionBefore = _completionSyncFrom(
      ref.read(todayChoresProvider),
    );
    await ref
        .read(todayChoresProvider.notifier)
        .prepareCompletionOutbox(
          householdId: householdId,
          actorMemberId: actorMemberId,
        );
    if (!mounted || epoch != _loadEpoch) {
      return;
    }
    final TodayChoreCompletionSync? completionAfter = _completionSyncFrom(
      ref.read(todayChoresProvider),
    );
    final bool completionWasProcessed =
        (completionBefore?.hasStoredIntent ?? false) ||
        completionBefore?.kind != completionAfter?.kind ||
        completionBefore?.occurrenceId != completionAfter?.occurrenceId;
    final TodayChoresState overdueState = ref.read(todayOverdueChoresProvider);
    final bool sameOverdueQuery =
        overdueState is TodayChoresReady &&
        overdueState.today.householdId == householdId &&
        overdueState.today.view == ChoreListView.overdue &&
        overdueState.today.assigneeFilterMemberId == assigneeMemberId;
    final Future<void> overdueLoad = sameOverdueQuery
        ? ref.read(todayOverdueChoresProvider.notifier).refresh()
        : ref
              .read(todayOverdueChoresProvider.notifier)
              .loadQuery(overdueRequest, actorMemberId: actorMemberId);
    final List<Future<void>> loads = <Future<void>>[overdueLoad];
    if (completionWasProcessed) {
      final ChoreListRequest primaryRequest = ChoreListRequest.tryCreate(
        householdId: householdId,
        view: _selectedView,
        assigneeMemberId: assigneeMemberId,
      )!;
      final TodayChoresState primaryState = ref.read(todayChoresProvider);
      final bool samePrimaryQuery =
          primaryState is TodayChoresReady &&
          primaryState.today.householdId == householdId &&
          primaryState.today.view == _selectedView &&
          primaryState.today.assigneeFilterMemberId == assigneeMemberId;
      loads.add(
        samePrimaryQuery
            ? ref.read(todayChoresProvider.notifier).refresh()
            : ref
                  .read(todayChoresProvider.notifier)
                  .loadQuery(primaryRequest, actorMemberId: actorMemberId),
      );
    }
    await Future.wait<void>(loads);
  }

  TodayChoreCompletionSync? _completionSyncFrom(TodayChoresState state) {
    return state is TodayChoresReady ? state.completionSync : null;
  }

  Future<void> _preflightGuidedResume({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required bool force,
  }) async {
    _guidedResumePreflightPending = true;
    GuidedChoreSetupResumePlan? pendingPlan;
    try {
      pendingPlan = await ref
          .read(guidedChoreSetupResumeStoreProvider)
          .read(
            expectedHouseholdId: householdId,
            expectedAssigneeMemberId: actorMemberId,
          );
    } on Object {
      pendingPlan = null;
    }
    if (!mounted) {
      return;
    }
    _guidedResumePreflightPending = false;
    if (pendingPlan != null) {
      context.go(AppRoutes.guidedChoreSetup);
      return;
    }
    _guidedResumePreflightComplete = true;
    _loadToday(force: force);
  }

  void _refreshCalendar() {
    final activeHousehold = ref.read(authLifecycleProvider).activeHousehold;
    final HouseholdId? householdId = activeHousehold?.householdId;
    final HouseholdMemberId? actorMemberId = activeHousehold?.memberId;
    if (!mounted || householdId == null || actorMemberId == null) {
      return;
    }
    unawaited(
      ref
          .read(todayCalendarProvider.notifier)
          .load(
            TodayCalendarRequest(
              householdId: householdId,
              participantMemberId: _meOnly ? actorMemberId : null,
            ),
          ),
    );
  }

  void _reconnectChoreUpdates() {
    unawaited(
      Future.wait<void>(<Future<void>>[
        ref.read(todayChoresProvider.notifier).reconnect(),
        if (_selectedView == ChoreListView.today)
          ref.read(todayOverdueChoresProvider.notifier).reconnect(),
      ]),
    );
  }

  void _selectView(ChoreListView view) {
    if (view == _selectedView) {
      return;
    }
    setState(() => _selectedView = view);
    _loadToday(force: true);
  }

  void _selectMe(bool meOnly) {
    if (meOnly == _meOnly) {
      return;
    }
    setState(() => _meOnly = meOnly);
    _loadToday(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final TodayChoresState state = ref.watch(todayChoresProvider);
    final TodayChoresState overdueState = ref.watch(todayOverdueChoresProvider);
    final TodayCalendarState calendarState = ref.watch(todayCalendarProvider);
    final HouseholdActivationProgressState activationState = ref.watch(
      householdActivationProgressProvider,
    );
    final HouseholdWeeklyReportState weeklyReportState = ref.watch(
      householdWeeklyReportProvider,
    );
    final bool calendarPending =
        calendarState is TodayCalendarLoading ||
        calendarState is TodayCalendarReady && calendarState.refreshing;
    final bool actionPending =
        state is TodayChoresReady &&
            (state.pendingOccurrenceId != null ||
                state.completionSync?.kind ==
                    TodayChoreCompletionSyncKind.syncing ||
                state.refreshing ||
                state.loadingMore) ||
        _reassignmentRosterBusy ||
        _selectedView == ChoreListView.today &&
            overdueState is TodayChoresReady &&
            (overdueState.pendingOccurrenceId != null ||
                overdueState.completionSync?.kind ==
                    TodayChoreCompletionSyncKind.syncing ||
                overdueState.refreshing ||
                overdueState.loadingMore) ||
        _selectedView == ChoreListView.today && calendarPending;
    final bool compactActions =
        MediaQuery.sizeOf(context).width < AppBreakpoints.medium;

    return AppResponsiveScaffold(
      key: Key(widget._isChoresHub ? 'chores.screen' : 'today.screen'),
      allowPrimaryDestinationReselection: widget._isChoresHub,
      selectedPrimaryDestination: AppPrimaryDestination.today,
      onPrimaryDestinationSelected: (AppPrimaryDestination destination) =>
          context.go(AppRoutes.primaryLocation(destination)),
      title: widget._isChoresHub
          ? localizations.choresNavigationLabel
          : localizations.todayTitle,
      actions: <Widget>[
        const NotificationAppShellAction(buttonKey: Key('today.notifications')),
        if (compactActions)
          PopupMenuButton<_TodayCompactAction>(
            key: const Key('today.more'),
            tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
            onSelected: (_TodayCompactAction action) {
              switch (action) {
                case _TodayCompactAction.chores:
                  _openChoresHub();
                  break;
                case _TodayCompactAction.weeklyReport:
                  _openWeeklyReport();
                  break;
                case _TodayCompactAction.trash:
                  unawaited(context.push<void>(AppRoutes.choreTrash));
                  break;
                case _TodayCompactAction.refresh:
                  if (!actionPending) {
                    _loadToday(force: true);
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<_TodayCompactAction>>[
                  if (!widget._isChoresHub)
                    PopupMenuItem<_TodayCompactAction>(
                      key: const Key('today.chores'),
                      value: _TodayCompactAction.chores,
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.checklist_outlined),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              localizations.choresNavigationLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!widget._isChoresHub)
                    PopupMenuItem<_TodayCompactAction>(
                      key: const Key('today.weeklyReport'),
                      value: _TodayCompactAction.weeklyReport,
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.insights_outlined),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              localizations.weeklyReportOpenAction,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem<_TodayCompactAction>(
                    key: const Key('today.trash'),
                    value: _TodayCompactAction.trash,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline),
                      title: Text(localizations.choreTrashOpenAction),
                    ),
                  ),
                  PopupMenuItem<_TodayCompactAction>(
                    key: const Key('today.refresh'),
                    value: _TodayCompactAction.refresh,
                    enabled: !actionPending,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.refresh),
                      title: Text(localizations.retryAction),
                    ),
                  ),
                ],
          )
        else ...<Widget>[
          if (!widget._isChoresHub)
            IconButton(
              key: const Key('today.chores'),
              onPressed: _openChoresHub,
              tooltip: localizations.choresNavigationLabel,
              icon: const Icon(Icons.checklist_outlined),
            ),
          if (!widget._isChoresHub)
            IconButton(
              key: const Key('today.weeklyReport'),
              onPressed: _openWeeklyReport,
              tooltip: localizations.weeklyReportOpenAction,
              icon: const Icon(Icons.insights_outlined),
            ),
          IconButton(
            key: const Key('today.trash'),
            onPressed: () =>
                unawaited(context.push<void>(AppRoutes.choreTrash)),
            tooltip: localizations.choreTrashOpenAction,
            icon: const Icon(Icons.delete_outline),
          ),
          IconButton(
            key: const Key('today.refresh'),
            onPressed: actionPending ? null : () => _loadToday(force: true),
            tooltip: localizations.retryAction,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ],
      body: _body(
        localizations,
        state,
        overdueState,
        calendarState,
        activationState,
        weeklyReportState,
      ),
    );
  }

  Widget _body(
    AppLocalizations localizations,
    TodayChoresState state,
    TodayChoresState overdueState,
    TodayCalendarState calendarState,
    HouseholdActivationProgressState activationState,
    HouseholdWeeklyReportState weeklyReportState,
  ) {
    return switch (state) {
      TodayChoresInitial() || TodayChoresLoading()
          when _selectedView == ChoreListView.today &&
              _hasReadyTodaySource(overdueState, calendarState) =>
        _partialTodayWithoutPrimary(
          localizations,
          overdueState,
          calendarState,
          activationState,
          weeklyReportState: weeklyReportState,
          choresLoading: true,
        ),
      TodayChoresInitial() || TodayChoresLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('today.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(localizations.todayLoadingLabel, textAlign: TextAlign.center),
          ],
        ),
      ),
      TodayChoresLoadFailed(:final failure)
          when _selectedView == ChoreListView.today &&
              _hasReadyTodaySource(overdueState, calendarState) =>
        _partialTodayWithoutPrimary(
          localizations,
          overdueState,
          calendarState,
          activationState,
          weeklyReportState: weeklyReportState,
          choresFailure: failure,
        ),
      TodayChoresLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('today.error'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.event_busy_outlined, size: AppIconSize.status),
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
              key: const Key('today.retry'),
              onPressed: () => _loadToday(force: true),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      TodayChoresReady(
        :final today,
        :final actionFailure,
        :final refreshing,
        :final refreshFailure,
        :final cacheMetadata,
        :final completionSync,
      )
          when _isTrueEmpty(today, overdueState, calendarState) =>
        _empty(
          localizations,
          today,
          actionFailure: actionFailure,
          refreshing: refreshing,
          refreshFailure: refreshFailure,
          cacheMetadata: cacheMetadata,
          completionSync: _mergedCompletionSync(completionSync, overdueState),
          calendarState: calendarState,
          activationState: activationState,
          weeklyReportState: weeklyReportState,
        ),
      TodayChoresReady(
        :final today,
        :final pendingOccurrenceId,
        :final actionFailure,
        :final refreshing,
        :final refreshFailure,
        :final loadingMore,
        :final loadMoreFailure,
        :final cacheMetadata,
        :final completionSync,
      ) =>
        _list(
          localizations,
          today,
          pendingOccurrenceId: pendingOccurrenceId,
          actionFailure: actionFailure,
          refreshing: refreshing,
          refreshFailure: refreshFailure,
          loadingMore: loadingMore,
          loadMoreFailure: loadMoreFailure,
          cacheMetadata: cacheMetadata,
          completionSync: _mergedCompletionSync(completionSync, overdueState),
          calendarState: calendarState,
          overdueState: overdueState,
          activationState: activationState,
          weeklyReportState: weeklyReportState,
        ),
    };
  }

  TodayChoreCompletionSync? _mergedCompletionSync(
    TodayChoreCompletionSync? primary,
    TodayChoresState overdueState,
  ) {
    final TodayChoreCompletionSync? overdue = overdueState is TodayChoresReady
        ? overdueState.completionSync
        : null;
    if (primary?.hasStoredIntent ?? false) {
      return primary;
    }
    if (overdue?.hasStoredIntent ?? false) {
      return overdue;
    }
    return primary ?? overdue;
  }

  bool _hasReadyTodaySource(
    TodayChoresState overdueState,
    TodayCalendarState calendarState,
  ) {
    return overdueState is TodayChoresReady ||
        calendarState is TodayCalendarReady;
  }

  bool _choreStateBusy(TodayChoresState state) {
    return state is TodayChoresInitial ||
        state is TodayChoresLoading ||
        state is TodayChoresReady &&
            (state.pendingOccurrenceId != null ||
                state.refreshing ||
                state.loadingMore);
  }

  bool _calendarStateBusy(TodayCalendarState state) {
    return state is TodayCalendarInitial ||
        state is TodayCalendarLoading ||
        state is TodayCalendarReady &&
            (state.refreshing || state.isReadOnlyCache);
  }

  bool _isTrueEmpty(
    TodayChores primaryToday,
    TodayChoresState overdueState,
    TodayCalendarState calendarState,
  ) {
    if (primaryToday.occurrences.isNotEmpty) {
      return false;
    }
    if (primaryToday.view != ChoreListView.today) {
      return true;
    }
    return switch ((overdueState, calendarState)) {
      (
        TodayChoresReady(today: final overdue),
        TodayCalendarReady(:final snapshot),
      ) =>
        TodaySnapshot.tryCreate(
                  chores: primaryToday,
                  overdue: overdue,
                  calendar: snapshot,
                ) !=
                null &&
            overdue.occurrences.isEmpty &&
            snapshot.events.isEmpty,
      _ => false,
    };
  }

  Widget _partialTodayWithoutPrimary(
    AppLocalizations localizations,
    TodayChoresState overdueState,
    TodayCalendarState calendarState,
    HouseholdActivationProgressState activationState, {
    required HouseholdWeeklyReportState weeklyReportState,
    bool choresLoading = false,
    ChoreFailure? choresFailure,
  }) {
    final TodayChoreCompletionSync? completionSync = _mergedCompletionSync(
      null,
      overdueState,
    );
    final ChoreLocalDate localDate = switch ((overdueState, calendarState)) {
      (_, TodayCalendarReady(:final snapshot)) => ChoreLocalDate.tryParse(
        snapshot.localDate.value,
      )!,
      (TodayChoresReady(:final today), _) => today.localDate,
      _ => throw StateError('A partial Today view requires ready content.'),
    };
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return ScrollableStatusLayout(
      maxWidth: AppLayoutTokens.pageContentMaxWidth,
      child: Column(
        key: const Key('today.partial.calendarOnly'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ..._partialControls(localizations),
          if (_choreSyncDisconnected(
            ref.read(todayChoresProvider),
            overdueState,
          )) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _choreLiveDisconnectedBanner(localizations),
          ],
          if (completionSync != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _completionSyncBanner(localizations, completionSync),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            localizations.choreListBoundaryDate(
              material.formatFullDate(localDate.toDateTime()),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _overdueSection(
            localizations,
            overdueState,
            primaryToday: null,
            calendarState: calendarState,
            completionSync: completionSync,
          ),
          const SizedBox(height: AppSpacing.lg),
          TodayCalendarSection(
            state: calendarState,
            chores: null,
            onRetry: _refreshCalendar,
            onReconnect: () =>
                unawaited(ref.read(todayCalendarProvider.notifier).reconnect()),
            onOpenCalendar: () => context.go(AppRoutes.calendar),
            onOpenEvent: (CalendarEventOccurrenceId occurrenceId) =>
                context.go(AppRoutes.calendarEventLocation(occurrenceId)),
            sectionKind: TodayCalendarSectionKind.nowAndNext,
            hideWhenEmpty: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              choresLoading
                  ? localizations.todayChoresSectionTitle
                  : localizations.todayChoresUnavailableTitle,
              key: const Key('today.chores.heading'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (choresLoading)
            Semantics(
              liveRegion: true,
              label: localizations.todayLoadingLabel,
              child: const LinearProgressIndicator(
                key: Key('today.chores.loading'),
              ),
            )
          else if (choresFailure != null)
            _choreSourceFailure(localizations, choresFailure),
          const SizedBox(height: AppSpacing.lg),
          TodayCalendarSection(
            state: calendarState,
            chores: null,
            onRetry: _refreshCalendar,
            onReconnect: () =>
                unawaited(ref.read(todayCalendarProvider.notifier).reconnect()),
            onOpenCalendar: () => context.go(AppRoutes.calendar),
            onOpenEvent: (CalendarEventOccurrenceId occurrenceId) =>
                context.go(AppRoutes.calendarEventLocation(occurrenceId)),
            sectionKind: TodayCalendarSectionKind.remaining,
            showSourceStatus: false,
            showOpenCalendar: false,
            hideWhenEmpty: true,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('today.createChore'),
            onPressed: () => _openCreate(localDate),
            icon: const Icon(Icons.add_task),
            label: Text(localizations.todayCreateAnotherChoreAction),
          ),
          const SizedBox(height: AppSpacing.lg),
          _activationCard(
            activationState,
            localDate: localDate,
            readOnly: _partialTodayReadOnly(overdueState, calendarState),
          ),
          const SizedBox(height: AppSpacing.md),
          _weeklyReportCard(weeklyReportState),
        ],
      ),
    );
  }

  List<Widget> _partialControls(AppLocalizations localizations) {
    final bool enabled =
        !_choreStateBusy(ref.read(todayChoresProvider)) &&
        !_choreStateBusy(ref.read(todayOverdueChoresProvider)) &&
        !_calendarStateBusy(ref.read(todayCalendarProvider));
    return <Widget>[
      Semantics(
        container: true,
        label: localizations.choreListViewFilterLabel,
        child: Wrap(
          key: const Key('today.viewFilters'),
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _availableViews
              .map(
                (ChoreListView view) => ChoiceChip(
                  key: Key('today.view.${view.wireName}'),
                  selected: _selectedView == view,
                  onSelected: enabled
                      ? (bool selected) {
                          if (selected) {
                            _selectView(view);
                          }
                        }
                      : null,
                  label: Text(_viewLabel(localizations, view)),
                ),
              )
              .toList(growable: false),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Semantics(
        container: true,
        label: localizations.choreListAssigneeFilterLabel,
        child: Wrap(
          key: const Key('today.assigneeFilters'),
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            ChoiceChip(
              key: const Key('today.assignee.everyone'),
              selected: !_meOnly,
              onSelected: enabled
                  ? (bool selected) {
                      if (selected) {
                        _selectMe(false);
                      }
                    }
                  : null,
              label: Text(localizations.choreListEveryoneFilter),
            ),
            ChoiceChip(
              key: const Key('today.assignee.me'),
              selected: _meOnly,
              onSelected: enabled
                  ? (bool selected) {
                      if (selected) {
                        _selectMe(true);
                      }
                    }
                  : null,
              label: Text(localizations.choreListMeFilter),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _choreSourceFailure(
    AppLocalizations localizations,
    ChoreFailure failure, {
    String keyPrefix = 'today.chores',
    VoidCallback? onRetry,
  }) {
    return Container(
      key: Key('$keyPrefix.error'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(choreFailureMessage(localizations, failure)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(localizations.todayPartialFailureHint),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: Key('$keyPrefix.retry'),
            onPressed: onRetry ?? () => _loadToday(force: true),
            icon: const Icon(Icons.refresh),
            label: Text(localizations.retryAction),
          ),
        ],
      ),
    );
  }

  Widget _empty(
    AppLocalizations localizations,
    TodayChores today, {
    required ChoreFailure? actionFailure,
    required bool refreshing,
    required ChoreFailure? refreshFailure,
    required ReadCacheMetadata? cacheMetadata,
    required TodayChoreCompletionSync? completionSync,
    required TodayCalendarState calendarState,
    required HouseholdActivationProgressState activationState,
    required HouseholdWeeklyReportState weeklyReportState,
  }) {
    return ScrollableStatusLayout(
      child: Column(
        key: const Key('today.empty'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ..._readyControls(
            localizations,
            today,
            refreshing: refreshing,
            refreshFailure: refreshFailure,
            cacheMetadata: cacheMetadata,
          ),
          if (completionSync != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _completionSyncBanner(localizations, completionSync),
          ],
          TodayCalendarSection(
            state: calendarState,
            chores: today,
            onRetry: _refreshCalendar,
            onReconnect: () =>
                unawaited(ref.read(todayCalendarProvider.notifier).reconnect()),
            onOpenCalendar: () => context.go(AppRoutes.calendar),
            onOpenEvent: (CalendarEventOccurrenceId occurrenceId) =>
                context.go(AppRoutes.calendarEventLocation(occurrenceId)),
            sectionKind: TodayCalendarSectionKind.nowAndNext,
            hideWhenEmpty: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          ExcludeSemantics(
            child: Icon(
              Icons.today_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: AppIconSize.status,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              _emptyTitle(localizations, today.view),
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _emptyBody(localizations, today.view),
            textAlign: TextAlign.center,
          ),
          if (actionFailure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _actionFailureBanner(localizations, actionFailure),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('today.createChore'),
            onPressed:
                cacheMetadata == null &&
                    !(completionSync?.hasStoredIntent ?? false)
                ? () => _openCreate(today.localDate)
                : null,
            icon: const Icon(Icons.add_task),
            label: Text(localizations.todayCreateChoreAction),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            key: const Key('today.invite'),
            onPressed:
                cacheMetadata == null &&
                    !(completionSync?.hasStoredIntent ?? false)
                ? _openInvite
                : null,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(localizations.todayInviteAction),
          ),
          if (today.view == ChoreListView.today) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _activationCard(
              activationState,
              localDate: today.localDate,
              readOnly:
                  cacheMetadata != null ||
                  (completionSync?.hasStoredIntent ?? false),
            ),
            const SizedBox(height: AppSpacing.md),
            _weeklyReportCard(weeklyReportState),
          ],
        ],
      ),
    );
  }

  Widget _list(
    AppLocalizations localizations,
    TodayChores today, {
    required ChoreOccurrenceId? pendingOccurrenceId,
    required ChoreFailure? actionFailure,
    required bool refreshing,
    required ChoreFailure? refreshFailure,
    required bool loadingMore,
    required ChoreFailure? loadMoreFailure,
    required TodayCalendarState calendarState,
    required TodayChoresState overdueState,
    required ReadCacheMetadata? cacheMetadata,
    required TodayChoreCompletionSync? completionSync,
    required HouseholdActivationProgressState activationState,
    required HouseholdWeeklyReportState weeklyReportState,
  }) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final List<ChoreOccurrence> scheduled = today.occurrences
        .where(
          (ChoreOccurrence occurrence) =>
              occurrence.status == ChoreOccurrenceStatus.scheduled,
        )
        .toList(growable: false);
    final List<ChoreOccurrence> completed = today.occurrences
        .where(
          (ChoreOccurrence occurrence) =>
              occurrence.status == ChoreOccurrenceStatus.completed,
        )
        .toList(growable: false);
    final TodayChores? matchingOverdue =
        overdueState is TodayChoresReady &&
            _matchesOverdueContext(overdueState.today, today, calendarState)
        ? overdueState.today
        : null;
    final int visibleChoreCount =
        today.occurrences.length +
        (today.view == ChoreListView.today
            ? matchingOverdue?.occurrences.length ?? 0
            : 0);
    return ScrollableStatusLayout(
      maxWidth: AppLayoutTokens.pageContentMaxWidth,
      child: Column(
        key: const Key('today.list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ..._readyControls(
            localizations,
            today,
            refreshing: refreshing,
            refreshFailure: refreshFailure,
            cacheMetadata: cacheMetadata,
          ),
          if (completionSync != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _completionSyncBanner(localizations, completionSync),
          ],
          const SizedBox(height: AppSpacing.lg),
          Semantics(
            header: true,
            child: Text(
              _viewLabel(localizations, today.view),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.choreListBoundaryDate(
              material.formatFullDate(today.localDate.toDateTime()),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(localizations.choreListCount(visibleChoreCount)),
          if (actionFailure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            _actionFailureBanner(localizations, actionFailure),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (today.view == ChoreListView.today) ...<Widget>[
            _overdueSection(
              localizations,
              overdueState,
              primaryToday: today,
              calendarState: calendarState,
              completionSync: completionSync,
            ),
            const SizedBox(height: AppSpacing.lg),
            TodayCalendarSection(
              state: calendarState,
              chores: today,
              onRetry: _refreshCalendar,
              onReconnect: () => unawaited(
                ref.read(todayCalendarProvider.notifier).reconnect(),
              ),
              onOpenCalendar: () => context.go(AppRoutes.calendar),
              onOpenEvent: (CalendarEventOccurrenceId occurrenceId) =>
                  context.go(AppRoutes.calendarEventLocation(occurrenceId)),
              sectionKind: TodayCalendarSectionKind.nowAndNext,
              hideWhenEmpty: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (scheduled.isNotEmpty) ...<Widget>[
              Semantics(
                header: true,
                child: Text(
                  localizations.todayChoresSectionTitle,
                  key: const Key('today.chores.heading'),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._occurrenceCards(
                localizations,
                today,
                scheduled,
                pendingOccurrenceId: pendingOccurrenceId,
                readOnly: cacheMetadata != null,
                completionSync: completionSync,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            TodayCalendarSection(
              state: calendarState,
              chores: today,
              onRetry: _refreshCalendar,
              onReconnect: () => unawaited(
                ref.read(todayCalendarProvider.notifier).reconnect(),
              ),
              onOpenCalendar: () => context.go(AppRoutes.calendar),
              onOpenEvent: (CalendarEventOccurrenceId occurrenceId) =>
                  context.go(AppRoutes.calendarEventLocation(occurrenceId)),
              sectionKind: TodayCalendarSectionKind.remaining,
              showSourceStatus: false,
              showOpenCalendar: false,
              hideWhenEmpty: true,
            ),
            if (completed.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              _completedSection(
                localizations,
                today,
                completed,
                pendingOccurrenceId: pendingOccurrenceId,
                readOnly: cacheMetadata != null,
                completionSync: completionSync,
              ),
            ],
          ] else ...<Widget>[
            if (today.occurrences.isEmpty)
              Text(
                _emptyBody(localizations, today.view),
                key: const Key('today.chores.empty'),
              ),
            ..._occurrenceCards(
              localizations,
              today,
              today.occurrences,
              pendingOccurrenceId: pendingOccurrenceId,
              readOnly: cacheMetadata != null,
              completionSync: completionSync,
            ),
          ],
          if (loadingMore) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              liveRegion: true,
              label: localizations.choreListLoadingMore,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ] else if (loadMoreFailure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _loadMoreFailure(localizations),
          ] else if (today.hasMore) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('today.loadMore'),
              onPressed:
                  cacheMetadata == null &&
                      !(completionSync?.hasStoredIntent ?? false)
                  ? () => unawaited(
                      ref.read(todayChoresProvider.notifier).loadMore(),
                    )
                  : null,
              icon: const Icon(Icons.expand_more),
              label: Text(localizations.choreListLoadMoreAction),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('today.createChore'),
            onPressed:
                cacheMetadata == null &&
                    !(completionSync?.hasStoredIntent ?? false)
                ? () => _openCreate(today.localDate)
                : null,
            icon: const Icon(Icons.add_task),
            label: Text(localizations.todayCreateAnotherChoreAction),
          ),
          if (today.view == ChoreListView.today) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            _activationCard(
              activationState,
              localDate: today.localDate,
              readOnly:
                  cacheMetadata != null ||
                  (completionSync?.hasStoredIntent ?? false),
            ),
            const SizedBox(height: AppSpacing.md),
            _weeklyReportCard(weeklyReportState),
          ],
        ],
      ),
    );
  }

  List<Widget> _occurrenceCards(
    AppLocalizations localizations,
    TodayChores today,
    List<ChoreOccurrence> occurrences, {
    required ChoreOccurrenceId? pendingOccurrenceId,
    required bool readOnly,
    TodayChoreCompletionSync? completionSync,
    _TodayChoreSource source = _TodayChoreSource.primary,
  }) {
    return occurrences
        .map(
          (ChoreOccurrence occurrence) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _occurrenceCard(
              localizations,
              today.householdId,
              today.localDate,
              occurrence,
              pendingOccurrenceId: pendingOccurrenceId,
              readOnly: readOnly,
              completionSync: completionSync,
              source: source,
            ),
          ),
        )
        .toList(growable: false);
  }

  Widget _completedSection(
    AppLocalizations localizations,
    TodayChores today,
    List<ChoreOccurrence> completed, {
    required ChoreOccurrenceId? pendingOccurrenceId,
    required bool readOnly,
    required TodayChoreCompletionSync? completionSync,
  }) {
    final String toggleHint = _completedExpanded
        ? localizations.todayCompletedCollapseAction
        : localizations.todayCompletedExpandAction;
    void toggleCompleted() {
      setState(() => _completedExpanded = !_completedExpanded);
    }

    return Column(
      key: const Key('today.completed.section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          key: const Key('today.completed.toggle.semantics'),
          container: true,
          button: true,
          expanded: _completedExpanded,
          label: localizations.todayCompletedSectionTitle,
          hint: toggleHint,
          onTap: toggleCompleted,
          child: ExcludeSemantics(
            child: Card(
              child: ListTile(
                key: const Key('today.completed.toggle'),
                onTap: toggleCompleted,
                title: Text(localizations.todayCompletedSectionTitle),
                subtitle: Text(localizations.choreListCount(completed.length)),
                trailing: Icon(
                  _completedExpanded ? Icons.expand_less : Icons.expand_more,
                ),
              ),
            ),
          ),
        ),
        if (_completedExpanded) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          ..._occurrenceCards(
            localizations,
            today,
            completed,
            pendingOccurrenceId: pendingOccurrenceId,
            readOnly: readOnly,
            completionSync: completionSync,
          ),
        ],
      ],
    );
  }

  Widget _overdueSection(
    AppLocalizations localizations,
    TodayChoresState state, {
    required TodayChores? primaryToday,
    required TodayCalendarState calendarState,
    required TodayChoreCompletionSync? completionSync,
  }) {
    if (state is TodayChoresInitial || state is TodayChoresLoading) {
      return Column(
        key: const Key('today.overdue.loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _overdueHeading(localizations, null),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            label: localizations.todayLoadingLabel,
            child: const LinearProgressIndicator(),
          ),
        ],
      );
    }
    if (state is TodayChoresLoadFailed) {
      return Column(
        key: const Key('today.overdue.failedSection'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _overdueHeading(localizations, null),
          const SizedBox(height: AppSpacing.sm),
          _choreSourceFailure(
            localizations,
            state.failure,
            keyPrefix: 'today.overdue',
            onRetry: _retryOverdue,
          ),
        ],
      );
    }
    final TodayChoresReady ready = state as TodayChoresReady;
    final TodayChores overdue = ready.today;
    if (!_matchesOverdueContext(overdue, primaryToday, calendarState)) {
      return Column(
        key: const Key('today.overdue.invalidSection'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _overdueHeading(localizations, null),
          const SizedBox(height: AppSpacing.sm),
          _choreSourceFailure(
            localizations,
            const ChoreFailure(ChoreFailureKind.invalidPayload),
            keyPrefix: 'today.overdue',
            onRetry: _retryOverdue,
          ),
        ],
      );
    }
    final bool hasStatus =
        ready.refreshing ||
        ready.refreshFailure != null ||
        ready.actionFailure != null ||
        ready.cacheMetadata != null ||
        ready.loadingMore ||
        ready.loadMoreFailure != null ||
        overdue.hasMore;
    if (overdue.occurrences.isEmpty && !hasStatus) {
      return const SizedBox.shrink();
    }
    final String? syncLabel = _syncLabel(
      ready.cacheMetadata?.validatedAt ?? overdue.generatedAt,
    );
    return Column(
      key: const Key('today.overdue.ready'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _overdueHeading(localizations, overdue.occurrences.length),
        if (ready.refreshing) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            label: localizations.choreListRefreshing,
            child: const LinearProgressIndicator(
              key: Key('today.overdue.refreshing'),
            ),
          ),
        ] else if (ready.cacheMetadata != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _overdueStaleBanner(
            localizations,
            syncLabel: syncLabel,
            offline: true,
          ),
        ] else if (ready.refreshFailure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _overdueStaleBanner(
            localizations,
            syncLabel: syncLabel,
            offline: false,
          ),
        ],
        if (ready.actionFailure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _actionFailureBanner(
            localizations,
            ready.actionFailure!,
            key: const Key('today.overdue.actionError'),
          ),
        ],
        if (overdue.occurrences.isNotEmpty)
          const SizedBox(height: AppSpacing.sm),
        ..._occurrenceCards(
          localizations,
          overdue,
          overdue.occurrences,
          pendingOccurrenceId: ready.pendingOccurrenceId,
          readOnly: ready.isReadOnlyCache,
          completionSync: completionSync,
          source: _TodayChoreSource.overdue,
        ),
        if (ready.loadingMore) ...<Widget>[
          Semantics(
            liveRegion: true,
            label: localizations.choreListLoadingMore,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ] else if (ready.loadMoreFailure != null) ...<Widget>[
          _loadMoreFailure(localizations, source: _TodayChoreSource.overdue),
        ] else if (overdue.hasMore) ...<Widget>[
          OutlinedButton.icon(
            key: const Key('today.overdue.loadMore'),
            onPressed:
                ready.isReadOnlyCache ||
                    (completionSync?.hasStoredIntent ?? false)
                ? null
                : () => unawaited(
                    ref.read(todayOverdueChoresProvider.notifier).loadMore(),
                  ),
            icon: const Icon(Icons.expand_more),
            label: Text(localizations.choreListLoadMoreAction),
          ),
        ],
      ],
    );
  }

  Widget _overdueHeading(AppLocalizations localizations, int? count) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              localizations.todayOverdueSectionTitle,
              key: const Key('today.overdue.heading'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        if (count != null) Text(localizations.choreListCount(count)),
      ],
    );
  }

  bool _matchesOverdueContext(
    TodayChores overdue,
    TodayChores? primaryToday,
    TodayCalendarState calendarState,
  ) {
    if (overdue.view != ChoreListView.overdue ||
        overdue.occurrences.any(
          (ChoreOccurrence occurrence) => !overdue.matches(occurrence),
        )) {
      return false;
    }
    if (primaryToday != null) {
      return overdue.householdId == primaryToday.householdId &&
          overdue.householdTimezone == primaryToday.householdTimezone &&
          overdue.localDate == primaryToday.localDate &&
          overdue.assigneeFilterMemberId == primaryToday.assigneeFilterMemberId;
    }
    if (calendarState is TodayCalendarReady) {
      final TodayCalendarSnapshot calendar = calendarState.snapshot;
      return overdue.householdId == calendar.householdId &&
          overdue.householdTimezone == calendar.householdTimeZone.value &&
          overdue.localDate.value == calendar.localDate.value &&
          overdue.assigneeFilterMemberId == calendar.participantMemberId;
    }
    return true;
  }

  Widget _overdueStaleBanner(
    AppLocalizations localizations, {
    required String? syncLabel,
    required bool offline,
  }) {
    return Container(
      key: Key(offline ? 'today.overdue.offlineCache' : 'today.overdue.stale'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              syncLabel == null
                  ? localizations.choreListStaleUnknown
                  : offline
                  ? localizations.choreListOfflineMessage(syncLabel)
                  : localizations.choreListStaleMessage(syncLabel),
            ),
          ),
          if (offline) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.choreListOfflineReadOnlyHint),
          ],
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: const Key('today.overdue.stale.retry'),
            onPressed: _retryOverdue,
            icon: Icon(offline ? Icons.cloud_sync_outlined : Icons.refresh),
            label: Text(localizations.retryAction),
          ),
        ],
      ),
    );
  }

  List<Widget> _readyControls(
    AppLocalizations localizations,
    TodayChores today, {
    required bool refreshing,
    required ChoreFailure? refreshFailure,
    required ReadCacheMetadata? cacheMetadata,
  }) {
    final TodayChoresState currentState = ref.read(todayChoresProvider);
    final bool enabled =
        currentState is TodayChoresReady &&
        currentState.pendingOccurrenceId == null &&
        !(currentState.completionSync?.hasStoredIntent ?? false) &&
        !currentState.refreshing &&
        !currentState.loadingMore &&
        !currentState.isReadOnlyCache &&
        !_reassignmentRosterBusy &&
        (today.view != ChoreListView.today ||
            !_choreStateBusy(ref.read(todayOverdueChoresProvider)) &&
                !_calendarStateBusy(ref.read(todayCalendarProvider)));
    final String? syncLabel = _syncLabel(
      cacheMetadata?.validatedAt ?? today.generatedAt,
    );
    final bool liveDisconnected = _choreSyncDisconnected(
      currentState,
      ref.read(todayOverdueChoresProvider),
    );
    return <Widget>[
      Semantics(
        container: true,
        label: localizations.choreListViewFilterLabel,
        child: Wrap(
          key: const Key('today.viewFilters'),
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _availableViews
              .map(
                (ChoreListView view) => ChoiceChip(
                  key: Key('today.view.${view.wireName}'),
                  selected: today.view == view,
                  onSelected: enabled
                      ? (bool selected) {
                          if (selected) {
                            _selectView(view);
                          }
                        }
                      : null,
                  label: Text(_viewLabel(localizations, view)),
                ),
              )
              .toList(growable: false),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      Semantics(
        container: true,
        label: localizations.choreListAssigneeFilterLabel,
        child: Wrap(
          key: const Key('today.assigneeFilters'),
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            ChoiceChip(
              key: const Key('today.assignee.everyone'),
              selected: today.assigneeFilterMemberId == null,
              onSelected: enabled
                  ? (bool selected) {
                      if (selected) {
                        _selectMe(false);
                      }
                    }
                  : null,
              label: Text(localizations.choreListEveryoneFilter),
            ),
            ChoiceChip(
              key: const Key('today.assignee.me'),
              selected: today.assigneeFilterMemberId != null,
              onSelected: enabled
                  ? (bool selected) {
                      if (selected) {
                        _selectMe(true);
                      }
                    }
                  : null,
              label: Text(localizations.choreListMeFilter),
            ),
          ],
        ),
      ),
      if (liveDisconnected) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        _choreLiveDisconnectedBanner(localizations),
      ],
      if (refreshing) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          label: localizations.choreListRefreshing,
          child: const LinearProgressIndicator(key: Key('today.refreshing')),
        ),
      ] else if (cacheMetadata != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Container(
          key: const Key('today.offlineCache'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: AppRadii.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                liveRegion: true,
                child: Text(
                  syncLabel == null
                      ? localizations.choreListStaleUnknown
                      : localizations.choreListOfflineMessage(syncLabel),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(localizations.choreListOfflineReadOnlyHint),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                key: const Key('today.offlineCache.retry'),
                onPressed: () => _loadToday(force: true),
                icon: const Icon(Icons.cloud_sync_outlined),
                label: Text(localizations.retryAction),
              ),
            ],
          ),
        ),
      ] else if (refreshFailure != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Container(
          key: const Key('today.stale'),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            borderRadius: AppRadii.medium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Semantics(
                liveRegion: true,
                child: Text(
                  syncLabel == null
                      ? localizations.choreListStaleUnknown
                      : localizations.choreListStaleMessage(syncLabel),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                key: const Key('today.stale.retry'),
                onPressed: () => _loadToday(force: true),
                icon: const Icon(Icons.refresh),
                label: Text(localizations.retryAction),
              ),
            ],
          ),
        ),
      ] else if (syncLabel != null) ...<Widget>[
        const SizedBox(height: AppSpacing.sm),
        Text(
          localizations.choreListLastSynced(syncLabel),
          key: const Key('today.lastSynced'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ];
  }

  bool _choreSyncDisconnected(
    TodayChoresState primary,
    TodayChoresState overdue,
  ) {
    if (primary is TodayChoresReady &&
        primary.syncStatus == ChoreSyncConnectionStatus.disconnected) {
      return true;
    }
    return _selectedView == ChoreListView.today &&
        overdue is TodayChoresReady &&
        overdue.syncStatus == ChoreSyncConnectionStatus.disconnected;
  }

  Widget _choreLiveDisconnectedBanner(AppLocalizations localizations) {
    final Color foreground = Theme.of(context).colorScheme.onTertiaryContainer;
    return Container(
      key: const Key('today.choreLive.disconnected'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.cloud_off_outlined, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    localizations.choreLiveDisconnectedMessage,
                    style: TextStyle(color: foreground),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: const Key('today.choreLive.reconnect'),
            onPressed: _reconnectChoreUpdates,
            icon: const Icon(Icons.sync),
            label: Text(localizations.choreReconnectAction),
          ),
        ],
      ),
    );
  }

  Widget _loadMoreFailure(
    AppLocalizations localizations, {
    _TodayChoreSource source = _TodayChoreSource.primary,
  }) {
    final bool overdue = source == _TodayChoreSource.overdue;
    return Container(
      key: Key(overdue ? 'today.overdue.loadMoreError' : 'today.loadMoreError'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              localizations.choreListLoadMoreFailed,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: Key(
              overdue ? 'today.overdue.loadMore.retry' : 'today.loadMore.retry',
            ),
            onPressed: () => unawaited(
              overdue
                  ? ref.read(todayOverdueChoresProvider.notifier).loadMore()
                  : ref.read(todayChoresProvider.notifier).loadMore(),
            ),
            icon: const Icon(Icons.refresh),
            label: Text(localizations.retryAction),
          ),
        ],
      ),
    );
  }

  String? _syncLabel(DateTime? generatedAt) {
    if (generatedAt == null) {
      return null;
    }
    final DateTime local = generatedAt.toLocal();
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return '${material.formatShortDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  String _viewLabel(AppLocalizations localizations, ChoreListView view) {
    return switch (view) {
      ChoreListView.today => localizations.choreListTodayFilter,
      ChoreListView.upcoming => localizations.choreListUpcomingFilter,
      ChoreListView.overdue => localizations.choreListOverdueFilter,
      ChoreListView.completed => localizations.choreListCompletedFilter,
    };
  }

  String _emptyTitle(AppLocalizations localizations, ChoreListView view) {
    return switch (view) {
      ChoreListView.today => localizations.todayEmptyTitle,
      ChoreListView.upcoming => localizations.choreListUpcomingEmptyTitle,
      ChoreListView.overdue => localizations.choreListOverdueEmptyTitle,
      ChoreListView.completed => localizations.choreListCompletedEmptyTitle,
    };
  }

  String _emptyBody(AppLocalizations localizations, ChoreListView view) {
    return switch (view) {
      ChoreListView.today => localizations.todayEmptyBody,
      ChoreListView.upcoming => localizations.choreListUpcomingEmptyBody,
      ChoreListView.overdue => localizations.choreListOverdueEmptyBody,
      ChoreListView.completed => localizations.choreListCompletedEmptyBody,
    };
  }

  Widget _completionSyncBanner(
    AppLocalizations localizations,
    TodayChoreCompletionSync sync,
  ) {
    final bool error = switch (sync.kind) {
      TodayChoreCompletionSyncKind.needsAttention ||
      TodayChoreCompletionSyncKind.discarded ||
      TodayChoreCompletionSyncKind.expired ||
      TodayChoreCompletionSyncKind.queueUnavailable ||
      TodayChoreCompletionSyncKind.queueOccupied => true,
      TodayChoreCompletionSyncKind.queued ||
      TodayChoreCompletionSyncKind.syncing ||
      TodayChoreCompletionSyncKind.paused ||
      TodayChoreCompletionSyncKind.reconciled => false,
    };
    final Color background = error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.tertiaryContainer;
    final Color foreground = error
        ? Theme.of(context).colorScheme.onErrorContainer
        : Theme.of(context).colorScheme.onTertiaryContainer;
    final String message = switch (sync.kind) {
      TodayChoreCompletionSyncKind.queued =>
        localizations.choreCompletionQueuedMessage,
      TodayChoreCompletionSyncKind.syncing =>
        localizations.choreCompletionSyncingMessage,
      TodayChoreCompletionSyncKind.paused =>
        localizations.choreCompletionPausedMessage,
      TodayChoreCompletionSyncKind.reconciled =>
        localizations.choreCompletionReconciledMessage,
      TodayChoreCompletionSyncKind.needsAttention =>
        localizations.choreCompletionNeedsAttentionMessage,
      TodayChoreCompletionSyncKind.discarded =>
        localizations.choreCompletionDiscardedMessage,
      TodayChoreCompletionSyncKind.expired =>
        localizations.choreCompletionExpiredMessage,
      TodayChoreCompletionSyncKind.queueUnavailable =>
        localizations.choreCompletionQueueUnavailableMessage,
      TodayChoreCompletionSyncKind.queueOccupied =>
        localizations.choreCompletionQueueOccupiedMessage,
    };
    return Container(
      key: Key('today.completionSync.${sync.kind.name}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                sync.kind == TodayChoreCompletionSyncKind.syncing
                    ? Icons.cloud_sync_outlined
                    : error
                    ? Icons.info_outline
                    : Icons.cloud_done_outlined,
                color: foreground,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(message, style: TextStyle(color: foreground)),
                ),
              ),
            ],
          ),
          if (sync.canDiscard) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const Key('today.completionSync.discard'),
              onPressed: () => unawaited(_discardCompletionOutbox()),
              icon: const Icon(Icons.delete_outline),
              label: Text(localizations.choreCompletionDiscardAction),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _discardCompletionOutbox() async {
    final bool cleared = await ref
        .read(todayChoresProvider.notifier)
        .discardCompletionOutbox();
    if (mounted && cleared) {
      _loadToday(force: true);
    }
  }

  Widget _actionFailureBanner(
    AppLocalizations localizations,
    ChoreFailure failure, {
    Key key = const Key('today.actionError'),
  }) {
    return Semantics(
      liveRegion: true,
      child: Container(
        key: key,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: AppRadii.medium,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                choreFailureMessage(localizations, failure),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _occurrenceCard(
    AppLocalizations localizations,
    HouseholdId householdId,
    ChoreLocalDate householdLocalDate,
    ChoreOccurrence occurrence, {
    required ChoreOccurrenceId? pendingOccurrenceId,
    required bool readOnly,
    required TodayChoreCompletionSync? completionSync,
    _TodayChoreSource source = _TodayChoreSource.primary,
  }) {
    final bool completed = occurrence.status == ChoreOccurrenceStatus.completed;
    final bool pending = pendingOccurrenceId == occurrence.id;
    final bool hasStoredIntent = completionSync?.hasStoredIntent ?? false;
    final bool queuedForThis =
        hasStoredIntent && completionSync?.occurrenceId == occurrence.id;
    final bool commandBusy =
        pendingOccurrenceId != null || _reassignmentRosterBusy;
    final bool completionDisabled =
        commandBusy ||
        hasStoredIntent ||
        readOnly &&
            (completed ||
                !occurrence.canSetCompletion ||
                !ref.read(choreCompletionOutboxProvider).isAvailable);
    final bool otherActionsDisabled =
        commandBusy || readOnly || hasStoredIntent;
    final bool canEditOccurrence =
        source == _TodayChoreSource.primary &&
        !completed &&
        (occurrence.recurrenceFrequency != null || occurrence.canManageOneTime);
    final String dueLabel = occurrence.dueLocalTime == null
        ? localizations.choreAllDayLabel
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay(
              hour: occurrence.dueLocalTime!.hour,
              minute: occurrence.dueLocalTime!.minute,
            ),
          );
    final String dueDateLabel = MaterialLocalizations.of(
      context,
    ).formatShortDate(occurrence.dueLocalDate.toDateTime());
    return Semantics(
      container: true,
      hint: localizations.choreDetailsAction,
      child: Card(
        key: Key('today.chore.${occurrence.id.value}'),
        child: ListTile(
          onTap: () => _openOccurrenceDetails(householdId, occurrence),
          leading: CircleAvatar(
            child: Icon(completed ? Icons.check : Icons.task_alt),
          ),
          title: Text(
            occurrence.title,
            style: completed
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                occurrence.dueLocalDate == householdLocalDate
                    ? localizations.todayChoreMetadata(
                        occurrence.assigneeDisplayName,
                        dueLabel,
                      )
                    : localizations.choreListMetadata(
                        occurrence.assigneeDisplayName,
                        dueDateLabel,
                        dueLabel,
                      ),
              ),
              Text(
                completed
                    ? localizations.choreCompletedStatus
                    : localizations.choreScheduledStatus,
              ),
              if (queuedForThis)
                Text(localizations.choreCompletionQueuedStatus),
              if (occurrence.recurrenceFrequency != null)
                Text(
                  _recurrenceLabel(
                    localizations,
                    occurrence.recurrenceFrequency!,
                  ),
                ),
              if (occurrence.description != null)
                Text(
                  occurrence.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: pending
              ? Semantics(
                  label: localizations.choreCompletionInProgress,
                  child: const SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: SizedBox.square(
                        dimension: AppSpacing.lg,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      key: Key('today.chore.toggle.${occurrence.id.value}'),
                      onPressed: completionDisabled
                          ? null
                          : () => _setCompleted(
                              householdId,
                              occurrence,
                              completed: !completed,
                              source: source,
                            ),
                      tooltip: completed
                          ? localizations.choreReopenAction
                          : localizations.choreMarkCompleteAction,
                      icon: Icon(
                        completed ? Icons.undo : Icons.check_circle_outline,
                      ),
                    ),
                    if (canEditOccurrence)
                      PopupMenuButton<_TodayOccurrenceAction>(
                        key: Key('today.chore.menu.${occurrence.id.value}'),
                        enabled: !otherActionsDisabled,
                        tooltip: localizations.choreOccurrenceMenuTooltip,
                        onSelected: (_TodayOccurrenceAction action) {
                          switch (action) {
                            case _TodayOccurrenceAction.editOneTime:
                              unawaited(
                                _editOneTimeChore(householdId, occurrence),
                              );
                            case _TodayOccurrenceAction.deleteOneTime:
                              unawaited(
                                _confirmDeleteOneTimeChore(
                                  householdId,
                                  occurrence,
                                ),
                              );
                            case _TodayOccurrenceAction.reschedule:
                              unawaited(
                                _rescheduleOccurrence(householdId, occurrence),
                              );
                            case _TodayOccurrenceAction.reassign:
                              unawaited(
                                _reassignOccurrence(householdId, occurrence),
                              );
                            case _TodayOccurrenceAction.skip:
                              unawaited(_confirmSkip(householdId, occurrence));
                            case _TodayOccurrenceAction.editSeries:
                              unawaited(
                                _editRepeatingSeries(
                                  householdId,
                                  householdLocalDate,
                                  occurrence,
                                ),
                              );
                            case _TodayOccurrenceAction
                                .editSeriesFromOccurrence:
                              unawaited(
                                _editRepeatingSeries(
                                  householdId,
                                  householdLocalDate,
                                  occurrence,
                                  fromOccurrence: true,
                                ),
                              );
                            case _TodayOccurrenceAction.cancelSeries:
                              unawaited(
                                _confirmCancelSeries(householdId, occurrence),
                              );
                            case _TodayOccurrenceAction
                                .cancelSeriesFromOccurrence:
                              unawaited(
                                _confirmCancelSeries(
                                  householdId,
                                  occurrence,
                                  fromOccurrence: true,
                                ),
                              );
                          }
                        },
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<_TodayOccurrenceAction>>[
                              if (occurrence.canManageOneTime) ...<
                                PopupMenuEntry<_TodayOccurrenceAction>
                              >[
                                PopupMenuItem<_TodayOccurrenceAction>(
                                  key: const Key('today.oneTime.edit.menuItem'),
                                  value: _TodayOccurrenceAction.editOneTime,
                                  child: Text(
                                    localizations.choreEditOneTimeAction,
                                  ),
                                ),
                                PopupMenuItem<_TodayOccurrenceAction>(
                                  key: const Key(
                                    'today.oneTime.delete.menuItem',
                                  ),
                                  value: _TodayOccurrenceAction.deleteOneTime,
                                  child: Text(
                                    localizations.choreDeleteOneTimeAction,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                              if (occurrence.recurrenceFrequency != null) ...<
                                PopupMenuEntry<_TodayOccurrenceAction>
                              >[
                                PopupMenuItem<_TodayOccurrenceAction>(
                                  key: const Key('today.reschedule.menuItem'),
                                  value: _TodayOccurrenceAction.reschedule,
                                  child: Text(
                                    localizations
                                        .choreRescheduleOccurrenceAction,
                                  ),
                                ),
                                PopupMenuItem<_TodayOccurrenceAction>(
                                  key: const Key('today.reassign.menuItem'),
                                  value: _TodayOccurrenceAction.reassign,
                                  child: Text(
                                    localizations.choreReassignOccurrenceAction,
                                  ),
                                ),
                                PopupMenuItem<_TodayOccurrenceAction>(
                                  key: const Key('today.skip.menuItem'),
                                  value: _TodayOccurrenceAction.skip,
                                  child: Text(
                                    localizations.choreSkipOccurrenceAction,
                                  ),
                                ),
                              ],
                              if (occurrence.canManageSeries) ...<
                                PopupMenuEntry<_TodayOccurrenceAction>
                              >[
                                const PopupMenuDivider(),
                                PopupMenuItem<_TodayOccurrenceAction>(
                                  key: const Key('today.series.edit.menuItem'),
                                  value: _TodayOccurrenceAction.editSeries,
                                  child: Text(
                                    localizations.choreEditSeriesAction,
                                  ),
                                ),
                                if (occurrence.dueLocalDate.value.compareTo(
                                      householdLocalDate.value,
                                    ) >
                                    0) ...<
                                  PopupMenuEntry<_TodayOccurrenceAction>
                                >[
                                  PopupMenuItem<_TodayOccurrenceAction>(
                                    key: const Key(
                                      'today.series.editFromOccurrence.menuItem',
                                    ),
                                    value: _TodayOccurrenceAction
                                        .editSeriesFromOccurrence,
                                    child: Text(
                                      localizations
                                          .choreEditSeriesFromOccurrenceAction,
                                    ),
                                  ),
                                  PopupMenuItem<_TodayOccurrenceAction>(
                                    key: const Key(
                                      'today.series.cancelFromOccurrence.menuItem',
                                    ),
                                    value: _TodayOccurrenceAction
                                        .cancelSeriesFromOccurrence,
                                    child: Text(
                                      localizations
                                          .choreCancelSeriesFromOccurrenceAction,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                                PopupMenuItem<_TodayOccurrenceAction>(
                                  key: const Key(
                                    'today.series.cancel.menuItem',
                                  ),
                                  value: _TodayOccurrenceAction.cancelSeries,
                                  child: Text(
                                    localizations.choreCancelSeriesAction,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                      ),
                  ],
                ),
          isThreeLine: true,
        ),
      ),
    );
  }

  void _openOccurrenceDetails(
    HouseholdId householdId,
    ChoreOccurrence occurrence,
  ) {
    unawaited(
      showAppModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext context) => ChoreOccurrenceHistorySheet(
          repository: ref.read(choreRepositoryProvider),
          householdId: householdId,
          occurrence: occurrence,
        ),
      ),
    );
  }

  void _openWeeklyReport() {
    final HouseholdId? householdId = ref
        .read(authLifecycleProvider)
        .activeHousehold
        ?.householdId;
    if (householdId == null) {
      return;
    }
    final HouseholdWeeklyReportState state = ref.read(
      householdWeeklyReportProvider,
    );
    final HouseholdWeeklyReport? initialReport =
        state is HouseholdWeeklyReportReady &&
            state.report.householdId == householdId
        ? state.report
        : null;
    unawaited(
      showAppModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (BuildContext context) => HouseholdWeeklyReportSheet(
          repository: ref.read(choreRepositoryProvider),
          householdId: householdId,
          initialReport: initialReport,
        ),
      ),
    );
  }

  void _setCompleted(
    HouseholdId householdId,
    ChoreOccurrence occurrence, {
    required bool completed,
    _TodayChoreSource source = _TodayChoreSource.primary,
  }) {
    final Future<void> mutation = source == _TodayChoreSource.overdue
        ? ref
              .read(todayOverdueChoresProvider.notifier)
              .setCompleted(
                householdId: householdId,
                occurrenceId: occurrence.id,
                completed: completed,
              )
        : ref
              .read(todayChoresProvider.notifier)
              .setCompleted(
                householdId: householdId,
                occurrenceId: occurrence.id,
                completed: completed,
              );
    unawaited(
      _refreshHouseholdInsightsAfterCompletion(
        mutation,
        householdId: householdId,
        completed: completed,
        source: source,
      ),
    );
  }

  Future<void> _refreshHouseholdInsightsAfterCompletion(
    Future<void> mutation, {
    required HouseholdId householdId,
    required bool completed,
    required _TodayChoreSource source,
  }) async {
    await mutation;
    if (!mounted) {
      return;
    }
    final TodayChoresState state = source == _TodayChoreSource.overdue
        ? ref.read(todayOverdueChoresProvider)
        : ref.read(todayChoresProvider);
    if (state is TodayChoresReady &&
        state.pendingOccurrenceId == null &&
        state.actionFailure == null &&
        !(state.completionSync?.hasStoredIntent ?? false)) {
      final HouseholdWeeklyReportRequest request =
          HouseholdWeeklyReportRequest.tryCreate(
            householdId: householdId,
            weekOffset: HouseholdWeeklyReportRequest.latestWeekOffset,
          )!;
      await Future.wait<void>(<Future<void>>[
        ref
            .read(householdWeeklyReportProvider.notifier)
            .load(request, preserveContent: true, force: true),
        if (completed)
          ref
              .read(householdActivationProgressProvider.notifier)
              .load(householdId, preserveContent: true),
      ]);
    }
  }

  Future<void> _rescheduleOccurrence(
    HouseholdId householdId,
    ChoreOccurrence occurrence,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    DateTime selectedDate = occurrence.dueLocalDate.toDateTime();
    TimeOfDay? selectedTime = occurrence.dueLocalTime == null
        ? null
        : TimeOfDay(
            hour: occurrence.dueLocalTime!.hour,
            minute: occurrence.dueLocalTime!.minute,
          );
    final _OccurrenceScheduleSelection?
    selection = await showAppDialog<_OccurrenceScheduleSelection>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext dialogContext, StateSetter setDialogState) {
          final MaterialLocalizations material = MaterialLocalizations.of(
            dialogContext,
          );
          final ChoreLocalDate dueLocalDate = ChoreLocalDate.fromDateTime(
            selectedDate,
          );
          final ChoreLocalTime? dueLocalTime = _choreLocalTime(selectedTime);
          final bool changed =
              dueLocalDate != occurrence.dueLocalDate ||
              dueLocalTime != occurrence.dueLocalTime;
          return Dialog(
            key: const Key('today.reschedule.dialog'),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        localizations.choreRescheduleDialogTitle,
                        style: Theme.of(dialogContext).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(localizations.choreRescheduleDialogBody),
                    const SizedBox(height: 16),
                    ListTile(
                      key: const Key('today.reschedule.date'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: Text(localizations.choreDueDateLabel),
                      subtitle: Text(material.formatFullDate(selectedDate)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final DateTime? nextDate = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100, 12, 31),
                        );
                        if (nextDate != null && dialogContext.mounted) {
                          setDialogState(() => selectedDate = nextDate);
                        }
                      },
                    ),
                    ListTile(
                      key: const Key('today.reschedule.time'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_outlined),
                      title: Text(localizations.choreDueTimeLabel),
                      subtitle: Text(
                        selectedTime == null
                            ? localizations.choreAllDayLabel
                            : material.formatTimeOfDay(selectedTime!),
                      ),
                      trailing: selectedTime == null
                          ? const Icon(Icons.add)
                          : IconButton(
                              key: const Key('today.reschedule.clearTime'),
                              onPressed: () =>
                                  setDialogState(() => selectedTime = null),
                              tooltip: localizations.choreClearTimeAction,
                              icon: const Icon(Icons.clear),
                            ),
                      onTap: () async {
                        final TimeOfDay? nextTime = await showTimePicker(
                          context: dialogContext,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (nextTime != null && dialogContext.mounted) {
                          setDialogState(() => selectedTime = nextTime);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      key: const Key('today.reschedule.cancel'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(localizations.memberCancelAction),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('today.reschedule.confirm'),
                      onPressed: changed
                          ? () => Navigator.of(dialogContext).pop(
                              _OccurrenceScheduleSelection(
                                dueLocalDate: dueLocalDate,
                                dueLocalTime: dueLocalTime,
                              ),
                            )
                          : null,
                      child: Text(localizations.choreRescheduleConfirmAction),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (selection == null || !mounted) {
      return;
    }
    await ref
        .read(todayChoresProvider.notifier)
        .rescheduleOccurrence(
          householdId: householdId,
          occurrenceId: occurrence.id,
          dueLocalDate: selection.dueLocalDate,
          dueLocalTime: selection.dueLocalTime,
        );
    if (!mounted) {
      return;
    }
    final TodayChoresState state = ref.read(todayChoresProvider);
    var rescheduled = false;
    if (state is TodayChoresReady &&
        state.actionFailure == null &&
        state.pendingOccurrenceId == null) {
      final DateTime selectedDate = selection.dueLocalDate.toDateTime();
      final ChoreOccurrence candidate = occurrence.rescheduled(
        dueLocalDate: selection.dueLocalDate,
        dueLocalTime: selection.dueLocalTime,
        dueAt: selection.dueLocalTime == null
            ? null
            : DateTime.utc(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                selection.dueLocalTime!.hour,
                selection.dueLocalTime!.minute,
              ),
      );
      final bool shouldRemain = state.today.matches(candidate);
      rescheduled = shouldRemain
          ? state.today.occurrences.any(
              (ChoreOccurrence item) =>
                  item.id == occurrence.id &&
                  item.dueLocalDate == selection.dueLocalDate &&
                  item.dueLocalTime == selection.dueLocalTime &&
                  item.version > occurrence.version,
            )
          : !state.today.occurrences.any(
              (ChoreOccurrence item) => item.id == occurrence.id,
            );
    }
    if (rescheduled) {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: const Key('today.reschedule.succeeded'),
          content: Text(localizations.choreRescheduleSucceeded),
        ),
      );
    }
  }

  Future<void> _reassignOccurrence(
    HouseholdId householdId,
    ChoreOccurrence occurrence,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (_reassignmentRosterBusy) {
      return;
    }
    final subscription = ref.listenManual<HouseholdMembersState>(
      householdMembersProvider,
      (_, _) {},
    );
    setState(() => _reassignmentRosterBusy = true);
    try {
      await ref.read(householdMembersProvider.notifier).load(householdId);
      if (!mounted) {
        return;
      }
      final HouseholdMembersState memberState = ref.read(
        householdMembersProvider,
      );
      if (memberState is! HouseholdMembersReady ||
          memberState.roster.householdId != householdId) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            key: const Key('today.reassign.rosterFailed'),
            content: Text(localizations.choreReassignRosterFailed),
          ),
        );
        return;
      }
      HouseholdMember? selectedMember;
      for (final HouseholdMember member in memberState.roster.members) {
        if (member.id == occurrence.assigneeMemberId) {
          selectedMember = member;
          break;
        }
      }
      final HouseholdMember? selection = await showAppDialog<HouseholdMember>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final bool changed =
                selectedMember != null &&
                selectedMember!.id != occurrence.assigneeMemberId;
            return Dialog(
              key: const Key('today.reassign.dialog'),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Semantics(
                        header: true,
                        child: Text(
                          localizations.choreReassignDialogTitle,
                          style: Theme.of(
                            dialogContext,
                          ).textTheme.headlineSmall,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(localizations.choreReassignDialogBody),
                      const SizedBox(height: 16),
                      ...memberState.roster.members.map((
                        HouseholdMember member,
                      ) {
                        final bool selected = selectedMember?.id == member.id;
                        return ListTile(
                          key: Key('today.reassign.member.${member.id.value}'),
                          contentPadding: EdgeInsets.zero,
                          selected: selected,
                          leading: Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(
                            member.isCurrentUser
                                ? localizations.choreAssigneeYou(
                                    member.displayName,
                                  )
                                : member.displayName,
                          ),
                          onTap: () =>
                              setDialogState(() => selectedMember = member),
                        );
                      }),
                      const SizedBox(height: 16),
                      TextButton(
                        key: const Key('today.reassign.cancel'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(localizations.memberCancelAction),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        key: const Key('today.reassign.confirm'),
                        onPressed: changed
                            ? () => Navigator.of(
                                dialogContext,
                              ).pop(selectedMember)
                            : null,
                        child: Text(localizations.choreReassignConfirmAction),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
      if (selection == null || !mounted) {
        return;
      }
      await ref
          .read(todayChoresProvider.notifier)
          .reassignOccurrence(
            householdId: householdId,
            occurrenceId: occurrence.id,
            assigneeMemberId: selection.id,
            assigneeDisplayName: selection.displayName,
          );
      if (!mounted) {
        return;
      }
      final TodayChoresState state = ref.read(todayChoresProvider);
      var reassigned = false;
      if (state is TodayChoresReady &&
          state.actionFailure == null &&
          state.pendingOccurrenceId == null) {
        final ChoreOccurrence candidate = occurrence.reassigned(
          assigneeMemberId: selection.id,
          assigneeDisplayName: selection.displayName,
        );
        final bool shouldRemain = state.today.matches(candidate);
        reassigned = shouldRemain
            ? state.today.occurrences.any(
                (ChoreOccurrence item) =>
                    item.id == occurrence.id &&
                    item.assigneeMemberId == selection.id &&
                    item.version > occurrence.version,
              )
            : !state.today.occurrences.any(
                (ChoreOccurrence item) => item.id == occurrence.id,
              );
      }
      if (reassigned) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            key: const Key('today.reassign.succeeded'),
            content: Text(localizations.choreReassignSucceeded),
          ),
        );
      }
    } finally {
      subscription.close();
      if (mounted) {
        setState(() => _reassignmentRosterBusy = false);
      }
    }
  }

  Future<void> _editOneTimeChore(
    HouseholdId householdId,
    ChoreOccurrence occurrence,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (_reassignmentRosterBusy || !occurrence.canManageOneTime) {
      return;
    }
    final subscription = ref.listenManual<HouseholdMembersState>(
      householdMembersProvider,
      (_, _) {},
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String titleInput = occurrence.title;
    String descriptionInput = occurrence.description ?? '';
    setState(() => _reassignmentRosterBusy = true);
    try {
      await ref.read(householdMembersProvider.notifier).load(householdId);
      if (!mounted) {
        return;
      }
      final HouseholdMembersState memberState = ref.read(
        householdMembersProvider,
      );
      if (memberState is! HouseholdMembersReady ||
          memberState.roster.householdId != householdId ||
          !memberState.roster.members.any(
            (HouseholdMember member) =>
                member.id == occurrence.assigneeMemberId,
          )) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            key: const Key('today.oneTime.edit.rosterFailed'),
            content: Text(localizations.choreReassignRosterFailed),
          ),
        );
        return;
      }
      HouseholdMemberId selectedAssigneeId = occurrence.assigneeMemberId;
      DateTime selectedDate = occurrence.dueLocalDate.toDateTime();
      TimeOfDay? selectedTime = occurrence.dueLocalTime == null
          ? null
          : TimeOfDay(
              hour: occurrence.dueLocalTime!.hour,
              minute: occurrence.dueLocalTime!.minute,
            );
      final _OneTimeUpdateSelection?
      selection = await showAppDialog<_OneTimeUpdateSelection>(
        context: context,
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final ChoreLocalDate dueLocalDate = ChoreLocalDate.fromDateTime(
              selectedDate,
            );
            final ChoreLocalTime? dueLocalTime = _choreLocalTime(selectedTime);
            final String normalizedTitle = titleInput.trim();
            final String normalizedDescription = descriptionInput.trim();
            final String? normalizedOptionalDescription =
                normalizedDescription.isEmpty ? null : normalizedDescription;
            final bool changed =
                normalizedTitle != occurrence.title ||
                normalizedOptionalDescription != occurrence.description ||
                selectedAssigneeId != occurrence.assigneeMemberId ||
                dueLocalDate != occurrence.dueLocalDate ||
                dueLocalTime != occurrence.dueLocalTime;
            final MaterialLocalizations material = MaterialLocalizations.of(
              dialogContext,
            );
            return Dialog(
              key: const Key('today.oneTime.edit.dialog'),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            localizations.choreEditOneTimeDialogTitle,
                            style: Theme.of(
                              dialogContext,
                            ).textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(localizations.choreEditOneTimeDialogBody),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('today.oneTime.edit.title'),
                          initialValue: titleInput,
                          maxLength: 160,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: localizations.choreTitleLabel,
                          ),
                          validator: (String? value) =>
                              value == null || value.trim().isEmpty
                              ? localizations.choreTitleValidation
                              : null,
                          onChanged: (String value) =>
                              setDialogState(() => titleInput = value),
                        ),
                        TextFormField(
                          key: const Key('today.oneTime.edit.description'),
                          initialValue: descriptionInput,
                          maxLength: 4000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: localizations.choreDescriptionLabel,
                          ),
                          onChanged: (String value) =>
                              setDialogState(() => descriptionInput = value),
                        ),
                        DropdownButtonFormField<HouseholdMemberId>(
                          key: const Key('today.oneTime.edit.assignee'),
                          initialValue: selectedAssigneeId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: localizations.choreAssigneeLabel,
                          ),
                          items: memberState.roster.members
                              .map(
                                (HouseholdMember member) =>
                                    DropdownMenuItem<HouseholdMemberId>(
                                      value: member.id,
                                      child: Text(
                                        member.isCurrentUser
                                            ? localizations.choreAssigneeYou(
                                                member.displayName,
                                              )
                                            : member.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (HouseholdMemberId? value) {
                            if (value != null) {
                              setDialogState(() => selectedAssigneeId = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          key: const Key('today.oneTime.edit.date'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.calendar_today_outlined),
                          title: Text(localizations.choreDueDateLabel),
                          subtitle: Text(material.formatFullDate(selectedDate)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final DateTime? nextDate = await showDatePicker(
                              context: dialogContext,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100, 12, 31),
                            );
                            if (nextDate != null && dialogContext.mounted) {
                              setDialogState(() => selectedDate = nextDate);
                            }
                          },
                        ),
                        ListTile(
                          key: const Key('today.oneTime.edit.time'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_outlined),
                          title: Text(localizations.choreDueTimeLabel),
                          subtitle: Text(
                            selectedTime == null
                                ? localizations.choreAllDayLabel
                                : material.formatTimeOfDay(selectedTime!),
                          ),
                          trailing: selectedTime == null
                              ? const Icon(Icons.add)
                              : IconButton(
                                  key: const Key(
                                    'today.oneTime.edit.clearTime',
                                  ),
                                  onPressed: () =>
                                      setDialogState(() => selectedTime = null),
                                  tooltip: localizations.choreClearTimeAction,
                                  icon: const Icon(Icons.clear),
                                ),
                          onTap: () async {
                            final TimeOfDay? nextTime = await showTimePicker(
                              context: dialogContext,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (nextTime != null && dialogContext.mounted) {
                              setDialogState(() => selectedTime = nextTime);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          key: const Key('today.oneTime.edit.cancel'),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(localizations.memberCancelAction),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const Key('today.oneTime.edit.confirm'),
                          onPressed: changed
                              ? () {
                                  if (!(formKey.currentState?.validate() ??
                                      false)) {
                                    return;
                                  }
                                  Navigator.of(dialogContext).pop(
                                    _OneTimeUpdateSelection(
                                      title: normalizedTitle,
                                      description: normalizedDescription,
                                      assigneeMemberId: selectedAssigneeId,
                                      dueLocalDate: dueLocalDate,
                                      dueLocalTime: dueLocalTime,
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            localizations.choreEditOneTimeConfirmAction,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      if (selection == null || !mounted) {
        return;
      }
      await ref
          .read(todayChoresProvider.notifier)
          .updateOneTimeChore(
            householdId: householdId,
            occurrenceId: occurrence.id,
            title: selection.title,
            description: selection.description,
            assigneeMemberId: selection.assigneeMemberId,
            dueLocalDate: selection.dueLocalDate,
            dueLocalTime: selection.dueLocalTime,
          );
      if (!mounted) {
        return;
      }
      final TodayChoresState state = ref.read(todayChoresProvider);
      var updated = false;
      if (state is TodayChoresReady &&
          state.actionFailure == null &&
          state.pendingOccurrenceId == null) {
        final DateTime selectedDate = selection.dueLocalDate.toDateTime();
        final ChoreOccurrence candidate = occurrence
            .rescheduled(
              dueLocalDate: selection.dueLocalDate,
              dueLocalTime: selection.dueLocalTime,
              dueAt: selection.dueLocalTime == null
                  ? null
                  : DateTime.utc(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selection.dueLocalTime!.hour,
                      selection.dueLocalTime!.minute,
                    ),
            )
            .reassigned(
              assigneeMemberId: selection.assigneeMemberId,
              assigneeDisplayName: occurrence.assigneeDisplayName,
            );
        final bool shouldRemain = state.today.matches(candidate);
        updated = shouldRemain
            ? state.today.occurrences.any(
                (ChoreOccurrence item) =>
                    item.id == occurrence.id &&
                    item.title == selection.title &&
                    item.description ==
                        (selection.description.isEmpty
                            ? null
                            : selection.description) &&
                    item.assigneeMemberId == selection.assigneeMemberId &&
                    item.dueLocalDate == selection.dueLocalDate &&
                    item.dueLocalTime == selection.dueLocalTime &&
                    item.seriesVersion > occurrence.seriesVersion &&
                    item.version > occurrence.version,
              )
            : !state.today.occurrences.any(
                (ChoreOccurrence item) => item.id == occurrence.id,
              );
      }
      if (updated) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            key: const Key('today.oneTime.edit.succeeded'),
            content: Text(localizations.choreEditOneTimeSucceeded),
          ),
        );
      }
    } finally {
      subscription.close();
      if (mounted) {
        setState(() => _reassignmentRosterBusy = false);
      }
    }
  }

  Future<void> _confirmDeleteOneTimeChore(
    HouseholdId householdId,
    ChoreOccurrence occurrence,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (!occurrence.canManageOneTime) {
      return;
    }
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => Dialog(
            key: const Key('today.oneTime.delete.dialog'),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        localizations.choreDeleteOneTimeDialogTitle,
                        style: Theme.of(dialogContext).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(localizations.choreDeleteOneTimeDialogBody),
                    const SizedBox(height: 24),
                    TextButton(
                      key: const Key('today.oneTime.delete.dismiss'),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(localizations.memberCancelAction),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('today.oneTime.delete.confirm'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(
                          dialogContext,
                        ).colorScheme.error,
                        foregroundColor: Theme.of(
                          dialogContext,
                        ).colorScheme.onError,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        localizations.choreDeleteOneTimeConfirmAction,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await ref
        .read(todayChoresProvider.notifier)
        .deleteOneTimeChore(
          householdId: householdId,
          occurrenceId: occurrence.id,
        );
    if (!mounted) {
      return;
    }
    final TodayChoresState state = ref.read(todayChoresProvider);
    final bool deleted =
        state is TodayChoresReady &&
        state.actionFailure == null &&
        state.pendingOccurrenceId == null &&
        state.undoableDeletion?.occurrence.id == occurrence.id &&
        !state.today.occurrences.any(
          (ChoreOccurrence item) => item.id == occurrence.id,
        );
    if (deleted) {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final ScaffoldFeatureController<SnackBar, SnackBarClosedReason>
      snackBarController = messenger.showSnackBar(
        SnackBar(
          key: const Key('today.oneTime.delete.succeeded'),
          content: Text(localizations.choreDeleteOneTimeSucceeded),
          action: SnackBarAction(
            label: localizations.choreDeleteUndoAction,
            onPressed: () {
              messenger.hideCurrentSnackBar(
                reason: SnackBarClosedReason.action,
              );
              unawaited(_undoDeleteOneTimeChore(householdId, occurrence.id));
            },
          ),
        ),
      );
      unawaited(
        snackBarController.closed.then<void>((SnackBarClosedReason reason) {
          if (reason != SnackBarClosedReason.action && mounted) {
            ref
                .read(todayChoresProvider.notifier)
                .dismissDeleteOneTimeChoreUndo(occurrence.id);
          }
        }),
      );
    }
  }

  Future<void> _undoDeleteOneTimeChore(
    HouseholdId householdId,
    ChoreOccurrenceId occurrenceId,
  ) async {
    await ref
        .read(todayChoresProvider.notifier)
        .undoDeleteOneTimeChore(
          householdId: householdId,
          occurrenceId: occurrenceId,
        );
    if (!mounted) {
      return;
    }
    final AppLocalizations localizations = AppLocalizations.of(context);
    final TodayChoresState state = ref.read(todayChoresProvider);
    final bool restored =
        state is TodayChoresReady &&
        state.restoredDeletionOccurrenceId == occurrenceId;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: Key(
          restored
              ? 'today.oneTime.restore.succeeded'
              : 'today.oneTime.restore.failed',
        ),
        content: Text(
          restored
              ? localizations.choreRestoreOneTimeSucceeded
              : localizations.choreRestoreOneTimeFailed,
        ),
      ),
    );
  }

  Future<void> _editRepeatingSeries(
    HouseholdId householdId,
    ChoreLocalDate householdLocalDate,
    ChoreOccurrence occurrence, {
    bool fromOccurrence = false,
  }) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ChoreRecurrenceRule? currentRule = occurrence.recurrenceRule;
    final HouseholdMemberId? currentAssigneeId =
        occurrence.seriesDefaultAssigneeMemberId;
    if (_reassignmentRosterBusy ||
        !occurrence.canManageSeries ||
        currentRule == null ||
        currentAssigneeId == null ||
        fromOccurrence &&
            occurrence.dueLocalDate.value.compareTo(householdLocalDate.value) <=
                0) {
      return;
    }
    final ChoreLocalDate editBoundaryLocalDate = fromOccurrence
        ? occurrence.dueLocalDate
        : householdLocalDate;
    final subscription = ref.listenManual<HouseholdMembersState>(
      householdMembersProvider,
      (_, _) {},
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    String titleInput = occurrence.title;
    String descriptionInput = occurrence.description ?? '';
    setState(() => _reassignmentRosterBusy = true);
    try {
      await ref.read(householdMembersProvider.notifier).load(householdId);
      if (!mounted) {
        return;
      }
      final HouseholdMembersState memberState = ref.read(
        householdMembersProvider,
      );
      if (memberState is! HouseholdMembersReady ||
          memberState.roster.householdId != householdId ||
          !memberState.roster.members.any(
            (HouseholdMember member) => member.id == currentAssigneeId,
          )) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            key: const Key('today.series.edit.rosterFailed'),
            content: Text(localizations.choreReassignRosterFailed),
          ),
        );
        return;
      }
      HouseholdMemberId selectedAssigneeId = currentAssigneeId;
      ChoreRecurrenceFrequency selectedFrequency = currentRule.frequency;
      Set<ChoreWeekday> selectedWeekdays =
          currentRule.frequency == ChoreRecurrenceFrequency.weekly
          ? <ChoreWeekday>{...currentRule.weekdays}
          : <ChoreWeekday>{
              ChoreWeekday.fromDateTime(editBoundaryLocalDate.toDateTime()),
            };
      int selectedMonthDay =
          currentRule.frequency == ChoreRecurrenceFrequency.monthly
          ? currentRule.monthDay!
          : editBoundaryLocalDate.toDateTime().day;
      final TextEditingController intervalController = TextEditingController(
        text: currentRule.interval.toString(),
      );
      final TextEditingController countController = TextEditingController(
        text: switch (currentRule.end) {
          ChoreRecurrenceCountEnd(:final count) => count.toString(),
          _ => '10',
        },
      );
      ChoreRecurrenceEndMode selectedEndMode = choreRecurrenceEndMode(
        currentRule.end,
      );
      DateTime selectedUntilDate = switch (currentRule.end) {
        ChoreRecurrenceUntilEnd(:final localDate) => localDate.toDateTime(),
        _ => editBoundaryLocalDate.toDateTime(),
      };
      if (selectedUntilDate.isBefore(editBoundaryLocalDate.toDateTime())) {
        selectedUntilDate = editBoundaryLocalDate.toDateTime();
      }
      TimeOfDay? selectedTime = occurrence.seriesDueLocalTime == null
          ? null
          : TimeOfDay(
              hour: occurrence.seriesDueLocalTime!.hour,
              minute: occurrence.seriesDueLocalTime!.minute,
            );
      _SeriesUpdateSelection? selection;
      final NavigatorState dialogNavigator = Navigator.of(
        context,
        rootNavigator: true,
      );
      final dialogRoute = DialogRoute<_SeriesUpdateSelection>(
        context: context,
        themes: InheritedTheme.capture(
          from: context,
          to: dialogNavigator.context,
        ),
        builder: (BuildContext dialogContext) => StatefulBuilder(
          builder: (BuildContext dialogContext, StateSetter setDialogState) {
            final ChoreLocalTime? dueLocalTime = _choreLocalTime(selectedTime);
            final int? interval = int.tryParse(intervalController.text.trim());
            final ChoreRecurrenceEnd? recurrenceEnd =
                choreRecurrenceEndFromEditor(
                  mode: selectedEndMode,
                  countText: countController.text,
                  untilDate: selectedUntilDate,
                );
            final ChoreRecurrenceRule? baseRecurrenceRule =
                interval == null || recurrenceEnd == null
                ? null
                : selectedFrequency == currentRule.frequency
                ? currentRule.tryWithIntervalAndEnd(
                    interval: interval,
                    end: recurrenceEnd,
                    minimumLocalDate: editBoundaryLocalDate,
                  )
                : ChoreRecurrenceRule.tryAnchored(
                    frequency: selectedFrequency,
                    startLocalDate: editBoundaryLocalDate,
                    interval: interval,
                    end: recurrenceEnd,
                  );
            final ChoreRecurrenceRule? recurrenceRule = switch ((
              baseRecurrenceRule,
              selectedFrequency,
            )) {
              (
                final ChoreRecurrenceRule base,
                ChoreRecurrenceFrequency.weekly,
              ) =>
                base.tryWithWeeklyWeekdays(
                  weekdays: selectedWeekdays,
                  interval: base.interval,
                  end: base.end,
                  minimumLocalDate: editBoundaryLocalDate,
                ),
              (
                final ChoreRecurrenceRule base,
                ChoreRecurrenceFrequency.monthly,
              ) =>
                base.tryWithMonthlyDay(
                  monthDay: selectedMonthDay,
                  interval: base.interval,
                  end: base.end,
                  minimumLocalDate: editBoundaryLocalDate,
                ),
              (final ChoreRecurrenceRule base, _) => base,
              _ => null,
            };
            final String normalizedTitle = titleInput.trim();
            final String normalizedDescription = descriptionInput.trim();
            final String? currentDescription = occurrence.description;
            final ChoreRecurrenceEndMode currentEndMode =
                choreRecurrenceEndMode(currentRule.end);
            final bool recurrenceInputChanged =
                selectedFrequency != currentRule.frequency ||
                selectedFrequency == ChoreRecurrenceFrequency.weekly &&
                    !_sameChoreWeekdaySet(
                      selectedWeekdays,
                      currentRule.weekdays,
                    ) ||
                selectedFrequency == ChoreRecurrenceFrequency.monthly &&
                    selectedMonthDay != currentRule.monthDay ||
                intervalController.text.trim() !=
                    currentRule.interval.toString() ||
                selectedEndMode != currentEndMode ||
                selectedEndMode == ChoreRecurrenceEndMode.count &&
                    countController.text.trim() !=
                        switch (currentRule.end) {
                          ChoreRecurrenceCountEnd(:final count) =>
                            count.toString(),
                          _ => '',
                        } ||
                selectedEndMode == ChoreRecurrenceEndMode.until &&
                    switch (currentRule.end) {
                      ChoreRecurrenceUntilEnd(:final localDate) =>
                        !DateUtils.isSameDay(
                          selectedUntilDate,
                          localDate.toDateTime(),
                        ),
                      _ => true,
                    };
            final bool changed =
                normalizedTitle != occurrence.title ||
                (normalizedDescription.isEmpty
                        ? null
                        : normalizedDescription) !=
                    currentDescription ||
                selectedAssigneeId != currentAssigneeId ||
                dueLocalTime != occurrence.seriesDueLocalTime ||
                recurrenceInputChanged;
            final MaterialLocalizations material = MaterialLocalizations.of(
              dialogContext,
            );
            return Dialog(
              key: const Key('today.series.edit.dialog'),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            fromOccurrence
                                ? localizations
                                      .choreEditSeriesFromOccurrenceDialogTitle
                                : localizations.choreEditSeriesDialogTitle,
                            style: Theme.of(
                              dialogContext,
                            ).textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          fromOccurrence
                              ? localizations
                                    .choreEditSeriesFromOccurrenceDialogBody
                              : localizations.choreEditSeriesDialogBody,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: const Key('today.series.edit.title'),
                          initialValue: titleInput,
                          maxLength: 160,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: localizations.choreTitleLabel,
                          ),
                          validator: (String? value) =>
                              value == null || value.trim().isEmpty
                              ? localizations.choreTitleValidation
                              : null,
                          onChanged: (String value) =>
                              setDialogState(() => titleInput = value),
                        ),
                        TextFormField(
                          key: const Key('today.series.edit.description'),
                          initialValue: descriptionInput,
                          maxLength: 4000,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: localizations.choreDescriptionLabel,
                          ),
                          onChanged: (String value) =>
                              setDialogState(() => descriptionInput = value),
                        ),
                        DropdownButtonFormField<HouseholdMemberId>(
                          key: const Key('today.series.edit.assignee'),
                          initialValue: selectedAssigneeId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: localizations.choreAssigneeLabel,
                          ),
                          items: memberState.roster.members
                              .map(
                                (HouseholdMember member) =>
                                    DropdownMenuItem<HouseholdMemberId>(
                                      value: member.id,
                                      child: Text(
                                        member.isCurrentUser
                                            ? localizations.choreAssigneeYou(
                                                member.displayName,
                                              )
                                            : member.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (HouseholdMemberId? value) {
                            if (value != null) {
                              setDialogState(() => selectedAssigneeId = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ChoreRecurrenceFrequency>(
                          key: const Key('today.series.edit.recurrence'),
                          initialValue: selectedFrequency,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: localizations.choreRecurrenceLabel,
                          ),
                          items: ChoreRecurrenceFrequency.values
                              .map(
                                (ChoreRecurrenceFrequency frequency) =>
                                    DropdownMenuItem<ChoreRecurrenceFrequency>(
                                      value: frequency,
                                      child: Text(
                                        _recurrenceLabel(
                                          localizations,
                                          frequency,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: (ChoreRecurrenceFrequency? value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedFrequency = value;
                                if (value == ChoreRecurrenceFrequency.weekly &&
                                    selectedWeekdays.isEmpty) {
                                  selectedWeekdays.add(
                                    ChoreWeekday.fromDateTime(
                                      editBoundaryLocalDate.toDateTime(),
                                    ),
                                  );
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        ChoreRecurrenceEditor(
                          keyPrefix: 'today.series.edit.advancedRecurrence',
                          frequency: selectedFrequency,
                          startLocalDate: editBoundaryLocalDate.toDateTime(),
                          weekdays: Set<ChoreWeekday>.unmodifiable(
                            selectedWeekdays,
                          ),
                          requiredWeekday: null,
                          monthDay: selectedMonthDay,
                          monthDayEditable: true,
                          intervalController: intervalController,
                          endMode: selectedEndMode,
                          countController: countController,
                          untilDate: selectedUntilDate,
                          enabled: true,
                          onWeekdaysChanged: (Set<ChoreWeekday> value) {
                            setDialogState(
                              () => selectedWeekdays = <ChoreWeekday>{...value},
                            );
                          },
                          onMonthDayChanged: (int value) {
                            setDialogState(() => selectedMonthDay = value);
                          },
                          onInputChanged: () => setDialogState(() {}),
                          onEndModeChanged: (ChoreRecurrenceEndMode value) {
                            setDialogState(() {
                              selectedEndMode = value;
                              if (value == ChoreRecurrenceEndMode.until &&
                                  selectedUntilDate.isBefore(
                                    editBoundaryLocalDate.toDateTime(),
                                  )) {
                                selectedUntilDate = editBoundaryLocalDate
                                    .toDateTime();
                              }
                            });
                          },
                          onUntilDateChanged: (DateTime value) =>
                              setDialogState(() => selectedUntilDate = value),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          key: const Key('today.series.edit.time'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.schedule_outlined),
                          title: Text(localizations.choreDueTimeLabel),
                          subtitle: Text(
                            selectedTime == null
                                ? localizations.choreAllDayLabel
                                : material.formatTimeOfDay(selectedTime!),
                          ),
                          trailing: selectedTime == null
                              ? const Icon(Icons.add)
                              : IconButton(
                                  key: const Key('today.series.edit.clearTime'),
                                  onPressed: () =>
                                      setDialogState(() => selectedTime = null),
                                  tooltip: localizations.choreClearTimeAction,
                                  icon: const Icon(Icons.clear),
                                ),
                          onTap: () async {
                            final TimeOfDay? nextTime = await showTimePicker(
                              context: dialogContext,
                              initialTime: selectedTime ?? TimeOfDay.now(),
                            );
                            if (nextTime != null && dialogContext.mounted) {
                              setDialogState(() => selectedTime = nextTime);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          key: const Key('today.series.edit.cancel'),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(localizations.memberCancelAction),
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          key: const Key('today.series.edit.confirm'),
                          onPressed: changed
                              ? () {
                                  if (!(formKey.currentState?.validate() ??
                                          false) ||
                                      recurrenceRule == null) {
                                    return;
                                  }
                                  Navigator.of(dialogContext).pop(
                                    _SeriesUpdateSelection(
                                      title: normalizedTitle,
                                      description: normalizedDescription,
                                      assigneeMemberId: selectedAssigneeId,
                                      dueLocalTime: dueLocalTime,
                                      recurrenceRule: recurrenceRule,
                                    ),
                                  );
                                }
                              : null,
                          child: Text(
                            fromOccurrence
                                ? localizations
                                      .choreEditSeriesFromOccurrenceConfirmAction
                                : localizations.choreEditSeriesConfirmAction,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      try {
        selection = await dialogNavigator.push(dialogRoute);
        await dialogRoute.completed;
      } finally {
        intervalController.dispose();
        countController.dispose();
      }
      if (selection == null || !mounted) {
        return;
      }
      final TodayChoresNotifier notifier = ref.read(
        todayChoresProvider.notifier,
      );
      if (fromOccurrence) {
        await notifier.updateRepeatingSeriesFromOccurrence(
          householdId: householdId,
          occurrenceId: occurrence.id,
          title: selection.title,
          description: selection.description,
          assigneeMemberId: selection.assigneeMemberId,
          dueLocalTime: selection.dueLocalTime,
          recurrenceRule: selection.recurrenceRule,
        );
      } else {
        await notifier.updateRepeatingSeries(
          householdId: householdId,
          occurrenceId: occurrence.id,
          title: selection.title,
          description: selection.description,
          assigneeMemberId: selection.assigneeMemberId,
          dueLocalTime: selection.dueLocalTime,
          recurrenceRule: selection.recurrenceRule,
        );
      }
      if (!mounted) {
        return;
      }
      final TodayChoresState state = ref.read(todayChoresProvider);
      final bool updated =
          state is TodayChoresReady &&
          state.actionFailure == null &&
          state.pendingOccurrenceId == null;
      if (updated) {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            key: const Key('today.series.edit.succeeded'),
            content: Text(
              fromOccurrence
                  ? localizations.choreEditSeriesFromOccurrenceSucceeded
                  : localizations.choreEditSeriesSucceeded,
            ),
          ),
        );
      }
    } finally {
      subscription.close();
      if (mounted) {
        setState(() => _reassignmentRosterBusy = false);
      }
    }
  }

  Future<void> _confirmCancelSeries(
    HouseholdId householdId,
    ChoreOccurrence occurrence, {
    bool fromOccurrence = false,
  }) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => Dialog(
            key: Key(
              fromOccurrence
                  ? 'today.series.cancelFromOccurrence.dialog'
                  : 'today.series.cancel.dialog',
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        fromOccurrence
                            ? localizations
                                  .choreCancelSeriesFromOccurrenceDialogTitle
                            : localizations.choreCancelSeriesDialogTitle,
                        style: Theme.of(dialogContext).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      fromOccurrence
                          ? localizations
                                .choreCancelSeriesFromOccurrenceDialogBody
                          : localizations.choreCancelSeriesDialogBody,
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      key: const Key('today.series.cancel.dismiss'),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(localizations.memberCancelAction),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: Key(
                        fromOccurrence
                            ? 'today.series.cancelFromOccurrence.confirm'
                            : 'today.series.cancel.confirm',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(
                          dialogContext,
                        ).colorScheme.error,
                        foregroundColor: Theme.of(
                          dialogContext,
                        ).colorScheme.onError,
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        fromOccurrence
                            ? localizations
                                  .choreCancelSeriesFromOccurrenceConfirmAction
                            : localizations.choreCancelSeriesConfirmAction,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    final TodayChoresNotifier notifier = ref.read(todayChoresProvider.notifier);
    if (fromOccurrence) {
      await notifier.cancelRepeatingSeriesFromOccurrence(
        householdId: householdId,
        occurrenceId: occurrence.id,
      );
    } else {
      await notifier.cancelRepeatingSeries(
        householdId: householdId,
        occurrenceId: occurrence.id,
      );
    }
    if (!mounted) {
      return;
    }
    final TodayChoresState state = ref.read(todayChoresProvider);
    final UndoableRepeatingChoreSeriesCancellation? undoableCancellation =
        state is TodayChoresReady ? state.undoableSeriesCancellation : null;
    final bool cancelled =
        state is TodayChoresReady &&
        state.actionFailure == null &&
        state.pendingOccurrenceId == null &&
        (!fromOccurrence ||
            undoableCancellation?.householdId == householdId &&
                undoableCancellation?.seriesId == occurrence.seriesId) &&
        !state.today.occurrences.any(
          (ChoreOccurrence item) => fromOccurrence
              ? item.id == occurrence.id
              : item.seriesId == occurrence.seriesId,
        );
    if (cancelled) {
      if (fromOccurrence && undoableCancellation != null) {
        _showSeriesCancellationUndoSnackBar(
          localizations,
          undoableCancellation,
          failed: false,
        );
        return;
      }
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: Key(
            fromOccurrence
                ? 'today.series.cancelFromOccurrence.succeeded'
                : 'today.series.cancel.succeeded',
          ),
          content: Text(
            fromOccurrence
                ? localizations.choreCancelSeriesFromOccurrenceSucceeded
                : localizations.choreCancelSeriesSucceeded,
          ),
        ),
      );
    }
  }

  void _showSeriesCancellationUndoSnackBar(
    AppLocalizations localizations,
    UndoableRepeatingChoreSeriesCancellation undoable, {
    required bool failed,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: Key(
          failed
              ? 'today.series.cancelFromOccurrence.undo.failed'
              : 'today.series.cancelFromOccurrence.succeeded',
        ),
        persist: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              failed
                  ? localizations.choreCancelSeriesFromOccurrenceUndoFailed
                  : localizations.choreCancelSeriesFromOccurrenceSucceeded,
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('today.series.cancelFromOccurrence.undo'),
              style: TextButton.styleFrom(
                foregroundColor:
                    SnackBarTheme.of(context).actionTextColor ??
                    Theme.of(context).colorScheme.inversePrimary,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () {
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
                unawaited(_resumeSeriesCancellation(undoable));
              },
              child: Text(
                localizations.choreCancelSeriesFromOccurrenceUndoAction,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resumeSeriesCancellation(
    UndoableRepeatingChoreSeriesCancellation undoable,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    await ref
        .read(todayChoresProvider.notifier)
        .resumeRepeatingSeriesCancellation(
          householdId: undoable.householdId,
          seriesId: undoable.seriesId,
        );
    if (!mounted) {
      return;
    }
    final TodayChoresState state = ref.read(todayChoresProvider);
    final UndoableRepeatingChoreSeriesCancellation? retryable =
        state is TodayChoresReady ? state.undoableSeriesCancellation : null;
    final bool restored =
        state is TodayChoresReady &&
        state.actionFailure == null &&
        retryable == null;
    if (restored) {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: const Key('today.series.cancelFromOccurrence.undo.succeeded'),
          content: Text(
            localizations.choreCancelSeriesFromOccurrenceUndoSucceeded,
          ),
        ),
      );
      return;
    }
    if (retryable != null &&
        retryable.householdId == undoable.householdId &&
        retryable.seriesId == undoable.seriesId) {
      _showSeriesCancellationUndoSnackBar(
        localizations,
        retryable,
        failed: true,
      );
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: const Key('today.series.cancelFromOccurrence.undo.failed'),
        content: Text(localizations.choreCancelSeriesFromOccurrenceUndoFailed),
      ),
    );
  }

  Future<void> _confirmSkip(
    HouseholdId householdId,
    ChoreOccurrence occurrence,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => Dialog(
            key: const Key('today.skip.dialog'),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: MediaQuery.sizeOf(dialogContext).height - 48,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(
                        localizations.choreSkipOccurrenceDialogTitle,
                        style: Theme.of(dialogContext).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(localizations.choreSkipOccurrenceDialogBody),
                    const SizedBox(height: 24),
                    TextButton(
                      key: const Key('today.skip.cancel'),
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(localizations.memberCancelAction),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('today.skip.confirm'),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: Text(
                        localizations.choreSkipOccurrenceConfirmAction,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await ref
        .read(todayChoresProvider.notifier)
        .skipOccurrence(householdId: householdId, occurrenceId: occurrence.id);
    if (!mounted) {
      return;
    }
    final TodayChoresState state = ref.read(todayChoresProvider);
    final bool skipped =
        state is TodayChoresReady &&
        state.actionFailure == null &&
        state.undoableSkip?.occurrence.id == occurrence.id &&
        !state.today.occurrences.any(
          (ChoreOccurrence item) => item.id == occurrence.id,
        );
    if (skipped) {
      _showRestoreSnackBar(
        localizations,
        householdId,
        occurrence.id,
        failed: false,
      );
    }
  }

  void _showRestoreSnackBar(
    AppLocalizations localizations,
    HouseholdId householdId,
    ChoreOccurrenceId occurrenceId, {
    required bool failed,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: Key(failed ? 'today.restore.failed' : 'today.skip.succeeded'),
        persist: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              failed
                  ? localizations.choreRestoreSkippedFailed
                  : localizations.choreSkipOccurrenceSucceeded,
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('today.skip.undo'),
              style: TextButton.styleFrom(
                foregroundColor:
                    SnackBarTheme.of(context).actionTextColor ??
                    Theme.of(context).colorScheme.inversePrimary,
                minimumSize: const Size(48, 48),
              ),
              onPressed: () {
                messenger.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action,
                );
                unawaited(_restoreSkippedOccurrence(householdId, occurrenceId));
              },
              child: Text(
                localizations.choreRestoreSkippedAction,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restoreSkippedOccurrence(
    HouseholdId householdId,
    ChoreOccurrenceId occurrenceId,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    await ref
        .read(todayChoresProvider.notifier)
        .restoreSkippedOccurrence(
          householdId: householdId,
          occurrenceId: occurrenceId,
        );
    if (!mounted) {
      return;
    }
    final TodayChoresState state = ref.read(todayChoresProvider);
    final bool restored =
        state is TodayChoresReady &&
        state.actionFailure == null &&
        state.undoableSkip == null &&
        state.today.occurrences.any(
          (ChoreOccurrence item) =>
              item.id == occurrenceId &&
              item.status == ChoreOccurrenceStatus.scheduled,
        );
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (restored) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: const Key('today.restore.succeeded'),
          content: Text(localizations.choreRestoreSkippedSucceeded),
        ),
      );
      return;
    }
    final bool retryable =
        state is TodayChoresReady &&
        state.undoableSkip?.occurrence.id == occurrenceId;
    if (retryable) {
      _showRestoreSnackBar(
        localizations,
        householdId,
        occurrenceId,
        failed: true,
      );
    } else {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: const Key('today.restore.failed'),
          content: Text(localizations.choreRestoreSkippedFailed),
        ),
      );
    }
  }

  String _recurrenceLabel(
    AppLocalizations localizations,
    ChoreRecurrenceFrequency frequency,
  ) {
    return switch (frequency) {
      ChoreRecurrenceFrequency.daily => localizations.choreRecurrenceDaily,
      ChoreRecurrenceFrequency.weekly => localizations.choreRecurrenceWeekly,
      ChoreRecurrenceFrequency.monthly => localizations.choreRecurrenceMonthly,
    };
  }

  void _openCreate(ChoreLocalDate dueLocalDate) {
    final String location = Uri(
      path: AppRoutes.choreCreate,
      queryParameters: <String, String>{'due': dueLocalDate.value},
    ).toString();
    unawaited(_openCreateFlow(location));
  }

  Future<void> _openCreateFlow(String location) async {
    final bool? created = await context.push<bool>(location);
    if (!mounted || created != true) {
      return;
    }
    _loadToday(force: true);
  }

  void _openChoresHub() {
    unawaited(context.push<void>(AppRoutes.chores));
  }

  void _openInvite() {
    unawaited(context.push<void>(AppRoutes.inviteCreate));
  }

  Widget _activationCard(
    HouseholdActivationProgressState state, {
    required ChoreLocalDate localDate,
    required bool readOnly,
  }) {
    final HouseholdId? householdId = ref
        .read(authLifecycleProvider)
        .activeHousehold
        ?.householdId;
    if (householdId == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      child: HouseholdActivationProgressCard(
        state: state,
        expectedHouseholdId: householdId,
        readOnly: readOnly,
        onInvite: _openInvite,
        onCreateChore: () => _openCreate(localDate),
        onRetry: () => unawaited(
          ref
              .read(householdActivationProgressProvider.notifier)
              .load(householdId),
        ),
      ),
    );
  }

  Widget _weeklyReportCard(HouseholdWeeklyReportState state) {
    final HouseholdId? householdId = ref
        .read(authLifecycleProvider)
        .activeHousehold
        ?.householdId;
    if (householdId == null ||
        state is! HouseholdWeeklyReportReady ||
        state.report.householdId != householdId ||
        state.report.weekOffset !=
            HouseholdWeeklyReportRequest.latestWeekOffset) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: double.infinity,
      child: HouseholdWeeklyReportCard(
        report: state.report,
        onOpen: _openWeeklyReport,
      ),
    );
  }

  bool _partialTodayReadOnly(
    TodayChoresState overdueState,
    TodayCalendarState calendarState,
  ) {
    return overdueState is TodayChoresReady &&
            overdueState.cacheMetadata != null ||
        calendarState is TodayCalendarReady && calendarState.isReadOnlyCache;
  }
}

ChoreLocalTime? _choreLocalTime(TimeOfDay? value) {
  if (value == null) {
    return null;
  }
  return ChoreLocalTime.tryParse(
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}',
  );
}
