import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/calendar/application/calendar_import_controller.dart';
import 'package:kinflow_app/features/calendar/application/calendar_import_state.dart';
import 'package:kinflow_app/features/calendar/application/calendar_events_controller.dart';
import 'package:kinflow_app/features/calendar/application/calendar_events_state.dart';
import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/application/unavailable_calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_event_requests.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_overlap_preview.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_recurrence.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_view_query.dart';
import 'package:kinflow_app/features/calendar/domain/entities/one_time_calendar_event.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/domain/services/calendar_time_resolver.dart';
import 'package:kinflow_app/features/calendar/domain/services/icalendar_import_parser.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_time_primitives.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  throw StateError('CalendarRepository override is required.');
});

final calendarCommandIdGeneratorProvider = Provider<CalendarCommandIdGenerator>(
  (ref) {
    throw StateError('CalendarCommandIdGenerator override is required.');
  },
);

final calendarTimeResolverProvider = Provider<CalendarTimeResolver>((ref) {
  throw StateError('CalendarTimeResolver override is required.');
});

final calendarSyncRepositoryProvider = Provider<CalendarSyncRepository?>(
  (ref) => null,
);

final calendarImportFileGatewayProvider = Provider<CalendarImportFileGateway>(
  (ref) => const UnavailableCalendarImportFileGateway(),
);

