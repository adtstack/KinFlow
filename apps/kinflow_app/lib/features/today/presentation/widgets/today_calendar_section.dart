import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/calendar/presentation/calendar_failure_message.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/today/application/today_calendar_state.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

enum TodayCalendarSectionKind { all, nowAndNext, remaining }

class TodayCalendarSection extends StatelessWidget {
  const TodayCalendarSection({
    required this.state,
    required this.chores,
    required this.onRetry,
    required this.onReconnect,
    required this.onOpenCalendar,
    required this.onOpenEvent,
    this.sectionKind = TodayCalendarSectionKind.all,
    this.showSourceStatus = true,
    this.showOpenCalendar = true,
    this.hideWhenEmpty = false,
    super.key,
  });

  final TodayCalendarState state;
  final TodayChores? chores;
  final VoidCallback onRetry;
  final VoidCallback onReconnect;
  final VoidCallback onOpenCalendar;
  final ValueChanged<CalendarEventOccurrenceId> onOpenEvent;
  final TodayCalendarSectionKind sectionKind;
  final bool showSourceStatus;
  final bool showOpenCalendar;
  final bool hideWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return switch (state) {
      TodayCalendarInitial() ||
      TodayCalendarLoading() when !showSourceStatus => const SizedBox.shrink(),
      TodayCalendarInitial() || TodayCalendarLoading() => Column(
        key: const Key('today.calendar.loading'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _heading(context, localizations, null),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            label: localizations.todayCalendarLoadingLabel,
            child: const LinearProgressIndicator(),
          ),
        ],
      ),
      TodayCalendarLoadFailed() when !showSourceStatus =>
        const SizedBox.shrink(),
      TodayCalendarLoadFailed(:final failure) => _failure(
        context,
        localizations,
        failure,
      ),
      TodayCalendarReady(:final snapshot)
          when chores != null &&
              !TodaySnapshot.hasMatchingCalendarContext(
                chores: chores!,
                calendar: snapshot,
              ) &&
              !showSourceStatus =>
        const SizedBox.shrink(),
      TodayCalendarReady(:final snapshot)
          when chores != null &&
              !TodaySnapshot.hasMatchingCalendarContext(
                chores: chores!,
                calendar: snapshot,
              ) =>
        _failure(
          context,
          localizations,
          const CalendarFailure(CalendarFailureKind.invalidPayload),
        ),
      TodayCalendarReady(
        :final snapshot,
        :final refreshing,
        :final refreshFailure,
        :final syncStatus,
        :final cacheMetadata,
      ) =>
        _ready(
          context,
          localizations,
          snapshot,
          refreshing: refreshing,
          refreshFailure: refreshFailure,
          syncStatus: syncStatus,
          cacheMetadata: cacheMetadata,
        ),
    };
  }

  Widget _ready(
    BuildContext context,
    AppLocalizations localizations,
    TodayCalendarSnapshot snapshot, {
    required bool refreshing,
    required CalendarFailure? refreshFailure,
    required CalendarSyncConnectionStatus syncStatus,
    required ReadCacheMetadata? cacheMetadata,
  }) {
    final List<CalendarEventProjection> events = switch (sectionKind) {
      TodayCalendarSectionKind.all => snapshot.events,
      TodayCalendarSectionKind.nowAndNext => snapshot.nowAndNextEvents,
      TodayCalendarSectionKind.remaining => snapshot.remainingEvents,
    };
    final bool hasVisibleSourceStatus =
        showSourceStatus &&
        (refreshing ||
            cacheMetadata != null ||
            refreshFailure != null ||
            syncStatus == CalendarSyncConnectionStatus.disconnected ||
            snapshot.truncated);
    if (events.isEmpty &&
        (sectionKind == TodayCalendarSectionKind.remaining ||
            hideWhenEmpty && !hasVisibleSourceStatus)) {
      return const SizedBox.shrink();
    }
    return Column(
      key: _sectionKey('ready'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(context, localizations, events.length),
        if (showSourceStatus && refreshing) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            label: localizations.todayCalendarRefreshingLabel,
            child: const LinearProgressIndicator(
              key: Key('today.calendar.refreshing'),
            ),
          ),
        ] else if (showSourceStatus && cacheMetadata != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _statusBanner(
            context,
            key: const Key('today.calendar.offlineCache'),
            icon: Icons.cloud_off_outlined,
            message: localizations.todayCalendarOfflineMessage(
              _syncLabel(context, cacheMetadata.validatedAt),
            ),
            detail: localizations.todayCalendarOfflineReadOnlyHint,
            onRetry: onRetry,
          ),
        ] else if (showSourceStatus && refreshFailure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _statusBanner(
            context,
            key: const Key('today.calendar.stale'),
            icon: Icons.cloud_off_outlined,
            message: localizations.todayCalendarStaleMessage(
              _syncLabel(context, snapshot.generatedAt.dateTime),
            ),
            onRetry: onRetry,
          ),
        ] else if (showSourceStatus &&
            syncStatus ==
                CalendarSyncConnectionStatus.disconnected) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _statusBanner(
            context,
            key: const Key('today.calendar.sync.disconnected'),
            icon: Icons.cloud_off_outlined,
            message: localizations.calendarLiveDisconnectedMessage,
            onRetry: onReconnect,
            retryLabel: localizations.calendarReconnectAction,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (events.isEmpty)
          Text(localizations.todayCalendarEmptyLabel, key: _sectionKey('empty'))
        else
          ...events.map(
            (CalendarEventProjection projection) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _eventCard(context, localizations, snapshot, projection),
            ),
          ),
        if (showSourceStatus && snapshot.truncated) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          _statusBanner(
            context,
            key: const Key('today.calendar.truncated'),
            icon: Icons.info_outline,
            message: localizations.todayCalendarTruncatedMessage,
          ),
        ],
      ],
    );
  }

  Widget _heading(
    BuildContext context,
    AppLocalizations localizations,
    int? count,
  ) {
    final String title = switch (sectionKind) {
      TodayCalendarSectionKind.all => localizations.todayCalendarSectionTitle,
      TodayCalendarSectionKind.nowAndNext =>
        localizations.todayNowAndNextSectionTitle,
      TodayCalendarSectionKind.remaining =>
        localizations.todayRemainingEventsSectionTitle,
    };
    return Row(
      children: <Widget>[
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              key: _sectionKey('heading'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        if (count != null)
          Flexible(
            child: Text(
              localizations.todayCalendarEventCount(count),
              key: const Key('today.calendar.count'),
              textAlign: TextAlign.end,
            ),
          ),
        if (showOpenCalendar)
          IconButton(
            key: const Key('today.calendar.open'),
            onPressed: onOpenCalendar,
            tooltip: localizations.todayOpenCalendarAction,
            icon: const Icon(Icons.arrow_forward),
          ),
      ],
    );
  }

  Widget _failure(
    BuildContext context,
    AppLocalizations localizations,
    CalendarFailure failure,
  ) {
    return Column(
      key: const Key('today.calendar.error'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(context, localizations, null),
        const SizedBox(height: AppSpacing.sm),
        _statusBanner(
          context,
          key: const Key('today.calendar.error.banner'),
          icon: Icons.event_busy_outlined,
          message: calendarFailureMessage(localizations, failure),
          onRetry: onRetry,
        ),
      ],
    );
  }

  Widget _eventCard(
    BuildContext context,
    AppLocalizations localizations,
    TodayCalendarSnapshot snapshot,
    CalendarEventProjection projection,
  ) {
    final OneTimeCalendarEvent event = projection.event;
    final String schedule = _scheduleLabel(
      context,
      localizations,
      snapshot,
      projection,
    );
    final String participants = localizations.calendarParticipantSummary(
      event.participants
          .map(
            (CalendarEventParticipant participant) => participant.displayName,
          )
          .join(', '),
    );
    return Semantics(
      container: true,
      button: true,
      label: localizations.todayCalendarEventSemantics(
        event.title,
        schedule,
        participants,
      ),
      hint: localizations.todayOpenCalendarAction,
      child: Card(
        key: Key('today.event.${event.occurrenceId.value}'),
        child: ListTile(
          onTap: () => onOpenEvent(event.occurrenceId),
          leading: CircleAvatar(
            child: Icon(
              event.isAllDay
                  ? Icons.event_available_outlined
                  : Icons.schedule_outlined,
            ),
          ),
          title: Text(event.title),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(schedule),
              Text(participants),
              if (event.isRecurring)
                Text(
                  localizations.calendarRecurrenceSummary(
                    _recurrenceLabel(
                      localizations,
                      event.recurrenceRule!.frequency,
                    ),
                  ),
                ),
              if (event.isException)
                Text(localizations.calendarOccurrenceModifiedLabel),
              if (event.description != null)
                Text(
                  event.description!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          isThreeLine: true,
        ),
      ),
    );
  }

  String _scheduleLabel(
    BuildContext context,
    AppLocalizations localizations,
    TodayCalendarSnapshot snapshot,
    CalendarEventProjection projection,
  ) {
    final OneTimeCalendarEvent event = projection.event;
    if (event.isAllDay) {
      return localizations.calendarAllDayChip;
    }
    final UtcInstant generatedAt = snapshot.generatedAt;
    if (event.startsAt!.compareTo(generatedAt) <= 0 &&
        event.endsAt!.compareTo(generatedAt) > 0) {
      return localizations.todayCalendarHappeningNowLabel;
    }
    final CalendarLocalTime time = projection.viewLocalTime!;
    return MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay(hour: time.hour, minute: time.minute));
  }

  String _recurrenceLabel(
    AppLocalizations localizations,
    CalendarRecurrenceFrequency frequency,
  ) {
    return switch (frequency) {
      CalendarRecurrenceFrequency.daily =>
        localizations.calendarRecurrenceDaily,
      CalendarRecurrenceFrequency.weekly =>
        localizations.calendarRecurrenceWeekly,
      CalendarRecurrenceFrequency.monthly =>
        localizations.calendarRecurrenceMonthly,
    };
  }

  Widget _statusBanner(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String message,
    String? detail,
    VoidCallback? onRetry,
    String? retryLabel,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: key,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ExcludeSemantics(child: Icon(icon)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(liveRegion: true, child: Text(message)),
              ),
            ],
          ),
          if (detail != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(detail),
          ],
          if (onRetry != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const Key('today.calendar.retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(
                retryLabel ?? AppLocalizations.of(context).retryAction,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _syncLabel(BuildContext context, DateTime generatedAt) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final DateTime local = generatedAt.toLocal();
    return '${material.formatShortDate(local)} '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  Key _sectionKey(String suffix) {
    final String prefix = sectionKind == TodayCalendarSectionKind.all
        ? 'today.calendar'
        : 'today.calendar.${sectionKind.name}';
    return Key('$prefix.$suffix');
  }
}
