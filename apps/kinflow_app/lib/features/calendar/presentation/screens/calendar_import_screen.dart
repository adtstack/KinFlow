import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/calendar/application/calendar_import_state.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_import.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/presentation/calendar_failure_message.dart';
import 'package:kinflow_app/features/calendar/presentation/calendar_import_route_context.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class CalendarImportScreen extends ConsumerStatefulWidget {
  const CalendarImportScreen({required this.routeContext, super.key});

  final CalendarImportRouteContext routeContext;

  @override
  ConsumerState<CalendarImportScreen> createState() =>
      _CalendarImportScreenState();
}

class _CalendarImportScreenState extends ConsumerState<CalendarImportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(householdMembersProvider.notifier)
            .load(widget.routeContext.householdId),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final CalendarImportState state = ref.watch(calendarImportProvider);
    final HouseholdMembersState rosterState = ref.watch(
      householdMembersProvider,
    );
    final bool mutationsBlocked = ref.watch(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    );
    ref.listen<CalendarImportState>(calendarImportProvider, (
      CalendarImportState? previous,
      CalendarImportState next,
    ) {
      if (next case CalendarImportCompleted(:final importedCount)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (context.canPop()) {
            context.pop(importedCount);
          } else {
            context.go(AppRoutes.calendar);
          }
        });
      }
    });
    final bool submitting = state is CalendarImportSubmitting;
    return PopScope(
      canPop: !submitting,
      child: AppResponsiveScaffold(
        key: const Key('calendarImport.screen'),
        title: localizations.calendarImportTitle,
        actions: <Widget>[
          IconButton(
            key: const Key('calendarImport.back'),
            onPressed: submitting
                ? null
                : () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.calendar),
            tooltip: localizations.calendarImportBackAction,
            icon: const Icon(Icons.close),
          ),
        ],
        body: _body(
          localizations,
          state,
          rosterState,
          mutationsBlocked: mutationsBlocked,
        ),
      ),
    );
  }

  Widget _body(
    AppLocalizations localizations,
    CalendarImportState state,
    HouseholdMembersState rosterState, {
    required bool mutationsBlocked,
  }) {
    return switch (state) {
      CalendarImportInitial() => _initial(
        localizations,
        rosterState,
        mutationsBlocked: mutationsBlocked,
      ),
      CalendarImportPicking() => ScrollableStatusLayout(
        child: Column(
          key: const Key('calendarImport.picking'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.calendarImportPickingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      CalendarImportLoadFailed(:final kind) => _loadFailed(
        localizations,
        rosterState,
        kind,
        mutationsBlocked: mutationsBlocked,
      ),
      CalendarImportReady(:final selection) => _preview(
        localizations,
        rosterState,
        selection,
        mutationsBlocked: mutationsBlocked,
      ),
      CalendarImportSubmitting(
        :final selection,
        :final completedCount,
        :final totalCount,
      ) =>
        _preview(
          localizations,
          rosterState,
          selection,
          mutationsBlocked: mutationsBlocked,
          progress: (completed: completedCount, total: totalCount),
        ),
      CalendarImportSubmissionFailed(
        :final selection,
        :final completedCount,
        :final totalCount,
        :final failure,
      ) =>
        _preview(
          localizations,
          rosterState,
          selection,
          mutationsBlocked: mutationsBlocked,
          submissionFailure: (
            completed: completedCount,
            total: totalCount,
            failure: failure,
          ),
        ),
      CalendarImportCompleted() => const ScrollableStatusLayout(
        child: CircularProgressIndicator(),
      ),
    };
  }

  Widget _initial(
    AppLocalizations localizations,
    HouseholdMembersState rosterState, {
    required bool mutationsBlocked,
  }) {
    return ScrollableStatusLayout(
      child: Column(
        key: const Key('calendarImport.initial'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.upload_file_outlined, size: AppIconSize.status),
          const SizedBox(height: AppSpacing.md),
          Text(localizations.calendarImportIntro, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            localizations.calendarImportCopyDisclosure,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('calendarImport.pick'),
            onPressed: mutationsBlocked ? null : _pickCallback(rosterState),
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_pickLabel(localizations, rosterState)),
          ),
        ],
      ),
    );
  }

  Widget _loadFailed(
    AppLocalizations localizations,
    HouseholdMembersState rosterState,
    CalendarImportLoadFailureKind kind, {
    required bool mutationsBlocked,
  }) {
    return ScrollableStatusLayout(
      child: Column(
        key: const Key('calendarImport.loadFailed'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.event_busy_outlined, size: AppIconSize.status),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              _loadFailureMessage(localizations, kind),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('calendarImport.pickAgain'),
            onPressed: mutationsBlocked ? null : _pickCallback(rosterState),
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_pickLabel(localizations, rosterState)),
          ),
        ],
      ),
    );
  }

  Widget _preview(
    AppLocalizations localizations,
    HouseholdMembersState rosterState,
    CalendarImportSelection selection, {
    required bool mutationsBlocked,
    ({int completed, int total})? progress,
    ({int completed, int total, CalendarFailure failure})? submissionFailure,
  }) {
    final HouseholdMemberRoster? roster = switch (rosterState) {
      HouseholdMembersReady(:final roster)
          when roster.householdId == widget.routeContext.householdId =>
        roster,
      _ => null,
    };
    final bool frozen = progress != null || submissionFailure != null;
    final bool hasFloating = selection.document.candidates.any(
      (CalendarImportCandidate candidate) => candidate.usesHouseholdTimeZone,
    );
    final bool hasOverlap = selection.document.candidates.any(
      (CalendarImportCandidate candidate) => candidate.usesOverlapEarlier,
    );
    return ListView(
      key: const Key('calendarImport.preview'),
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
                _summaryCard(localizations, selection),
                if (hasFloating) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _infoCard(
                    key: const Key('calendarImport.floatingDisclosure'),
                    icon: Icons.schedule_outlined,
                    text: localizations.calendarImportFloatingDisclosure(
                      selection.householdTimeZone.value,
                    ),
                  ),
                ],
                if (hasOverlap) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _infoCard(
                    key: const Key('calendarImport.overlapDisclosure'),
                    icon: Icons.more_time_outlined,
                    text: localizations.calendarImportOverlapDisclosure,
                  ),
                ],
                if (progress != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  LinearProgressIndicator(
                    value: progress.total == 0
                        ? null
                        : progress.completed / progress.total,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      localizations.calendarImportProgress(
                        progress.completed,
                        progress.total,
                      ),
                    ),
                  ),
                ],
                if (submissionFailure != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _failureCard(
                    localizations,
                    submissionFailure.completed,
                    submissionFailure.total,
                    submissionFailure.failure,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  localizations.calendarImportEventsHeading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.calendarImportSelectedCount(
                    selection.selectedSourceIndexes.length,
                    selection.document.candidates.length,
                  ),
                ),
                if (selection.document.candidates.isEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _infoCard(
                    key: const Key('calendarImport.noSupported'),
                    icon: Icons.event_busy_outlined,
                    text: localizations.calendarImportNoSupportedEvents,
                  ),
                ] else
                  for (final CalendarImportCandidate candidate
                      in selection.document.candidates) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _candidateTile(
                      localizations,
                      candidate,
                      selected: selection.selectedSourceIndexes.contains(
                        candidate.sourceIndex,
                      ),
                      enabled: !frozen && !mutationsBlocked,
                    ),
                  ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  localizations.calendarImportParticipantsHeading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(localizations.calendarImportParticipantsHelper),
                const SizedBox(height: AppSpacing.sm),
                if (roster == null)
                  _rosterStatus(localizations, rosterState)
                else
                  Card(
                    child: Column(
                      children: <Widget>[
                        for (final HouseholdMember member in roster.members)
                          CheckboxListTile(
                            key: Key(
                              'calendarImport.participant.${member.id.value}',
                            ),
                            value: selection.participantMemberIds.contains(
                              member.id,
                            ),
                            onChanged: frozen || mutationsBlocked
                                ? null
                                : (_) => ref
                                      .read(calendarImportProvider.notifier)
                                      .toggleParticipant(member.id),
                            title: Text(member.displayName),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.lg),
                if (submissionFailure != null)
                  FilledButton.icon(
                    key: const Key('calendarImport.retry'),
                    onPressed: mutationsBlocked
                        ? null
                        : () => unawaited(
                            ref
                                .read(calendarImportProvider.notifier)
                                .retryImport(),
                          ),
                    icon: const Icon(Icons.refresh),
                    label: Text(localizations.calendarImportRetryAction),
                  )
                else
                  FilledButton.icon(
                    key: const Key('calendarImport.submit'),
                    onPressed:
                        frozen ||
                            mutationsBlocked ||
                            roster == null ||
                            !selection.canImport
                        ? null
                        : () => unawaited(
                            ref
                                .read(calendarImportProvider.notifier)
                                .importSelected(),
                          ),
                    icon: const Icon(Icons.content_copy_outlined),
                    label: Text(
                      localizations.calendarImportSubmitAction(
                        selection.selectedSourceIndexes.length,
                      ),
                    ),
                  ),
                if (!frozen) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    key: const Key('calendarImport.chooseAnother'),
                    onPressed: mutationsBlocked
                        ? null
                        : _pickCallback(rosterState),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: Text(
                      localizations.calendarImportChooseAnotherAction,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
    AppLocalizations localizations,
    CalendarImportSelection selection,
  ) {
    final CalendarImportDocument document = selection.document;
    return Card(
      key: const Key('calendarImport.summary'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              selection.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.calendarImportSupportedCount(
                document.candidates.length,
              ),
            ),
            Text(
              localizations.calendarImportSkippedCount(
                document.skippedEventCount,
              ),
            ),
            if (document.skippedEventCount > 0)
              Text(
                localizations.calendarImportSkippedDetails(
                  document.invalidEventCount,
                  document.unsupportedEventCount,
                  document.duplicateEventCount,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.calendarImportCopyDisclosure),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.calendarImportIgnoredFieldsDisclosure),
          ],
        ),
      ),
    );
  }

  Widget _candidateTile(
    AppLocalizations localizations,
    CalendarImportCandidate candidate, {
    required bool selected,
    required bool enabled,
  }) {
    return Card(
      child: CheckboxListTile(
        key: Key('calendarImport.event.${candidate.sourceIndex}'),
        value: selected,
        onChanged: enabled
            ? (_) => ref
                  .read(calendarImportProvider.notifier)
                  .toggleCandidate(candidate.sourceIndex)
            : null,
        title: Text(candidate.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_candidateSummary(localizations, candidate)),
            if (candidate.description != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                candidate.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        isThreeLine:
            candidate.recurrenceRule != null || candidate.description != null,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _failureCard(
    AppLocalizations localizations,
    int completed,
    int total,
    CalendarFailure failure,
  ) {
    return Card(
      key: const Key('calendarImport.submissionFailed'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                localizations.calendarImportPartialFailure(completed, total),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(calendarFailureMessage(localizations, failure)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required Key key,
    required IconData icon,
    required String text,
  }) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }

  Widget _rosterStatus(
    AppLocalizations localizations,
    HouseholdMembersState state,
  ) {
    if (state is HouseholdMembersLoadFailed) {
      return Text(
        localizations.calendarRosterError,
        key: const Key('calendarImport.rosterError'),
      );
    }
    return Row(
      key: const Key('calendarImport.rosterLoading'),
      children: <Widget>[
        const SizedBox.square(
          dimension: AppIconSize.inline,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(localizations.calendarImportRosterLoading)),
      ],
    );
  }

  VoidCallback? _pickCallback(HouseholdMembersState rosterState) {
    final HouseholdMemberRoster? roster = switch (rosterState) {
      HouseholdMembersReady(:final roster)
          when roster.householdId == widget.routeContext.householdId =>
        roster,
      _ => null,
    };
    if (roster == null) return null;
    return () => unawaited(
      ref
          .read(calendarImportProvider.notifier)
          .pickFile(
            householdId: widget.routeContext.householdId,
            householdTimeZone: widget.routeContext.householdTimeZone,
            currentMemberId: roster.currentMember.id,
            availableParticipantIds: roster.members.map(
              (HouseholdMember member) => member.id,
            ),
          ),
    );
  }

  String _pickLabel(
    AppLocalizations localizations,
    HouseholdMembersState rosterState,
  ) {
    return switch (rosterState) {
      HouseholdMembersLoadFailed() => localizations.calendarRosterError,
      HouseholdMembersReady(:final roster)
          when roster.householdId == widget.routeContext.householdId =>
        localizations.calendarImportChooseFileAction,
      _ => localizations.calendarImportRosterLoading,
    };
  }

  String _candidateSummary(
    AppLocalizations localizations,
    CalendarImportCandidate candidate,
  ) {
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final DateFormat dateFormat = DateFormat.yMMMd(locale);
    final String startDate = dateFormat.format(
      candidate.localStartDate.toUtcCalendarDate(),
    );
    final String temporal;
    if (candidate.isAllDay) {
      final String inclusiveEnd = dateFormat.format(
        candidate.allDayEndDateExclusive!.addDays(-1).toUtcCalendarDate(),
      );
      temporal = localizations.calendarImportAllDayRange(
        startDate,
        inclusiveEnd,
      );
    } else {
      final String time = TimeOfDay(
        hour: candidate.localStartTime!.hour,
        minute: candidate.localStartTime!.minute,
      ).format(context);
      temporal = localizations.calendarImportTimedSummary(
        startDate,
        time,
        localizations.calendarDurationMinutes(candidate.durationMinutes!),
        candidate.timeZone!.value,
      );
    }
    final CalendarRecurrenceRule? rule = candidate.recurrenceRule;
    if (rule == null) return temporal;
    final String pattern = switch (rule.frequency) {
      CalendarRecurrenceFrequency.daily =>
        localizations.calendarRecurrenceEveryDays(rule.interval),
      CalendarRecurrenceFrequency.weekly =>
        localizations.calendarRecurrenceEveryWeeks(rule.interval),
      CalendarRecurrenceFrequency.monthly =>
        localizations.calendarRecurrenceEveryMonths(rule.interval),
    };
    final String end = switch (rule.end) {
      CalendarRecurrenceNeverEnds() =>
        localizations.calendarRecurrenceEndNeverSummary,
      CalendarRecurrenceCountEnd(:final count) =>
        localizations.calendarRecurrenceEndCountSummary(count),
      CalendarRecurrenceUntilEnd(:final localDate) =>
        localizations.calendarRecurrenceEndUntilSummary(
          dateFormat.format(localDate.toUtcCalendarDate()),
        ),
    };
    return '$temporal\n$pattern · $end';
  }

  String _loadFailureMessage(
    AppLocalizations localizations,
    CalendarImportLoadFailureKind kind,
  ) {
    return switch (kind) {
      CalendarImportLoadFailureKind.pickerUnavailable =>
        localizations.calendarImportPickerUnavailableError,
      CalendarImportLoadFailureKind.pickerFailed =>
        localizations.calendarImportPickerFailedError,
      CalendarImportLoadFailureKind.invalidFile =>
        localizations.calendarImportInvalidFileError,
      CalendarImportLoadFailureKind.unsupportedVersion =>
        localizations.calendarImportUnsupportedVersionError,
      CalendarImportLoadFailureKind.tooLarge =>
        localizations.calendarImportTooLargeError,
      CalendarImportLoadFailureKind.tooManyEvents =>
        localizations.calendarImportTooManyEventsError,
    };
  }
}