final calendarImportControllerProvider =
    Provider.autoDispose<CalendarImportController>((ref) {
      final CalendarImportController controller = CalendarImportController(
        fileGateway: ref.watch(calendarImportFileGatewayProvider),
        parser: IcalendarImportParser(ref.watch(calendarTimeResolverProvider)),
        repository: ref.watch(calendarRepositoryProvider),
        idGenerator: ref.watch(calendarCommandIdGeneratorProvider),
        mutationsBlocked: () => ref.read(
          appRuntimePolicyFeatureMutationsBlockedProvider(
            AppRuntimeFeature.calendar,
          ),
        ),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final calendarImportProvider =
    NotifierProvider.autoDispose<CalendarImportNotifier, CalendarImportState>(
      CalendarImportNotifier.new,
    );

final class CalendarImportNotifier extends Notifier<CalendarImportState> {
  @override
  CalendarImportState build() {
    final CalendarImportController controller = ref.watch(
      calendarImportControllerProvider,
    );
    final StreamSubscription<CalendarImportState> subscription = controller
        .states
        .listen((CalendarImportState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  bool get _mutationsBlocked => ref.read(
    appRuntimePolicyFeatureMutationsBlockedProvider(AppRuntimeFeature.calendar),
  );

  Future<void> pickFile({
    required HouseholdId householdId,
    required IanaTimeZoneId householdTimeZone,
    required HouseholdMemberId currentMemberId,
    required Iterable<HouseholdMemberId> availableParticipantIds,
  }) {
    if (_mutationsBlocked) return Future<void>.value();
    return ref
        .read(calendarImportControllerProvider)
        .pickFile(
          householdId: householdId,
          householdTimeZone: householdTimeZone,
          currentMemberId: currentMemberId,
          availableParticipantIds: availableParticipantIds,
        );
  }

  void toggleCandidate(int sourceIndex) {
    ref.read(calendarImportControllerProvider).toggleCandidate(sourceIndex);
  }

  void toggleParticipant(HouseholdMemberId participantId) {
    ref.read(calendarImportControllerProvider).toggleParticipant(participantId);
  }

  Future<void> importSelected() {
    if (_mutationsBlocked) return Future<void>.value();
    return ref.read(calendarImportControllerProvider).importSelected();
  }

  Future<void> retryImport() {
    if (_mutationsBlocked) return Future<void>.value();
    return ref.read(calendarImportControllerProvider).retryImport();
  }

  void reset() {
    ref.read(calendarImportControllerProvider).reset();
  }
}

final calendarEventsControllerProvider =
    Provider.autoDispose<CalendarEventsController>((ref) {
      final CalendarEventsController controller = CalendarEventsController(
        repository: ref.watch(calendarRepositoryProvider),
        idGenerator: ref.watch(calendarCommandIdGeneratorProvider),
        timeResolver: ref.watch(calendarTimeResolverProvider),
        syncRepository: ref.watch(calendarSyncRepositoryProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final calendarEventsProvider =
    NotifierProvider.autoDispose<CalendarEventsNotifier, CalendarEventsState>(
      CalendarEventsNotifier.new,
    );

final class CalendarEventsNotifier extends Notifier<CalendarEventsState> {
  @override
  CalendarEventsState build() {
    final CalendarEventsController controller = ref.watch(
      calendarEventsControllerProvider,
    );
    final StreamSubscription<CalendarEventsState> subscription = controller
        .states
        .listen((CalendarEventsState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load(HouseholdId householdId) {
    return ref.read(calendarEventsControllerProvider).load(householdId);
  }

  Future<PreviewCalendarOverlapsResult> previewOverlaps(
    CalendarOverlapPreviewRequest request,
  ) {
    return ref.read(calendarEventsControllerProvider).previewOverlaps(request);
  }

  Future<void> refresh() {
    return ref.read(calendarEventsControllerProvider).refresh();
  }

  Future<void> resume() {
    return ref.read(calendarEventsControllerProvider).resume();
  }

  Future<void> reconnect() {
    return ref.read(calendarEventsControllerProvider).reconnect();
  }

  Future<void> openOccurrence(
    HouseholdId householdId,
    CalendarEventOccurrenceId occurrenceId,
  ) {
    return ref
        .read(calendarEventsControllerProvider)
        .openOccurrence(householdId, occurrenceId);
  }

  Future<void> setView(CalendarViewMode viewMode) {
    return ref.read(calendarEventsControllerProvider).setView(viewMode);
  }

  Future<void> shiftRange(int delta) {
    return ref.read(calendarEventsControllerProvider).shiftRange(delta);
  }

  Future<void> goToToday() {
    return ref.read(calendarEventsControllerProvider).goToToday();
  }

  Future<void> selectMonthDate(CalendarLocalDate date) {
    return ref.read(calendarEventsControllerProvider).selectMonthDate(date);
  }

  Future<void> loadMore() {
    return ref.read(calendarEventsControllerProvider).loadMore();
  }

  Future<void> create(OneTimeCalendarEventDraft draft) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(calendarEventsControllerProvider).create(draft);
  }

  Future<void> createRecurring(RecurringCalendarEventDraft draft) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(calendarEventsControllerProvider).createRecurring(draft);
  }

  Future<RecurringCalendarSeriesDetail?> loadSeriesForEdit(
    OneTimeCalendarEvent current,
  ) {
    return ref
        .read(calendarEventsControllerProvider)
        .loadSeriesForEdit(current);
  }

  Future<void> updateSeries({
    required RecurringCalendarSeriesDetail current,
    required RecurringCalendarEventDraft draft,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(calendarEventsControllerProvider)
        .updateSeries(current: current, draft: draft);
  }

  Future<void> updateSeriesFromOccurrence({
    required OneTimeCalendarEvent current,
    required RecurringCalendarSeriesDetail series,
    required RecurringCalendarEventDraft draft,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(calendarEventsControllerProvider)
        .updateSeriesFromOccurrence(
          current: current,
          series: series,
          draft: draft,
        );
  }

  Future<void> cancelSeries(OneTimeCalendarEvent current) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(calendarEventsControllerProvider).cancelSeries(current);
  }

  Future<void> cancelSeriesFromOccurrence({
    required OneTimeCalendarEvent current,
    required RecurringCalendarSeriesDetail series,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(calendarEventsControllerProvider)
        .cancelSeriesFromOccurrence(current: current, series: series);
  }

  Future<void> resumeSeriesCancellation({
    required HouseholdId householdId,
    required CalendarEventSeriesId seriesId,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(calendarEventsControllerProvider)
        .resumeSeriesCancellation(householdId: householdId, seriesId: seriesId);
  }

  Future<void> update({
    required OneTimeCalendarEvent current,
    required OneTimeCalendarEventDraft draft,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(calendarEventsControllerProvider)
        .update(current: current, draft: draft);
  }

  Future<void> delete(OneTimeCalendarEvent current) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(calendarEventsControllerProvider).delete(current);
  }

  Future<void> updateOccurrence({
    required OneTimeCalendarEvent current,
    required OneTimeCalendarEventDraft draft,
  }) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref
        .read(calendarEventsControllerProvider)
        .updateOccurrence(current: current, draft: draft);
  }

  Future<void> cancelOccurrence(OneTimeCalendarEvent current) {
    if (ref.read(
      appRuntimePolicyFeatureMutationsBlockedProvider(
        AppRuntimeFeature.calendar,
      ),
    )) {
      return Future<void>.value();
    }
    return ref.read(calendarEventsControllerProvider).cancelOccurrence(current);
  }
}
