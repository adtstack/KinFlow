import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/chores/application/chore_occurrence_history_controller.dart';
import 'package:kinflow_app/features/chores/application/chore_occurrence_history_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class ChoreOccurrenceHistorySheet extends StatefulWidget {
  const ChoreOccurrenceHistorySheet({
    required this.repository,
    required this.householdId,
    required this.occurrence,
    this.embedded = false,
    this.actions,
    super.key,
  });

  final ChoreRepository repository;
  final HouseholdId householdId;
  final ChoreOccurrence occurrence;
  final bool embedded;
  final Widget? actions;

  @override
  State<ChoreOccurrenceHistorySheet> createState() =>
      _ChoreOccurrenceHistorySheetState();
}

class _ChoreOccurrenceHistorySheetState
    extends State<ChoreOccurrenceHistorySheet> {
  late final ChoreOccurrenceHistoryController _controller;
  late final StreamSubscription<ChoreOccurrenceHistoryState> _subscription;
  ChoreOccurrenceHistoryState _state = const ChoreOccurrenceHistoryInitial();

  @override
  void initState() {
    super.initState();
    _controller = ChoreOccurrenceHistoryController(
      repository: widget.repository,
    );
    _subscription = _controller.states.listen((
      ChoreOccurrenceHistoryState next,
    ) {
      if (mounted) {
        setState(() => _state = next);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _controller.load(
            householdId: widget.householdId,
            occurrenceId: widget.occurrence.id,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final double sheetHeight = (MediaQuery.sizeOf(context).height * 0.9)
        .clamp(0, 760)
        .toDouble();

    final Widget content = Column(
      children: <Widget>[
        if (!widget.embedded) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xxs,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: IconButton(
                key: const Key('chore.history.close'),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: localizations.choreDetailsCloseTooltip,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
        Expanded(
          child: ListView(
            key: const Key('chore.history.scroll'),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              if (!widget.embedded) ...<Widget>[
                Semantics(
                  header: true,
                  child: Text(
                    localizations.choreDetailsTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              _currentDetails(localizations, material),
              if (widget.actions != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                widget.actions!,
              ],
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                header: true,
                child: Text(
                  localizations.choreHistoryHeading,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ..._historyContent(localizations, material),
            ],
          ),
        ),
      ],
    );

    return SafeArea(
      top: false,
      child: widget.embedded
          ? SizedBox.expand(
              key: const Key('chore.target.details'),
              child: content,
            )
          : SizedBox(
              key: const Key('chore.history.sheet'),
              height: sheetHeight,
              child: content,
            ),
    );
  }

  Widget _currentDetails(
    AppLocalizations localizations,
    MaterialLocalizations material,
  ) {
    final ChoreOccurrence occurrence = widget.occurrence;
    final bool completed = occurrence.status == ChoreOccurrenceStatus.completed;
    final String schedule = _scheduleLabel(
      localizations,
      material,
      occurrence.dueLocalDate,
      occurrence.dueLocalTime,
    );
    return Column(
      key: const Key('chore.history.current'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            localizations.choreDetailsCurrentHeading,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(occurrence.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          localizations.todayChoreMetadata(
            occurrence.assigneeDisplayName,
            schedule,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          completed
              ? localizations.choreCompletedStatus
              : localizations.choreScheduledStatus,
        ),
        if (occurrence.description != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(occurrence.description!),
        ],
      ],
    );
  }

  List<Widget> _historyContent(
    AppLocalizations localizations,
    MaterialLocalizations material,
  ) {
    final ChoreOccurrenceHistoryState state = _state;
    if (state is ChoreOccurrenceHistoryInitial ||
        state is ChoreOccurrenceHistoryLoading) {
      return <Widget>[
        Semantics(
          key: const Key('chore.history.loading'),
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Column(
              children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text(
                  localizations.choreHistoryLoading,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ];
    }
    if (state is ChoreOccurrenceHistoryLoadFailed) {
      return <Widget>[
        Padding(
          key: const Key('chore.history.error'),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: <Widget>[
              const Icon(Icons.sync_problem_outlined, size: AppIconSize.status),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  localizations.choreHistoryLoadFailed,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('chore.history.retry'),
                onPressed: () => unawaited(_controller.retry()),
                icon: const Icon(Icons.refresh),
                label: Text(localizations.retryAction),
              ),
            ],
          ),
        ),
      ];
    }
    final ChoreOccurrenceHistoryReady ready =
        state as ChoreOccurrenceHistoryReady;
    if (ready.events.isEmpty) {
      return <Widget>[
        Padding(
          key: const Key('chore.history.empty'),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: <Widget>[
              const Icon(Icons.history_outlined, size: AppIconSize.status),
              const SizedBox(height: AppSpacing.md),
              Text(
                localizations.choreHistoryEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                localizations.choreHistoryEmptyBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ];
    }
    return <Widget>[
      Column(
        key: const Key('chore.history.list'),
        children: ready.events
            .map(
              (ChoreOccurrenceHistoryEvent event) =>
                  _historyEntry(localizations, material, event),
            )
            .toList(growable: false),
      ),
      if (ready.loadingMore)
        Semantics(
          key: const Key('chore.history.loadingMore'),
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox.square(
                  dimension: AppSpacing.lg,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(child: Text(localizations.choreHistoryLoadingMore)),
              ],
            ),
          ),
        )
      else if (ready.loadMoreFailure != null) ...<Widget>[
        Semantics(
          key: const Key('chore.history.loadMoreError'),
          liveRegion: true,
          child: Text(
            localizations.choreHistoryLoadMoreFailed,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: OutlinedButton.icon(
            key: const Key('chore.history.loadMoreRetry'),
            onPressed: () => unawaited(_controller.retry()),
            icon: const Icon(Icons.refresh),
            label: Text(localizations.retryAction),
          ),
        ),
      ] else if (ready.hasMore)
        Center(
          child: OutlinedButton.icon(
            key: const Key('chore.history.loadMore'),
            onPressed: () => unawaited(_controller.loadMore()),
            icon: const Icon(Icons.expand_more),
            label: Text(localizations.choreHistoryLoadMoreAction),
          ),
        ),
    ];
  }

  Widget _historyEntry(
    AppLocalizations localizations,
    MaterialLocalizations material,
    ChoreOccurrenceHistoryEvent event,
  ) {
    final DateTime occurredAt = event.occurredAt.toLocal();
    return ListTile(
      key: Key('chore.history.event.${event.id.value}'),
      contentPadding: EdgeInsets.zero,
      leading: Icon(_eventIcon(event.type)),
      title: Text(_eventMessage(localizations, material, event)),
      subtitle: Text(
        localizations.choreHistoryTimestamp(
          material.formatMediumDate(occurredAt),
          material.formatTimeOfDay(TimeOfDay.fromDateTime(occurredAt)),
        ),
      ),
    );
  }

  String _eventMessage(
    AppLocalizations localizations,
    MaterialLocalizations material,
    ChoreOccurrenceHistoryEvent event,
  ) {
    final String actorName = event.actingDisplayName == null
        ? event.actorDisplayName
        : localizations.choreHistoryActorActingAs(
            event.actorDisplayName,
            event.actingDisplayName!,
          );
    return switch (event.type) {
      ChoreOccurrenceHistoryEventType.completed =>
        localizations.choreHistoryCompleted(actorName),
      ChoreOccurrenceHistoryEventType.reopened =>
        localizations.choreHistoryReopened(actorName),
      ChoreOccurrenceHistoryEventType.skipped =>
        localizations.choreHistorySkipped(actorName),
      ChoreOccurrenceHistoryEventType.restored =>
        localizations.choreHistoryRestored(actorName),
      ChoreOccurrenceHistoryEventType.rescheduled =>
        localizations.choreHistoryRescheduled(
          actorName,
          _scheduleLabel(
            localizations,
            material,
            event.previousDueLocalDate!,
            event.previousDueLocalTime,
          ),
          _scheduleLabel(
            localizations,
            material,
            event.newDueLocalDate!,
            event.newDueLocalTime,
          ),
        ),
      ChoreOccurrenceHistoryEventType.reassigned =>
        localizations.choreHistoryReassigned(
          actorName,
          event.previousAssigneeDisplayName!,
          event.newAssigneeDisplayName!,
        ),
    };
  }

  String _scheduleLabel(
    AppLocalizations localizations,
    MaterialLocalizations material,
    ChoreLocalDate date,
    ChoreLocalTime? time,
  ) {
    final String timeLabel = time == null
        ? localizations.choreAllDayLabel
        : material.formatTimeOfDay(
            TimeOfDay(hour: time.hour, minute: time.minute),
          );
    return localizations.choreScheduleLabel(
      material.formatMediumDate(date.toDateTime()),
      timeLabel,
    );
  }

  IconData _eventIcon(ChoreOccurrenceHistoryEventType type) {
    return switch (type) {
      ChoreOccurrenceHistoryEventType.completed => Icons.check_circle_outline,
      ChoreOccurrenceHistoryEventType.reopened => Icons.undo,
      ChoreOccurrenceHistoryEventType.skipped => Icons.skip_next_outlined,
      ChoreOccurrenceHistoryEventType.restored => Icons.restore,
      ChoreOccurrenceHistoryEventType.rescheduled => Icons.schedule_outlined,
      ChoreOccurrenceHistoryEventType.reassigned => Icons.person_outline,
    };
  }
}
