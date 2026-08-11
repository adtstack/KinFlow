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
import 'package:kinflow_app/features/calendar/application/calendar_events_state.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/calendar/presentation/calendar_failure_message.dart';
import 'package:kinflow_app/features/calendar/presentation/calendar_import_route_context.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/calendar/presentation/widgets/calendar_recurrence_editor.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/notifications/presentation/widgets/notification_app_shell_action.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class CalendarEventsScreen extends ConsumerStatefulWidget {
  const CalendarEventsScreen({this.initialOccurrenceId, super.key});

  final CalendarEventOccurrenceId? initialOccurrenceId;

  @override
  ConsumerState<CalendarEventsScreen> createState() =>
      _CalendarEventsScreenState();
}

class _CalendarEventsScreenState extends ConsumerState<CalendarEventsScreen>
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
      unawaited(ref.read(calendarEventsProvider.notifier).resume());
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
    if (!force && _requestedHouseholdId == householdId) {
      return;
    }
    _requestedHouseholdId = householdId;
    final CalendarEventOccurrenceId? occurrenceId = widget.initialOccurrenceId;
    if (occurrenceId != null) {
      unawaited(
        ref
            .read(calendarEventsProvider.notifier)
            .openOccurrence(householdId, occurrenceId),
      );
    } else if (force &&
        ref.read(calendarEventsProvider) is CalendarEventsReady) {
      unawaited(ref.read(calendarEventsProvider.notifier).refresh());
    } else {
      unawaited(ref.read(calendarEventsProvider.notifier).load(householdId));
    }
    unawaited(ref.read(householdMembersProvider.notifier).load(householdId));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final CalendarEventsState state = ref.watch(calendarEventsProvider);
    ref.watch(householdMembersProvider);
    final bool busy =
        state is CalendarEventsReady &&
        (state.actionPending || state.refreshing || state.loadingMore);
    return AppResponsiveScaffold(
      key: const Key('calendar.screen'),
      selectedPrimaryDestination: widget.initialOccurrenceId == null
          ? AppPrimaryDestination.calendar
          : null,
      onPrimaryDestinationSelected: widget.initialOccurrenceId == null
          ? (AppPrimaryDestination destination) =>
                context.go(AppRoutes.primaryLocation(destination))
          : null,
      title: localizations.calendarTitle,
      actions: <Widget>[
        if (widget.initialOccurrenceId == null)
          const NotificationAppShellAction(
            buttonKey: Key('calendar.notifications'),
          ),
        IconButton(
          key: const Key('calendar.refresh'),
          onPressed: busy ? null : () => _load(force: true),
          tooltip: localizations.retryAction,
          icon: const Icon(Icons.refresh),
        ),
        if (widget.initialOccurrenceId != null)
          IconButton(
            key: const Key('calendar.today'),
            onPressed: () => context.go(AppRoutes.today),
            tooltip: localizations.calendarTodayAction,
            icon: const Icon(Icons.today_outlined),
          ),
      ],
      body: _body(localizations, state),
    );
  }

  Widget _body(AppLocalizations localizations, CalendarEventsState state) {
    return switch (state) {
      CalendarEventsInitial() ||
      CalendarEventsLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('calendar.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.calendarLoadingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      CalendarEventsLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('calendar.error'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.event_busy_outlined, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                calendarFailureMessage(localizations, failure),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('calendar.retry'),
              onPressed: () => _load(force: true),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      CalendarEventsTargetUnavailable() => ScrollableStatusLayout(
        child: Column(
          key: const Key('calendar.targetUnavailable'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.event_busy_outlined, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                localizations.calendarTargetUnavailableTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.calendarTargetUnavailableMessage,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('calendar.targetUnavailable.back'),
              onPressed: () => context.go(AppRoutes.calendar),
              icon: const Icon(Icons.calendar_month_outlined),
              label: Text(localizations.calendarBackToCalendarAction),
            ),
          ],
        ),
      ),
      CalendarEventsReady() => _list(localizations, state),
    };
  }

  Widget _empty(AppLocalizations localizations, CalendarEventsReady state) {
    return Card(
      key: const Key('calendar.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(
                Icons.calendar_month_outlined,
                size: AppIconSize.status,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                localizations.calendarEmptyTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.calendarNoEventsInView,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(AppLocalizations localizations, CalendarEventsReady state) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppWindowSizeClass sizeClass = AppBreakpoints.sizeClassFor(
          constraints.maxWidth,
        );
        return RefreshIndicator(
          onRefresh: () => ref.read(calendarEventsProvider.notifier).refresh(),
          child: ListView(
            key: const Key('calendar.list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(
              sizeClass == AppWindowSizeClass.compact
                  ? AppSpacing.md
                  : AppSpacing.lg,
            ),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppLayoutTokens.pageContentMaxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _viewSelector(localizations, state, sizeClass),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        children: <Widget>[
                          _timeZoneLabel(localizations, state.page),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: <Widget>[
                              OutlinedButton.icon(
                                key: const Key('calendar.import'),
                                onPressed: state.busy
                                    ? null
                                    : () => _openImport(state.page),
                                icon: const Icon(Icons.upload_file_outlined),
                                label: Text(localizations.calendarImportAction),
                              ),
                              FilledButton.icon(
                                key: const Key('calendar.create'),
                                onPressed: state.busy
                                    ? null
                                    : () => _openEditor(state.page),
                                icon: const Icon(Icons.add),
                                label: Text(localizations.calendarCreateAction),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _rangeHeader(localizations, state),
                      if (state.refreshing) ...<Widget>[
                        const SizedBox(height: AppSpacing.sm),
                        const LinearProgressIndicator(),
                      ],
                      if (state.syncStatus ==
                          CalendarSyncConnectionStatus
                              .disconnected) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _syncBanner(localizations),
                      ],
                      if (state.conflictResolution != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _conflictBanner(
                          localizations,
                          state.conflictResolution!,
                        ),
                      ],
                      if (state.actionFailure != null ||
                          state.refreshFailure != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        _failureBanner(
                          localizations,
                          state.actionFailure ?? state.refreshFailure!,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      if (state.viewMode == CalendarViewMode.month)
                        _monthView(localizations, state, sizeClass)
                      else
                        _eventGroups(localizations, state),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openImport(CalendarEventPage page) async {
    final int? importedCount = await context.push<int>(
      AppRoutes.calendarImport,
      extra: CalendarImportRouteContext(
        householdId: page.householdId,
        householdTimeZone: page.householdTimeZone,
      ),
    );
    if (!mounted || importedCount == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).calendarImportSuccess(importedCount),
        ),
      ),
    );
    _load(force: true);
  }

  Widget _viewSelector(
    AppLocalizations localizations,
    CalendarEventsReady state,
    AppWindowSizeClass sizeClass,
  ) {
    if (sizeClass == AppWindowSizeClass.compact) {
      return Semantics(
        label: localizations.calendarTitle,
        child: DropdownButtonFormField<CalendarViewMode>(
          key: ValueKey<String>(
            'calendar.view.selector.${state.viewMode.wireValue}',
          ),
          initialValue: state.viewMode,
          isExpanded: true,
          decoration: const InputDecoration(isDense: true),
          items: CalendarViewMode.values
              .map(
                (CalendarViewMode mode) => DropdownMenuItem<CalendarViewMode>(
                  value: mode,
                  child: Text(_viewLabel(localizations, mode)),
                ),
              )
              .toList(growable: false),
          onChanged: state.busy
              ? null
              : (CalendarViewMode? mode) {
                  if (mode != null) {
                    unawaited(
                      ref.read(calendarEventsProvider.notifier).setView(mode),
                    );
                  }
                },
        ),
      );
    }
    return SegmentedButton<CalendarViewMode>(
      key: const Key('calendar.view.selector'),
      showSelectedIcon: false,
      segments: CalendarViewMode.values
          .map(
            (CalendarViewMode mode) => ButtonSegment<CalendarViewMode>(
              value: mode,
              label: Text(_viewLabel(localizations, mode)),
            ),
          )
          .toList(growable: false),
      selected: <CalendarViewMode>{state.viewMode},
      onSelectionChanged: state.busy
          ? null
          : (Set<CalendarViewMode> selection) => unawaited(
              ref
                  .read(calendarEventsProvider.notifier)
                  .setView(selection.single),
            ),
    );
  }

  String _viewLabel(AppLocalizations localizations, CalendarViewMode viewMode) {
    return switch (viewMode) {
      CalendarViewMode.agenda => localizations.calendarAgendaView,
      CalendarViewMode.day => localizations.calendarDayView,
      CalendarViewMode.month => localizations.calendarMonthView,
    };
  }

  Widget _rangeHeader(
    AppLocalizations localizations,
    CalendarEventsReady state,
  ) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String heading = switch (state.viewMode) {
      CalendarViewMode.agenda => localizations.calendarDateRange(
        material.formatMediumDate(_displayDate(state.page.range.startDate)),
        material.formatMediumDate(
          _displayDate(state.page.range.endDateExclusive.addDays(-1)),
        ),
      ),
      CalendarViewMode.day => material.formatMediumDate(
        _displayDate(state.focusedDate),
      ),
      CalendarViewMode.month => material.formatMonthYear(
        _displayDate(state.focusedDate.firstDayOfMonth),
      ),
    };
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              key: const Key('calendar.previous'),
              onPressed: state.busy
                  ? null
                  : () => unawaited(
                      ref.read(calendarEventsProvider.notifier).shiftRange(-1),
                    ),
              tooltip: localizations.calendarPreviousRangeAction,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  heading,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            IconButton(
              key: const Key('calendar.next'),
              onPressed: state.busy
                  ? null
                  : () => unawaited(
                      ref.read(calendarEventsProvider.notifier).shiftRange(1),
                    ),
              tooltip: localizations.calendarNextRangeAction,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        TextButton.icon(
          key: const Key('calendar.goToToday'),
          onPressed: state.busy
              ? null
              : () => unawaited(
                  ref.read(calendarEventsProvider.notifier).goToToday(),
                ),
          icon: const Icon(Icons.today_outlined),
          label: Text(localizations.calendarGoToTodayAction),
        ),
      ],
    );
  }

  Widget _eventGroups(
    AppLocalizations localizations,
    CalendarEventsReady state,
  ) {
    if (state.page.items.isEmpty) {
      return _empty(localizations, state);
    }
    final Map<CalendarLocalDate, List<CalendarEventProjection>> groups =
        <CalendarLocalDate, List<CalendarEventProjection>>{};
    for (final CalendarEventProjection item in state.page.items) {
      groups
          .putIfAbsent(item.viewLocalDate, () => <CalendarEventProjection>[])
          .add(item);
    }
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final MapEntry<CalendarLocalDate, List<CalendarEventProjection>>
            group
            in groups.entries) ...<Widget>[
          Semantics(
            header: true,
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                material.formatMediumDate(_displayDate(group.key)),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          for (final CalendarEventProjection item in group.value) ...<Widget>[
            _eventCard(localizations, state, item.event),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        _pagination(localizations, state),
      ],
    );
  }

  Widget _monthView(
    AppLocalizations localizations,
    CalendarEventsReady state,
    AppWindowSizeClass sizeClass,
  ) {
    final CalendarMonthSummary summary = state.monthSummary!;
    final Widget grid = _monthGrid(localizations, state, summary);
    final Widget selectedEvents = _selectedDateEvents(localizations, state);
    if (sizeClass == AppWindowSizeClass.expanded) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 2, child: grid),
          const SizedBox(width: AppSpacing.lg),
          Expanded(child: selectedEvents),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        grid,
        const SizedBox(height: AppSpacing.lg),
        selectedEvents,
      ],
    );
  }

  Widget _monthGrid(
    AppLocalizations localizations,
    CalendarEventsReady state,
    CalendarMonthSummary summary,
  ) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final int firstWeekday = material.firstDayOfWeekIndex;
    final int monthWeekday = summary.request.monthStartDate.weekday % 7;
    final int leadingDays = (monthWeekday - firstWeekday + 7) % 7;
    final int cellCount = ((leadingDays + summary.days.length + 6) ~/ 7) * 7;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gridWidth = constraints.maxWidth < 336
            ? 336
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth,
            child: Column(
              children: <Widget>[
                Row(
                  children: List<Widget>.generate(7, (int index) {
                    final int weekday = (firstWeekday + index) % 7;
                    return SizedBox(
                      width: gridWidth / 7,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          material.narrowWeekdays[weekday],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    );
                  }),
                ),
                GridView.builder(
                  key: const Key('calendar.month.grid'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 1,
                  ),
                  itemCount: cellCount,
                  itemBuilder: (BuildContext context, int index) {
                    final int dayIndex = index - leadingDays;
                    if (dayIndex < 0 || dayIndex >= summary.days.length) {
                      return const SizedBox.shrink();
                    }
                    final CalendarMonthDaySummary day = summary.days[dayIndex];
                    final bool selected = day.date == state.focusedDate;
                    final bool today = day.date == summary.householdLocalDate;
                    final ColorScheme colors = Theme.of(context).colorScheme;
                    final VoidCallback? selectDate = state.busy
                        ? null
                        : () => unawaited(
                            ref
                                .read(calendarEventsProvider.notifier)
                                .selectMonthDate(day.date),
                          );
                    return Semantics(
                      key: Key(
                        'calendar.month.day.semantics.${day.date.value}',
                      ),
                      button: true,
                      enabled: !state.busy,
                      selected: selected,
                      label: localizations.calendarMonthDateSemantics(
                        material.formatMediumDate(_displayDate(day.date)),
                        day.eventCount,
                      ),
                      onTap: selectDate,
                      child: ExcludeSemantics(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: Key('calendar.month.day.${day.date.value}'),
                            borderRadius: BorderRadius.circular(AppRadii.sm),
                            onTap: selectDate,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xxs),
                              child: Ink(
                                decoration: ShapeDecoration(
                                  color: selected
                                      ? colors.primaryContainer
                                      : Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadii.sm,
                                    ),
                                    side: today
                                        ? BorderSide(color: colors.primary)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text('${day.date.day}'),
                                      if (day.eventCount > 0)
                                        Text(
                                          '${day.eventCount}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: colors.primary,
                                                fontWeight: FontWeight.bold,
                                                height: 1,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _selectedDateEvents(
    AppLocalizations localizations,
    CalendarEventsReady state,
  ) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            localizations.calendarSelectedDateHeading(
              material.formatMediumDate(_displayDate(state.focusedDate)),
            ),
            key: const Key('calendar.selectedDate.heading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (state.page.items.isEmpty)
          _empty(localizations, state)
        else
          for (final CalendarEventProjection item
              in state.page.items) ...<Widget>[
            _eventCard(localizations, state, item.event),
            const SizedBox(height: AppSpacing.sm),
          ],
        _pagination(localizations, state),
      ],
    );
  }

  Widget _pagination(
    AppLocalizations localizations,
    CalendarEventsReady state,
  ) {
    if (state.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.page.hasMore && state.loadMoreFailure == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.loadMoreFailure != null) ...<Widget>[
          Semantics(
            liveRegion: true,
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(localizations.calendarLoadMoreError),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          key: const Key('calendar.loadMore'),
          onPressed: state.busy
              ? null
              : () => unawaited(
                  ref.read(calendarEventsProvider.notifier).loadMore(),
                ),
          icon: const Icon(Icons.expand_more),
          label: Text(localizations.calendarLoadMoreAction),
        ),
      ],
    );
  }

  Widget _timeZoneLabel(
    AppLocalizations localizations,
    CalendarEventPage page,
  ) {
    return Text(
      localizations.calendarHouseholdTimeZone(page.householdTimeZone.value),
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  Widget _failureBanner(
    AppLocalizations localizations,
    CalendarFailure failure,
  ) {
    return Semantics(
      liveRegion: true,
      child: Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(calendarFailureMessage(localizations, failure)),
        ),
      ),
    );
  }

  Widget _syncBanner(AppLocalizations localizations) {
    return Semantics(
      liveRegion: true,
      child: Card(
        key: const Key('calendar.sync.disconnected'),
        color: Theme.of(context).colorScheme.tertiaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(localizations.calendarLiveDisconnectedMessage),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                key: const Key('calendar.sync.reconnect'),
                onPressed: () => unawaited(
                  ref.read(calendarEventsProvider.notifier).reconnect(),
                ),
                child: Text(localizations.calendarReconnectAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _conflictBanner(
    AppLocalizations localizations,
    CalendarConflictResolution resolution,
  ) {
    return Semantics(
      liveRegion: true,
      child: Card(
        key: Key('calendar.conflict.${resolution.name}'),
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(switch (resolution) {
            CalendarConflictResolution.latestReloaded =>
              localizations.calendarConflictLatestReloadedMessage,
            CalendarConflictResolution.targetUnavailable =>
              localizations.calendarConflictTargetUnavailableMessage,
          }),
        ),
      ),
    );
  }

  Widget _eventCard(
    AppLocalizations localizations,
    CalendarEventsReady state,
    OneTimeCalendarEvent event,
  ) {
    final bool pending =
        state.pendingSeriesId == event.seriesId ||
        state.pendingOccurrenceId == event.occurrenceId;
    final String eventIdentity = event.isRecurring
        ? event.occurrenceId.value
        : event.seriesId.value;
    final String schedule = _scheduleLabel(localizations, event);
    return Card(
      key: Key('calendar.event.$eventIdentity'),
      color: state.highlightedOccurrenceId == event.occurrenceId
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(event.isAllDay ? Icons.wb_sunny_outlined : Icons.schedule),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(schedule),
                  if (event.recurrenceRule != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      label: _recurrenceSummary(localizations, event),
                      child: Chip(
                        key: Key('calendar.event.recurrence.$eventIdentity'),
                        avatar: const Icon(Icons.repeat, size: 18),
                        label: Text(_recurrenceSummary(localizations, event)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                  if (event.isException) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Chip(
                      key: Key(
                        'calendar.event.exception.${event.occurrenceId.value}',
                      ),
                      avatar: const Icon(
                        Icons.edit_calendar_outlined,
                        size: 18,
                      ),
                      label: Text(
                        localizations.calendarOccurrenceModifiedLabel,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                  if (!event.isAllDay) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      localizations.calendarTimeZoneLabel(
                        event.timeZone!.value,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    localizations.calendarParticipantSummary(
                      event.participants
                          .map(
                            (CalendarEventParticipant participant) =>
                                participant.displayName,
                          )
                          .join(', '),
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.description != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(event.description!),
                  ],
                  if (pending) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            if (event.isRecurring) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Column(
                children: <Widget>[
                  IconButton(
                    key: Key(
                      'calendar.occurrence.edit.${event.occurrenceId.value}',
                    ),
                    onPressed: pending || state.busy
                        ? null
                        : () => _openEditor(state.page, event: event),
                    tooltip: localizations.calendarOccurrenceEditAction,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    key: Key(
                      'calendar.occurrence.cancel.${event.occurrenceId.value}',
                    ),
                    onPressed: pending || state.busy
                        ? null
                        : () => _confirmCancelOccurrence(event),
                    tooltip: localizations.calendarOccurrenceCancelAction,
                    icon: const Icon(Icons.event_busy_outlined),
                  ),
                  PopupMenuButton<_RecurringSeriesAction>(
                    key: Key(
                      'calendar.series.menu.${event.occurrenceId.value}',
                    ),
                    enabled: !pending && !state.busy,
                    tooltip: localizations.calendarSeriesMenuTooltip,
                    onSelected: (_RecurringSeriesAction action) => unawaited(
                      _handleSeriesAction(state.page, event, action),
                    ),
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<_RecurringSeriesAction>>[
                          if (!event.isException &&
                              event.recurrenceLocalStartDate.compareTo(
                                    state.page.householdLocalDate,
                                  ) >=
                                  0) ...<
                            PopupMenuEntry<_RecurringSeriesAction>
                          >[
                            PopupMenuItem<_RecurringSeriesAction>(
                              key: Key(
                                'calendar.series.editFromOccurrence.'
                                '${event.occurrenceId.value}',
                              ),
                              value: _RecurringSeriesAction.editFromOccurrence,
                              child: Text(
                                localizations
                                    .calendarSeriesEditFromOccurrenceAction,
                              ),
                            ),
                            PopupMenuItem<_RecurringSeriesAction>(
                              key: Key(
                                'calendar.series.cancelFromOccurrence.'
                                '${event.occurrenceId.value}',
                              ),
                              value:
                                  _RecurringSeriesAction.cancelFromOccurrence,
                              child: Text(
                                localizations
                                    .calendarSeriesCancelFromOccurrenceAction,
                              ),
                            ),
                          ],
                          PopupMenuItem<_RecurringSeriesAction>(
                            value: _RecurringSeriesAction.edit,
                            child: Text(localizations.calendarSeriesEditAction),
                          ),
                          PopupMenuItem<_RecurringSeriesAction>(
                            value: _RecurringSeriesAction.cancel,
                            child: Text(
                              localizations.calendarSeriesCancelAction,
                            ),
                          ),
                        ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
            ] else ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Column(
                children: <Widget>[
                  IconButton(
                    key: Key('calendar.edit.${event.seriesId.value}'),
                    onPressed: pending || state.busy
                        ? null
                        : () => _openEditor(state.page, event: event),
                    tooltip: localizations.calendarEditAction,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    key: Key('calendar.delete.${event.seriesId.value}'),
                    onPressed: pending || state.busy
                        ? null
                        : () => _confirmDelete(event),
                    tooltip: localizations.calendarDeleteAction,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _scheduleLabel(
    AppLocalizations localizations,
    OneTimeCalendarEvent event,
  ) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String startDate = material.formatMediumDate(
      _displayDate(event.localStartDate),
    );
    if (event.isAllDay) {
      final CalendarAllDayRange range = event.allDayRange!;
      if (range.dayCount == 1) {
        return localizations.calendarAllDaySingle(startDate);
      }
      final String endDate = material.formatMediumDate(
        _displayDate(range.endDateExclusive.addDays(-1)),
      );
      return localizations.calendarAllDayRange(startDate, endDate);
    }
    final CalendarLocalTime time = event.localStartTime!;
    return localizations.calendarTimedSchedule(
      startDate,
      material.formatTimeOfDay(TimeOfDay(hour: time.hour, minute: time.minute)),
      localizations.calendarDurationMinutes(event.durationMinutes!),
    );
  }

  String _recurrenceSummary(
    AppLocalizations localizations,
    OneTimeCalendarEvent event,
  ) {
    final CalendarRecurrenceRule rule = event.recurrenceRule!;
    final String pattern = calendarRecurrencePattern(
      localizations,
      rule.frequency,
      rule.interval,
    );
    if (rule.frequency == CalendarRecurrenceFrequency.weekly) {
      return localizations.calendarRecurrenceWeeklySummary(
        pattern,
        calendarRecurrenceWeekdayList(localizations, rule.weekdays),
      );
    }
    if (rule.frequency == CalendarRecurrenceFrequency.monthly) {
      return localizations.calendarRecurrenceMonthlySummary(
        pattern,
        rule.monthDay!,
      );
    }
    return localizations.calendarRecurrenceSummary(pattern);
  }

  Future<void> _openEditor(
    CalendarEventPage page, {
    OneTimeCalendarEvent? event,
  }) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final HouseholdMembersState membersState = ref.read(
      householdMembersProvider,
    );
    if (membersState is! HouseholdMembersReady ||
        membersState.roster.householdId != page.householdId) {
      unawaited(
        ref.read(householdMembersProvider.notifier).load(page.householdId),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.calendarRosterError)),
      );
      return;
    }
    final _CalendarEventEditorResult? result = await showAppDialog(
      context: context,
      builder: (BuildContext context) => _CalendarEventEditorDialog(
        householdId: page.householdId,
        householdTimeZone: page.householdTimeZone,
        householdLocalDate: page.householdLocalDate,
        roster: membersState.roster,
        event: event,
        seriesDetail: null,
        seriesBoundaryLocalDate: null,
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    switch (result) {
      case _OneTimeEditorResult(:final draft):
        if (event == null) {
          unawaited(ref.read(calendarEventsProvider.notifier).create(draft));
        } else if (event.isRecurring) {
          unawaited(
            ref
                .read(calendarEventsProvider.notifier)
                .updateOccurrence(current: event, draft: draft),
          );
        } else {
          unawaited(
            ref
                .read(calendarEventsProvider.notifier)
                .update(current: event, draft: draft),
          );
        }
      case _RecurringEditorResult(:final draft):
        unawaited(
          ref.read(calendarEventsProvider.notifier).createRecurring(draft),
        );
      case _RecurringSeriesEditorResult():
        break;
    }
  }

  Future<void> _handleSeriesAction(
    CalendarEventPage page,
    OneTimeCalendarEvent event,
    _RecurringSeriesAction action,
  ) {
    return switch (action) {
      _RecurringSeriesAction.editFromOccurrence => _openSeriesEditor(
        page,
        event,
        fromOccurrence: true,
      ),
      _RecurringSeriesAction.cancelFromOccurrence =>
        _confirmCancelSeriesFromOccurrence(event),
      _RecurringSeriesAction.edit => _openSeriesEditor(page, event),
      _RecurringSeriesAction.cancel => _confirmCancelSeries(event),
    };
  }

  Future<void> _openSeriesEditor(
    CalendarEventPage page,
    OneTimeCalendarEvent event, {
    bool fromOccurrence = false,
  }) async {
    final RecurringCalendarSeriesDetail? detail = await ref
        .read(calendarEventsProvider.notifier)
        .loadSeriesForEdit(event);
    if (!mounted || detail == null) {
      return;
    }
    final AppLocalizations localizations = AppLocalizations.of(context);
    final HouseholdMembersState membersState = ref.read(
      householdMembersProvider,
    );
    if (membersState is! HouseholdMembersReady ||
        membersState.roster.householdId != page.householdId) {
      unawaited(
        ref.read(householdMembersProvider.notifier).load(page.householdId),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.calendarRosterError)),
      );
      return;
    }
    final _CalendarEventEditorResult? result = await showAppDialog(
      context: context,
      builder: (BuildContext context) => _CalendarEventEditorDialog(
        householdId: page.householdId,
        householdTimeZone: detail.householdTimeZone,
        householdLocalDate: detail.householdLocalDate,
        roster: membersState.roster,
        event: null,
        seriesDetail: detail,
        seriesBoundaryLocalDate: fromOccurrence
            ? event.recurrenceLocalStartDate
            : null,
      ),
    );
    if (!mounted || result is! _RecurringSeriesEditorResult) {
      return;
    }
    if (fromOccurrence) {
      unawaited(
        ref
            .read(calendarEventsProvider.notifier)
            .updateSeriesFromOccurrence(
              current: event,
              series: result.current,
              draft: result.draft,
            ),
      );
    } else {
      unawaited(
        ref
            .read(calendarEventsProvider.notifier)
            .updateSeries(current: result.current, draft: result.draft),
      );
    }
  }

  Future<void> _confirmDelete(OneTimeCalendarEvent event) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(localizations.calendarDeleteTitle),
            content: Text(localizations.calendarDeleteBody(event.title)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(localizations.calendarCancelAction),
              ),
              FilledButton(
                key: const Key('calendar.delete.confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(localizations.calendarDeleteConfirmAction),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) {
      unawaited(ref.read(calendarEventsProvider.notifier).delete(event));
    }
  }

  Future<void> _confirmCancelOccurrence(OneTimeCalendarEvent event) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(localizations.calendarOccurrenceCancelTitle),
            content: Text(
              localizations.calendarOccurrenceCancelBody(event.title),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(localizations.calendarCancelAction),
              ),
              FilledButton(
                key: const Key('calendar.occurrence.cancel.confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  localizations.calendarOccurrenceCancelConfirmAction,
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) {
      unawaited(
        ref.read(calendarEventsProvider.notifier).cancelOccurrence(event),
      );
    }
  }

  Future<void> _confirmCancelSeries(OneTimeCalendarEvent event) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(localizations.calendarSeriesCancelTitle),
            content: Text(localizations.calendarSeriesCancelBody(event.title)),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(localizations.calendarCancelAction),
              ),
              FilledButton(
                key: const Key('calendar.series.cancel.confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(localizations.calendarSeriesCancelConfirmAction),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed && mounted) {
      unawaited(ref.read(calendarEventsProvider.notifier).cancelSeries(event));
    }
  }

  Future<void> _confirmCancelSeriesFromOccurrence(
    OneTimeCalendarEvent event,
  ) async {
    final RecurringCalendarSeriesDetail? detail = await ref
        .read(calendarEventsProvider.notifier)
        .loadSeriesForEdit(event);
    if (!mounted || detail == null) {
      return;
    }
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => Dialog(
            key: const Key('calendar.series.cancelFromOccurrence.dialog'),
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
                        localizations.calendarSeriesCancelFromOccurrenceTitle,
                        style: Theme.of(dialogContext).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      localizations.calendarSeriesCancelFromOccurrenceBody(
                        event.title,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Text(localizations.calendarCancelAction),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FilledButton(
                      key: const Key(
                        'calendar.series.cancelFromOccurrence.confirm',
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
                        localizations
                            .calendarSeriesCancelFromOccurrenceConfirmAction,
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
        .read(calendarEventsProvider.notifier)
        .cancelSeriesFromOccurrence(current: event, series: detail);
    if (!mounted) {
      return;
    }
    final CalendarEventsState state = ref.read(calendarEventsProvider);
    final UndoableRecurringCalendarSeriesCancellation? undoable =
        state is CalendarEventsReady ? state.undoableSeriesCancellation : null;
    if (state is CalendarEventsReady &&
        state.actionFailure == null &&
        undoable?.householdId == event.householdId &&
        undoable?.seriesId == event.seriesId) {
      _showSeriesCancellationUndoSnackBar(
        localizations,
        undoable!,
        failed: false,
      );
    }
  }

  void _showSeriesCancellationUndoSnackBar(
    AppLocalizations localizations,
    UndoableRecurringCalendarSeriesCancellation undoable, {
    required bool failed,
  }) {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: Key(
          failed
              ? 'calendar.series.cancelFromOccurrence.undo.failed'
              : 'calendar.series.cancelFromOccurrence.succeeded',
        ),
        persist: true,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  failed
                      ? localizations
                            .calendarSeriesCancelFromOccurrenceUndoFailed
                      : localizations
                            .calendarSeriesCancelFromOccurrenceSucceeded,
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  key: const Key('calendar.series.cancelFromOccurrence.undo'),
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
                    localizations.calendarSeriesCancelFromOccurrenceUndoAction,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resumeSeriesCancellation(
    UndoableRecurringCalendarSeriesCancellation undoable,
  ) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    await ref
        .read(calendarEventsProvider.notifier)
        .resumeSeriesCancellation(
          householdId: undoable.householdId,
          seriesId: undoable.seriesId,
        );
    if (!mounted) {
      return;
    }
    final CalendarEventsState state = ref.read(calendarEventsProvider);
    final UndoableRecurringCalendarSeriesCancellation? retryable =
        state is CalendarEventsReady ? state.undoableSeriesCancellation : null;
    if (state is CalendarEventsReady &&
        state.actionFailure == null &&
        retryable == null) {
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          key: const Key('calendar.series.cancelFromOccurrence.undo.succeeded'),
          content: Text(
            localizations.calendarSeriesCancelFromOccurrenceUndoSucceeded,
          ),
        ),
      );
      return;
    }
    if (retryable?.householdId == undoable.householdId &&
        retryable?.seriesId == undoable.seriesId) {
      _showSeriesCancellationUndoSnackBar(
        localizations,
        retryable!,
        failed: true,
      );
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: const Key('calendar.series.cancelFromOccurrence.undo.failed'),
        content: Text(
          localizations.calendarSeriesCancelFromOccurrenceUndoFailed,
        ),
      ),
    );
  }
}

enum _RecurringSeriesAction {
  editFromOccurrence,
  cancelFromOccurrence,
  edit,
  cancel,
}

sealed class _CalendarEventEditorResult {
  const _CalendarEventEditorResult();
}

final class _OneTimeEditorResult extends _CalendarEventEditorResult {
  const _OneTimeEditorResult(this.draft);

  final OneTimeCalendarEventDraft draft;
}

final class _RecurringEditorResult extends _CalendarEventEditorResult {
  const _RecurringEditorResult(this.draft);

  final RecurringCalendarEventDraft draft;
}

final class _RecurringSeriesEditorResult extends _CalendarEventEditorResult {
  const _RecurringSeriesEditorResult({
    required this.current,
    required this.draft,
  });

  final RecurringCalendarSeriesDetail current;
  final RecurringCalendarEventDraft draft;
}

class _CalendarEventEditorDialog extends ConsumerStatefulWidget {
  const _CalendarEventEditorDialog({
    required this.householdId,
    required this.householdTimeZone,
    required this.householdLocalDate,
    required this.roster,
    required this.event,
    required this.seriesDetail,
    required this.seriesBoundaryLocalDate,
  }) : assert(event == null || seriesDetail == null),
       assert(seriesBoundaryLocalDate == null || seriesDetail != null);

  final HouseholdId householdId;
  final IanaTimeZoneId householdTimeZone;
  final CalendarLocalDate householdLocalDate;
  final HouseholdMemberRoster roster;
  final OneTimeCalendarEvent? event;
  final RecurringCalendarSeriesDetail? seriesDetail;
  final CalendarLocalDate? seriesBoundaryLocalDate;

  @override
  ConsumerState<_CalendarEventEditorDialog> createState() =>
      _CalendarEventEditorDialogState();
}

class _CalendarEventEditorDialogState
    extends ConsumerState<_CalendarEventEditorDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late bool _isAllDay;
  late DateTime _startDate;
  late DateTime _endDateInclusive;
  late TimeOfDay _startTime;
  late int _durationMinutes;
  late CalendarDstOverlapPolicy _overlapPolicy;
  late IanaTimeZoneId _timeZone;
  late Set<HouseholdMemberId> _participantIds;
  late CalendarRecurrenceFrequency? _recurrenceFrequency;
  late Set<CalendarWeekday> _recurrenceWeekdays;
  late final TextEditingController _recurrenceIntervalController;
  late CalendarRecurrenceEndMode _recurrenceEndMode;
  late final TextEditingController _recurrenceCountController;
  late DateTime _recurrenceUntilDate;
  Timer? _overlapDebounce;
  CalendarOverlapPreview? _overlapPreview;
  var _overlapChecking = false;
  var _overlapUnavailable = false;
  var _overlapGeneration = 0;
  var _participantInvalid = false;
  var _draftInvalid = false;

  @override
  void initState() {
    super.initState();
    final OneTimeCalendarEvent? event = widget.event;
    final RecurringCalendarSeriesDetail? seriesDetail = widget.seriesDetail;
    final OneTimeCalendarEventDraft? seriesEvent = seriesDetail?.draft.event;
    _titleController = TextEditingController(
      text: seriesEvent?.title ?? event?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: seriesEvent?.description ?? event?.description ?? '',
    );
    _isAllDay = seriesEvent?.isAllDay ?? event?.isAllDay ?? false;
    _startDate = _displayDate(
      widget.seriesBoundaryLocalDate ??
          seriesEvent?.localStartDate ??
          event?.localStartDate ??
          widget.householdLocalDate,
    );
    final CalendarLocalDate? endDateExclusive =
        seriesEvent?.allDayEndDateExclusive ??
        event?.allDayRange?.endDateExclusive;
    final int? seriesAllDaySpan =
        widget.seriesBoundaryLocalDate != null &&
            seriesEvent != null &&
            endDateExclusive != null
        ? endDateExclusive.differenceInDays(seriesEvent.localStartDate)
        : null;
    _endDateInclusive = endDateExclusive == null
        ? _startDate
        : seriesAllDaySpan != null
        ? _displayDate(
            widget.seriesBoundaryLocalDate!.addDays(seriesAllDaySpan - 1),
          )
        : _displayDate(endDateExclusive.addDays(-1));
    final CalendarLocalTime? sourceStartTime =
        seriesEvent?.localStartTime ?? event?.localStartTime;
    _startTime = sourceStartTime == null
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: sourceStartTime.hour, minute: sourceStartTime.minute);
    _durationMinutes =
        seriesEvent?.durationMinutes ?? event?.durationMinutes ?? 60;
    _overlapPolicy =
        seriesEvent?.overlapPolicy ??
        event?.overlapPolicy ??
        CalendarDstOverlapPolicy.earlier;
    _timeZone =
        seriesEvent?.timeZone ?? event?.timeZone ?? widget.householdTimeZone;
    final CalendarRecurrenceRule? sourceRecurrenceRule =
        seriesDetail?.draft.recurrenceRule ?? event?.recurrenceRule;
    _recurrenceFrequency = sourceRecurrenceRule?.frequency;
    final CalendarWeekday startWeekday = CalendarWeekday.fromDate(
      CalendarLocalDate.fromDateTime(_startDate),
    );
    _recurrenceWeekdays =
        sourceRecurrenceRule?.frequency == CalendarRecurrenceFrequency.weekly
        ? sourceRecurrenceRule!.weekdays.toSet()
        : <CalendarWeekday>{startWeekday};
    _recurrenceWeekdays.add(startWeekday);
    _recurrenceIntervalController = TextEditingController(
      text: '${sourceRecurrenceRule?.interval ?? 1}',
    );
    final CalendarRecurrenceEnd sourceRecurrenceEnd =
        sourceRecurrenceRule?.end ?? const CalendarRecurrenceNeverEnds();
    _recurrenceEndMode = calendarRecurrenceEndMode(sourceRecurrenceEnd);
    _recurrenceCountController = TextEditingController(
      text: sourceRecurrenceEnd is CalendarRecurrenceCountEnd
          ? '${sourceRecurrenceEnd.count}'
          : '10',
    );
    final DateTime minimumUntilDate = _minimumRecurrenceUntilDate();
    _recurrenceUntilDate = sourceRecurrenceEnd is CalendarRecurrenceUntilEnd
        ? _displayDate(sourceRecurrenceEnd.localDate)
        : minimumUntilDate;
    if (_recurrenceUntilDate.isBefore(minimumUntilDate)) {
      _recurrenceUntilDate = minimumUntilDate;
    }
    final Set<HouseholdMemberId> activeIds = widget.roster.members
        .map((HouseholdMember member) => member.id)
        .toSet();
    final Iterable<HouseholdMemberId>? sourceParticipantIds =
        seriesEvent?.participantMemberIds ??
        event?.participants.map(
          (CalendarEventParticipant participant) => participant.memberId,
        );
    _participantIds = sourceParticipantIds == null
        ? <HouseholdMemberId>{widget.roster.currentMember.id}
        : sourceParticipantIds
              .map((HouseholdMemberId participantId) => participantId)
              .where(activeIds.contains)
              .toSet();
    if (_participantIds.isEmpty) {
      _participantIds.add(widget.roster.currentMember.id);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scheduleOverlapPreview(delay: Duration.zero);
      }
    });
  }

  @override
  void dispose() {
    _overlapDebounce?.cancel();
    _overlapGeneration += 1;
    _titleController.dispose();
    _descriptionController.dispose();
    _recurrenceIntervalController.dispose();
    _recurrenceCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final List<int> durations = <int>{
      30,
      60,
      90,
      120,
      _durationMinutes,
    }.toList()..sort();
    return Dialog(
      key: const Key('calendar.editor'),
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppLayoutTokens.dialogContentMaxWidth,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    widget.seriesBoundaryLocalDate != null
                        ? localizations
                              .calendarSeriesEditFromOccurrenceEditorTitle
                        : widget.seriesDetail != null
                        ? localizations.calendarSeriesEditorEditTitle
                        : widget.event == null
                        ? localizations.calendarEditorCreateTitle
                        : widget.event!.isRecurring
                        ? localizations.calendarOccurrenceEditorEditTitle
                        : localizations.calendarEditorEditTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (widget.seriesBoundaryLocalDate != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    localizations.calendarSeriesEditFromOccurrenceEditorBody,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  key: const Key('calendar.editor.title'),
                  controller: _titleController,
                  maxLength: 200,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: localizations.calendarTitleLabel,
                  ),
                  validator: (String? value) =>
                      value == null || value.trim().isEmpty
                      ? localizations.calendarTitleValidation
                      : null,
                ),
                TextFormField(
                  key: const Key('calendar.editor.description'),
                  controller: _descriptionController,
                  maxLength: 8000,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: localizations.calendarDescriptionLabel,
                  ),
                ),
                SwitchListTile(
                  key: const Key('calendar.editor.allDay'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(localizations.calendarAllDayLabel),
                  value: _isAllDay,
                  onChanged: (bool value) {
                    setState(() {
                      _isAllDay = value;
                      _draftInvalid = false;
                    });
                    _scheduleOverlapPreview();
                  },
                ),
                if (widget.event == null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<CalendarRecurrenceFrequency?>(
                    key: const Key('calendar.editor.recurrence'),
                    initialValue: _recurrenceFrequency,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localizations.calendarRecurrenceLabel,
                    ),
                    items: <DropdownMenuItem<CalendarRecurrenceFrequency?>>[
                      if (widget.seriesDetail == null)
                        DropdownMenuItem<CalendarRecurrenceFrequency?>(
                          child: Text(localizations.calendarRecurrenceOnce),
                        ),
                      for (final CalendarRecurrenceFrequency frequency
                          in CalendarRecurrenceFrequency.values)
                        DropdownMenuItem<CalendarRecurrenceFrequency?>(
                          value: frequency,
                          child: Text(
                            _recurrenceLabel(localizations, frequency),
                          ),
                        ),
                    ],
                    onChanged: (CalendarRecurrenceFrequency? value) {
                      setState(() {
                        _recurrenceFrequency = value;
                        if (value == CalendarRecurrenceFrequency.weekly) {
                          _ensureRecurrenceStartWeekday();
                        }
                        _draftInvalid = false;
                      });
                      _scheduleOverlapPreview();
                    },
                  ),
                  if (_recurrenceFrequency != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    CalendarRecurrenceEditor(
                      keyPrefix: 'calendar.editor.recurrenceOptions',
                      frequency: _recurrenceFrequency!,
                      startLocalDate: _startDate,
                      minimumUntilDate: _minimumRecurrenceUntilDate(),
                      weekdays: Set<CalendarWeekday>.unmodifiable(
                        _recurrenceWeekdays,
                      ),
                      anchorWeekday: CalendarWeekday.fromDate(
                        CalendarLocalDate.fromDateTime(_startDate),
                      ),
                      intervalController: _recurrenceIntervalController,
                      endMode: _recurrenceEndMode,
                      countController: _recurrenceCountController,
                      untilDate: _recurrenceUntilDate,
                      enabled: true,
                      onWeekdaysChanged: (Set<CalendarWeekday> value) {
                        setState(() {
                          _recurrenceWeekdays = value.toSet();
                          _ensureRecurrenceStartWeekday();
                          _draftInvalid = false;
                        });
                        _scheduleOverlapPreview();
                      },
                      onInputChanged: () {
                        setState(() => _draftInvalid = false);
                        _scheduleOverlapPreview();
                      },
                      onEndModeChanged: (CalendarRecurrenceEndMode value) {
                        setState(() {
                          _recurrenceEndMode = value;
                          _draftInvalid = false;
                        });
                        _scheduleOverlapPreview();
                      },
                      onUntilDateChanged: (DateTime value) {
                        setState(() {
                          _recurrenceUntilDate = value;
                          _draftInvalid = false;
                        });
                        _scheduleOverlapPreview();
                      },
                    ),
                  ],
                ],
                _dateButton(
                  key: const Key('calendar.editor.startDate'),
                  label: localizations.calendarStartDateLabel,
                  value: material.formatMediumDate(_startDate),
                  onPressed: _pickStartDate,
                ),
                if (_isAllDay) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _dateButton(
                    key: const Key('calendar.editor.endDate'),
                    label: localizations.calendarEndDateLabel,
                    value: material.formatMediumDate(_endDateInclusive),
                    onPressed: _pickEndDate,
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('calendar.editor.startTime'),
                    onPressed: _pickStartTime,
                    icon: const Icon(Icons.schedule),
                    label: Text(
                      '${localizations.calendarStartTimeLabel}: '
                      '${material.formatTimeOfDay(_startTime)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<int>(
                    key: const Key('calendar.editor.duration'),
                    initialValue: _durationMinutes,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localizations.calendarDurationLabel,
                    ),
                    items: durations
                        .map(
                          (int minutes) => DropdownMenuItem<int>(
                            value: minutes,
                            child: Text(
                              localizations.calendarDurationMinutes(minutes),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (int? value) {
                      if (value != null) {
                        setState(() => _durationMinutes = value);
                        _scheduleOverlapPreview();
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(localizations.calendarTimeZoneLabel(_timeZone.value)),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<CalendarDstOverlapPolicy>(
                    key: const Key('calendar.editor.overlap'),
                    initialValue: _overlapPolicy,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: localizations.calendarOverlapLabel,
                    ),
                    items: <DropdownMenuItem<CalendarDstOverlapPolicy>>[
                      DropdownMenuItem<CalendarDstOverlapPolicy>(
                        value: CalendarDstOverlapPolicy.earlier,
                        child: Text(
                          localizations.calendarOverlapEarlier,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem<CalendarDstOverlapPolicy>(
                        value: CalendarDstOverlapPolicy.later,
                        child: Text(
                          localizations.calendarOverlapLater,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (CalendarDstOverlapPolicy? value) {
                      if (value != null) {
                        setState(() => _overlapPolicy = value);
                        _scheduleOverlapPreview();
                      }
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text(
                    localizations.calendarParticipantsLabel,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final HouseholdMember member in widget.roster.members)
                  CheckboxListTile(
                    key: Key('calendar.editor.participant.${member.id.value}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(member.displayName),
                    value: _participantIds.contains(member.id),
                    onChanged: (bool? selected) {
                      setState(() {
                        if (selected ?? false) {
                          _participantIds.add(member.id);
                        } else {
                          _participantIds.remove(member.id);
                        }
                        _participantInvalid = false;
                      });
                      _scheduleOverlapPreview();
                    },
                  ),
                if (_participantInvalid)
                  Text(
                    localizations.calendarParticipantValidation,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_overlapChecking ||
                    _overlapUnavailable ||
                    _overlapPreview != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _overlapHint(localizations, material),
                ],
                if (_draftInvalid)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      localizations.calendarInvalidError,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(localizations.calendarCancelAction),
                    ),
                    FilledButton(
                      key: const Key('calendar.editor.save'),
                      onPressed: _save,
                      child: Text(localizations.calendarSaveAction),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateButton({
    required Key key,
    required String label,
    required String value,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      key: key,
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(
        '$label: $value',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _pickStartDate() async {
    final DateTime earliestDate = widget.seriesBoundaryLocalDate == null
        ? DateTime(1900)
        : _displayDate(widget.seriesBoundaryLocalDate!);
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: earliestDate,
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() {
        _startDate = selected;
        if (_endDateInclusive.isBefore(selected)) {
          _endDateInclusive = selected;
        }
        final DateTime minimumUntilDate = _minimumRecurrenceUntilDate();
        if (_recurrenceUntilDate.isBefore(minimumUntilDate)) {
          _recurrenceUntilDate = minimumUntilDate;
        }
        if (_recurrenceFrequency == CalendarRecurrenceFrequency.weekly) {
          _ensureRecurrenceStartWeekday();
        }
        _draftInvalid = false;
      });
      _scheduleOverlapPreview();
    }
  }

  DateTime _minimumRecurrenceUntilDate() {
    final DateTime startDate = DateUtils.dateOnly(_startDate);
    if (widget.seriesDetail == null) {
      return startDate;
    }
    final DateTime householdDate = _displayDate(widget.householdLocalDate);
    return householdDate.isAfter(startDate) ? householdDate : startDate;
  }

  void _ensureRecurrenceStartWeekday() {
    _recurrenceWeekdays.add(
      CalendarWeekday.fromDate(CalendarLocalDate.fromDateTime(_startDate)),
    );
  }

  Future<void> _pickEndDate() async {
    final DateTime? selected = await showDatePicker(
      context: context,
      initialDate: _endDateInclusive.isBefore(_startDate)
          ? _startDate
          : _endDateInclusive,
      firstDate: _startDate,
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() {
        _endDateInclusive = selected;
        _draftInvalid = false;
      });
      _scheduleOverlapPreview();
    }
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (selected != null && mounted) {
      setState(() {
        _startTime = selected;
        _draftInvalid = false;
      });
      _scheduleOverlapPreview();
    }
  }

  Widget _overlapHint(
    AppLocalizations localizations,
    MaterialLocalizations material,
  ) {
    final CalendarOverlapPreview? preview = _overlapPreview;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Card.outlined(
        key: const Key('calendar.editor.overlapHint'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                localizations.calendarScheduleOverlapHeading,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_overlapChecking) ...<Widget>[
                const LinearProgressIndicator(
                  key: Key('calendar.editor.overlapChecking'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(localizations.calendarScheduleOverlapChecking),
              ] else if (_overlapUnavailable)
                Text(
                  localizations.calendarScheduleOverlapUnavailable,
                  key: const Key('calendar.editor.overlapUnavailable'),
                )
              else if (preview != null && !preview.hasConflicts)
                Text(
                  localizations.calendarScheduleOverlapNone,
                  key: const Key('calendar.editor.overlapNone'),
                )
              else if (preview != null) ...<Widget>[
                Text(
                  localizations.calendarScheduleOverlapSummary(
                    preview.totalConflictCount,
                    preview.candidateOccurrenceCount,
                    material.formatMediumDate(
                      _displayDate(preview.checkedFromLocalDate),
                    ),
                    material.formatMediumDate(
                      _displayDate(preview.checkedThroughLocalDate),
                    ),
                  ),
                  key: const Key('calendar.editor.overlapSummary'),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final CalendarOverlapConflict conflict
                    in preview.conflicts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.errorContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Padding(
                        key: Key(
                          'calendar.editor.overlap.'
                          '${conflict.occurrenceId.value}',
                        ),
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              conflict.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              localizations
                                  .calendarScheduleOverlapCandidateDate(
                                    material.formatMediumDate(
                                      _displayDate(
                                        conflict.candidateLocalStartDate,
                                      ),
                                    ),
                                  ),
                            ),
                            Text(
                              _overlapConflictSchedule(
                                localizations,
                                material,
                                conflict,
                              ),
                            ),
                            Text(
                              localizations.calendarParticipantSummary(
                                conflict.participants
                                    .map(
                                      (
                                        CalendarOverlapParticipant participant,
                                      ) => participant.displayName,
                                    )
                                    .join(', '),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (preview.truncated)
                  Text(
                    localizations.calendarScheduleOverlapTruncated(
                      calendarOverlapPreviewLimit,
                    ),
                  ),
              ],
              if (!_overlapChecking) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(localizations.calendarScheduleOverlapSaveAllowed),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _overlapConflictSchedule(
    AppLocalizations localizations,
    MaterialLocalizations material,
    CalendarOverlapConflict conflict,
  ) {
    final String startDate = material.formatMediumDate(
      _displayDate(conflict.viewLocalStartDate),
    );
    if (conflict.isAllDay) {
      final CalendarLocalDate inclusiveEnd = conflict.allDayEndDateExclusive!
          .addDays(-1);
      return inclusiveEnd == conflict.viewLocalStartDate
          ? localizations.calendarAllDaySingle(startDate)
          : localizations.calendarAllDayRange(
              startDate,
              material.formatMediumDate(_displayDate(inclusiveEnd)),
            );
    }
    final CalendarLocalTime time = conflict.viewLocalStartTime!;
    return localizations.calendarTimedSchedule(
      startDate,
      material.formatTimeOfDay(TimeOfDay(hour: time.hour, minute: time.minute)),
      localizations.calendarDurationMinutes(conflict.durationMinutes!),
    );
  }

  void _scheduleOverlapPreview({
    Duration delay = const Duration(milliseconds: 350),
  }) {
    _overlapDebounce?.cancel();
    final int generation = ++_overlapGeneration;
    setState(() {
      _overlapPreview = null;
      _overlapUnavailable = false;
      _overlapChecking = true;
    });
    _overlapDebounce = Timer(
      delay,
      () => unawaited(_loadOverlapPreview(generation)),
    );
  }

  Future<void> _loadOverlapPreview(int generation) async {
    final CalendarOverlapPreviewRequest? request = _overlapPreviewRequest();
    if (request == null) {
      if (mounted && generation == _overlapGeneration) {
        setState(() => _overlapChecking = false);
      }
      return;
    }
    final PreviewCalendarOverlapsResult result = await ref
        .read(calendarEventsProvider.notifier)
        .previewOverlaps(request);
    if (!mounted || generation != _overlapGeneration) {
      return;
    }
    setState(() {
      _overlapChecking = false;
      switch (result) {
        case CalendarOverlapsPreviewed(:final preview):
          _overlapPreview = preview;
          _overlapUnavailable = false;
        case PreviewCalendarOverlapsFailed():
          _overlapPreview = null;
          _overlapUnavailable = true;
      }
    });
  }

  CalendarOverlapPreviewRequest? _overlapPreviewRequest() {
    if (_participantIds.isEmpty) {
      return null;
    }
    final CalendarLocalDate localStartDate = CalendarLocalDate.fromDateTime(
      _startDate,
    );
    final CalendarLocalTime? localStartTime = _isAllDay
        ? null
        : CalendarLocalTime.tryParse(
            '${_startTime.hour.toString().padLeft(2, '0')}:'
            '${_startTime.minute.toString().padLeft(2, '0')}',
          );
    final CalendarLocalDate? allDayEndDateExclusive = _isAllDay
        ? CalendarLocalDate.fromDateTime(_endDateInclusive).addDays(1)
        : null;
    final CalendarRecurrenceRule? recurrenceRule = _overlapRecurrenceRule(
      localStartDate,
    );
    if (widget.event == null &&
        _recurrenceFrequency != null &&
        recurrenceRule == null) {
      return null;
    }
    final OneTimeCalendarEvent? event = widget.event;
    final RecurringCalendarSeriesDetail? seriesDetail = widget.seriesDetail;
    final CalendarEventSeriesId? excludedSeriesId =
        seriesDetail?.seriesId ??
        (event != null && !event.isRecurring ? event.seriesId : null);
    final CalendarEventOccurrenceId? excludedOccurrenceId =
        event != null && event.isRecurring ? event.occurrenceId : null;
    return CalendarOverlapPreviewRequest.tryCreate(
      householdId: widget.householdId,
      isAllDay: _isAllDay,
      localStartDate: localStartDate,
      localStartTime: localStartTime,
      durationMinutes: _isAllDay ? null : _durationMinutes,
      allDayEndDateExclusive: allDayEndDateExclusive,
      timeZone: _isAllDay ? null : _timeZone,
      overlapPolicy: _isAllDay ? null : _overlapPolicy,
      recurrenceRule: recurrenceRule,
      windowStartDate: recurrenceRule == null
          ? localStartDate
          : widget.seriesBoundaryLocalDate ??
                seriesDetail?.householdLocalDate ??
                localStartDate,
      participantMemberIds: _participantIds,
      excludedSeriesId: excludedSeriesId,
      excludedOccurrenceId: excludedOccurrenceId,
    );
  }

  CalendarRecurrenceRule? _overlapRecurrenceRule(
    CalendarLocalDate localStartDate,
  ) {
    if (widget.event != null) {
      return null;
    }
    return _editedRecurrenceRule(localStartDate);
  }

  CalendarRecurrenceRule? _editedRecurrenceRule(
    CalendarLocalDate localStartDate,
  ) {
    final CalendarRecurrenceFrequency? recurrence = _recurrenceFrequency;
    if (recurrence == null) {
      return null;
    }
    final int? interval = int.tryParse(
      _recurrenceIntervalController.text.trim(),
    );
    final CalendarRecurrenceEnd? end = calendarRecurrenceEndFromEditor(
      mode: _recurrenceEndMode,
      countText: _recurrenceCountController.text,
      untilDate: _recurrenceUntilDate,
    );
    if (interval == null || end == null) {
      return null;
    }
    final CalendarRecurrenceRule? currentRule =
        widget.seriesDetail?.draft.recurrenceRule;
    final CalendarRecurrenceRule baseRule =
        currentRule != null && currentRule.frequency == recurrence
        ? currentRule
        : CalendarRecurrenceRule.anchored(
            frequency: recurrence,
            startLocalDate: localStartDate,
          );
    if (recurrence == CalendarRecurrenceFrequency.weekly) {
      return baseRule.tryWithWeeklyWeekdays(
        weekdays: _recurrenceWeekdays,
        sourceLocalDate: localStartDate,
        interval: interval,
        end: end,
        minimumLocalDate: CalendarLocalDate.fromDateTime(
          _minimumRecurrenceUntilDate(),
        ),
      );
    }
    if (recurrence == CalendarRecurrenceFrequency.monthly) {
      return baseRule.tryWithMonthlyStartDate(
        sourceLocalDate: localStartDate,
        interval: interval,
        end: end,
        minimumLocalDate: CalendarLocalDate.fromDateTime(
          _minimumRecurrenceUntilDate(),
        ),
      );
    }
    return baseRule.tryWithIntervalAndEnd(
      interval: interval,
      end: end,
      minimumLocalDate: CalendarLocalDate.fromDateTime(
        _minimumRecurrenceUntilDate(),
      ),
    );
  }

  void _save() {
    final bool formValid = _formKey.currentState?.validate() ?? false;
    if (_participantIds.isEmpty) {
      setState(() => _participantInvalid = true);
    }
    if (!formValid || _participantIds.isEmpty) {
      return;
    }
    final CalendarLocalDate localStartDate = CalendarLocalDate.fromDateTime(
      _startDate,
    );
    final CalendarLocalTime? localStartTime = _isAllDay
        ? null
        : CalendarLocalTime.tryParse(
            '${_startTime.hour.toString().padLeft(2, '0')}:'
            '${_startTime.minute.toString().padLeft(2, '0')}',
          );
    final CalendarLocalDate? allDayEndDateExclusive = _isAllDay
        ? CalendarLocalDate.fromDateTime(_endDateInclusive).addDays(1)
        : null;
    final OneTimeCalendarEventDraft? draft =
        OneTimeCalendarEventDraft.tryCreate(
          householdId: widget.householdId,
          title: _titleController.text,
          description: _descriptionController.text,
          isAllDay: _isAllDay,
          localStartDate: localStartDate,
          localStartTime: localStartTime,
          durationMinutes: _isAllDay ? null : _durationMinutes,
          allDayEndDateExclusive: allDayEndDateExclusive,
          timeZone: _isAllDay ? null : _timeZone,
          overlapPolicy: _isAllDay ? null : _overlapPolicy,
          participantMemberIds: _participantIds,
        );
    if (draft == null) {
      setState(() => _draftInvalid = true);
      return;
    }
    final CalendarRecurrenceFrequency? recurrence = _recurrenceFrequency;
    final CalendarRecurrenceRule? recurrenceRule =
        widget.event == null && recurrence != null
        ? _editedRecurrenceRule(localStartDate)
        : null;
    final RecurringCalendarSeriesDetail? seriesDetail = widget.seriesDetail;
    if (seriesDetail != null) {
      if (recurrenceRule == null) {
        setState(() => _draftInvalid = true);
        return;
      }
      final RecurringCalendarEventDraft? recurringDraft =
          RecurringCalendarEventDraft.tryCreate(
            event: draft,
            recurrenceRule: recurrenceRule,
          );
      if (recurringDraft == null) {
        setState(() => _draftInvalid = true);
        return;
      }
      Navigator.of(context).pop(
        _RecurringSeriesEditorResult(
          current: seriesDetail,
          draft: recurringDraft,
        ),
      );
      return;
    }
    if (recurrence == null || widget.event != null) {
      Navigator.of(context).pop(_OneTimeEditorResult(draft));
      return;
    }
    if (recurrenceRule == null) {
      setState(() => _draftInvalid = true);
      return;
    }
    final RecurringCalendarEventDraft? recurringDraft =
        RecurringCalendarEventDraft.tryCreate(
          event: draft,
          recurrenceRule: recurrenceRule,
        );
    if (recurringDraft == null) {
      setState(() => _draftInvalid = true);
      return;
    }
    Navigator.of(context).pop(_RecurringEditorResult(recurringDraft));
  }
}

String _recurrenceLabel(
  AppLocalizations localizations,
  CalendarRecurrenceFrequency frequency,
) {
  return switch (frequency) {
    CalendarRecurrenceFrequency.daily => localizations.calendarRecurrenceDaily,
    CalendarRecurrenceFrequency.weekly =>
      localizations.calendarRecurrenceWeekly,
    CalendarRecurrenceFrequency.monthly =>
      localizations.calendarRecurrenceMonthly,
  };
}

DateTime _displayDate(CalendarLocalDate value) {
  final DateTime utc = value.toUtcCalendarDate();
  return DateTime(utc.year, utc.month, utc.day);
}
