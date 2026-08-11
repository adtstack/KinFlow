import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence.dart';
import 'package:kinflow_app/features/chores/application/guided_chore_setup_resume_store.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_list_query.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reassignment_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_restore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_reschedule_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_skip_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_activation_progress.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/entities/guided_chore_setup.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_completion_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_change.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/entities/recurring_chore_request.dart';
import 'package:kinflow_app/features/chores/domain/entities/repeating_chore_series_change.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class FakeChoreRepository implements ChoreRepository {
  FakeChoreRepository({
    TodayChores? today,
    this.loadCallback,
    this.activationProgressCallback,
    this.weeklyReportCallback,
    this.listCallback,
    this.occurrenceTargetCallback,
    this.historyCallback,
    this.deletedOneTimeChoresCallback,
    this.createCallback,
    this.oneTimeUpdateCallback,
    this.oneTimeDeletionCallback,
    this.oneTimeRestoreCallback,
    this.completionCallback,
    this.recurringCallback,
    this.skipCallback,
    this.restoreCallback,
    this.rescheduleCallback,
    this.reassignmentCallback,
    this.seriesUpdateCallback,
    this.seriesFromOccurrenceUpdateCallback,
    this.seriesCancellationCallback,
    this.seriesFromOccurrenceCancellationCallback,
    this.seriesCancellationResumeCallback,
    this.reassignmentDisplayName = 'Sam',
    List<LoadTodayChoresResult> loadResults = const <LoadTodayChoresResult>[],
    List<LoadHouseholdActivationProgressResult> activationProgressResults =
        const <LoadHouseholdActivationProgressResult>[],
    List<LoadHouseholdWeeklyReportResult> weeklyReportResults =
        const <LoadHouseholdWeeklyReportResult>[],
    List<LoadChoreOccurrenceTargetResult> occurrenceTargetResults =
        const <LoadChoreOccurrenceTargetResult>[],
    List<LoadChoreOccurrenceHistoryResult> historyResults =
        const <LoadChoreOccurrenceHistoryResult>[],
    List<LoadDeletedOneTimeChoresResult> deletedOneTimeChoresResults =
        const <LoadDeletedOneTimeChoresResult>[],
    List<CreateOneTimeChoreResult> createResults =
        const <CreateOneTimeChoreResult>[],
    List<UpdateOneTimeChoreResult> oneTimeUpdateResults =
        const <UpdateOneTimeChoreResult>[],
    List<DeleteOneTimeChoreResult> oneTimeDeletionResults =
        const <DeleteOneTimeChoreResult>[],
    List<RestoreOneTimeChoreResult> oneTimeRestoreResults =
        const <RestoreOneTimeChoreResult>[],
    List<SetChoreCompletionResult> completionResults =
        const <SetChoreCompletionResult>[],
    List<CreateRecurringChoreResult> recurringResults =
        const <CreateRecurringChoreResult>[],
    List<SkipChoreOccurrenceResult> skipResults =
        const <SkipChoreOccurrenceResult>[],
    List<RestoreSkippedChoreOccurrenceResult> restoreResults =
        const <RestoreSkippedChoreOccurrenceResult>[],
    List<RescheduleChoreOccurrenceResult> rescheduleResults =
        const <RescheduleChoreOccurrenceResult>[],
    List<ReassignChoreOccurrenceResult> reassignmentResults =
        const <ReassignChoreOccurrenceResult>[],
    List<UpdateRepeatingChoreSeriesResult> seriesUpdateResults =
        const <UpdateRepeatingChoreSeriesResult>[],
    List<UpdateRepeatingChoreSeriesResult> seriesFromOccurrenceUpdateResults =
        const <UpdateRepeatingChoreSeriesResult>[],
    List<CancelRepeatingChoreSeriesResult> seriesCancellationResults =
        const <CancelRepeatingChoreSeriesResult>[],
    List<CancelRepeatingChoreSeriesFromOccurrenceResult>
        seriesFromOccurrenceCancellationResults =
        const <CancelRepeatingChoreSeriesFromOccurrenceResult>[],
    List<ResumeRepeatingChoreSeriesCancellationResult>
        seriesCancellationResumeResults =
        const <ResumeRepeatingChoreSeriesCancellationResult>[],
  }) : defaultToday = today ?? todayChoresFixture(),
       _loadResults = List<LoadTodayChoresResult>.of(loadResults),
       _activationProgressResults =
           List<LoadHouseholdActivationProgressResult>.of(
             activationProgressResults,
           ),
       _weeklyReportResults = List<LoadHouseholdWeeklyReportResult>.of(
         weeklyReportResults,
       ),
       _occurrenceTargetResults = List<LoadChoreOccurrenceTargetResult>.of(
         occurrenceTargetResults,
       ),
       _historyResults = List<LoadChoreOccurrenceHistoryResult>.of(
         historyResults,
       ),
       _deletedOneTimeChoresResults = List<LoadDeletedOneTimeChoresResult>.of(
         deletedOneTimeChoresResults,
       ),
       _createResults = List<CreateOneTimeChoreResult>.of(createResults),
       _oneTimeUpdateResults = List<UpdateOneTimeChoreResult>.of(
         oneTimeUpdateResults,
       ),
       _oneTimeDeletionResults = List<DeleteOneTimeChoreResult>.of(
         oneTimeDeletionResults,
       ),
       _oneTimeRestoreResults = List<RestoreOneTimeChoreResult>.of(
         oneTimeRestoreResults,
       ),
       _completionResults = List<SetChoreCompletionResult>.of(
         completionResults,
       ),
       _recurringResults = List<CreateRecurringChoreResult>.of(
         recurringResults,
       ),
       _skipResults = List<SkipChoreOccurrenceResult>.of(skipResults),
       _restoreResults = List<RestoreSkippedChoreOccurrenceResult>.of(
         restoreResults,
       ),
       _rescheduleResults = List<RescheduleChoreOccurrenceResult>.of(
         rescheduleResults,
       ),
       _reassignmentResults = List<ReassignChoreOccurrenceResult>.of(
         reassignmentResults,
       ),
       _seriesUpdateResults = List<UpdateRepeatingChoreSeriesResult>.of(
         seriesUpdateResults,
       ),
       _seriesFromOccurrenceUpdateResults =
           List<UpdateRepeatingChoreSeriesResult>.of(
             seriesFromOccurrenceUpdateResults,
           ),
       _seriesCancellationResults = List<CancelRepeatingChoreSeriesResult>.of(
         seriesCancellationResults,
       ),
       _seriesFromOccurrenceCancellationResults =
           List<CancelRepeatingChoreSeriesFromOccurrenceResult>.of(
             seriesFromOccurrenceCancellationResults,
           ),
       _seriesCancellationResumeResults =
           List<ResumeRepeatingChoreSeriesCancellationResult>.of(
             seriesCancellationResumeResults,
           );

  final TodayChores defaultToday;
  final Future<LoadTodayChoresResult> Function(HouseholdId householdId)?
  loadCallback;
  final Future<LoadHouseholdActivationProgressResult> Function(
    HouseholdId householdId,
  )?
  activationProgressCallback;
  final Future<LoadHouseholdWeeklyReportResult> Function(
    HouseholdWeeklyReportRequest request,
  )?
  weeklyReportCallback;
  final Future<LoadTodayChoresResult> Function(ChoreListRequest request)?
  listCallback;
  final Future<LoadChoreOccurrenceTargetResult> Function(
    HouseholdId householdId,
    ChoreOccurrenceId occurrenceId,
  )?
  occurrenceTargetCallback;
  final Future<LoadChoreOccurrenceHistoryResult> Function(
    ChoreOccurrenceHistoryRequest request,
  )?
  historyCallback;
  final Future<LoadDeletedOneTimeChoresResult> Function(
    DeletedOneTimeChoreListRequest request,
  )?
  deletedOneTimeChoresCallback;
  final Future<CreateOneTimeChoreResult> Function(
    CreateOneTimeChoreRequest request,
  )?
  createCallback;
  final Future<UpdateOneTimeChoreResult> Function(
    UpdateOneTimeChoreRequest request,
  )?
  oneTimeUpdateCallback;
  final Future<DeleteOneTimeChoreResult> Function(
    DeleteOneTimeChoreRequest request,
  )?
  oneTimeDeletionCallback;
  final Future<RestoreOneTimeChoreResult> Function(
    RestoreOneTimeChoreRequest request,
  )?
  oneTimeRestoreCallback;
  final Future<SetChoreCompletionResult> Function(
    SetChoreCompletionRequest request,
  )?
  completionCallback;
  final Future<CreateRecurringChoreResult> Function(
    CreateRecurringChoreRequest request,
  )?
  recurringCallback;
  final Future<SkipChoreOccurrenceResult> Function(
    SkipChoreOccurrenceRequest request,
  )?
  skipCallback;
  final Future<RestoreSkippedChoreOccurrenceResult> Function(
    RestoreSkippedChoreOccurrenceRequest request,
  )?
  restoreCallback;
  final Future<RescheduleChoreOccurrenceResult> Function(
    RescheduleChoreOccurrenceRequest request,
  )?
  rescheduleCallback;
  final Future<ReassignChoreOccurrenceResult> Function(
    ReassignChoreOccurrenceRequest request,
  )?
  reassignmentCallback;
  final Future<UpdateRepeatingChoreSeriesResult> Function(
    UpdateRepeatingChoreSeriesRequest request,
  )?
  seriesUpdateCallback;
  final Future<UpdateRepeatingChoreSeriesResult> Function(
    UpdateRepeatingChoreSeriesFromOccurrenceRequest request,
  )?
  seriesFromOccurrenceUpdateCallback;
  final Future<CancelRepeatingChoreSeriesResult> Function(
    CancelRepeatingChoreSeriesRequest request,
  )?
  seriesCancellationCallback;
  final Future<CancelRepeatingChoreSeriesFromOccurrenceResult> Function(
    CancelRepeatingChoreSeriesFromOccurrenceRequest request,
  )?
  seriesFromOccurrenceCancellationCallback;
  final Future<ResumeRepeatingChoreSeriesCancellationResult> Function(
    ResumeRepeatingChoreSeriesCancellationRequest request,
  )?
  seriesCancellationResumeCallback;
  final String reassignmentDisplayName;
  final List<LoadTodayChoresResult> _loadResults;
  final List<LoadHouseholdActivationProgressResult> _activationProgressResults;
  final List<LoadHouseholdWeeklyReportResult> _weeklyReportResults;
  final List<LoadChoreOccurrenceTargetResult> _occurrenceTargetResults;
  final List<LoadChoreOccurrenceHistoryResult> _historyResults;
  final List<LoadDeletedOneTimeChoresResult> _deletedOneTimeChoresResults;
  final List<CreateOneTimeChoreResult> _createResults;
  final List<UpdateOneTimeChoreResult> _oneTimeUpdateResults;
  final List<DeleteOneTimeChoreResult> _oneTimeDeletionResults;
  final List<RestoreOneTimeChoreResult> _oneTimeRestoreResults;
  final List<SetChoreCompletionResult> _completionResults;
  final List<CreateRecurringChoreResult> _recurringResults;
  final List<SkipChoreOccurrenceResult> _skipResults;
  final List<RestoreSkippedChoreOccurrenceResult> _restoreResults;
  final List<RescheduleChoreOccurrenceResult> _rescheduleResults;
  final List<ReassignChoreOccurrenceResult> _reassignmentResults;
  final List<UpdateRepeatingChoreSeriesResult> _seriesUpdateResults;
  final List<UpdateRepeatingChoreSeriesResult>
  _seriesFromOccurrenceUpdateResults;
  final List<CancelRepeatingChoreSeriesResult> _seriesCancellationResults;
  final List<CancelRepeatingChoreSeriesFromOccurrenceResult>
  _seriesFromOccurrenceCancellationResults;
  final List<ResumeRepeatingChoreSeriesCancellationResult>
  _seriesCancellationResumeResults;
  final List<HouseholdId> loadedHouseholds = <HouseholdId>[];
  final List<HouseholdId> activationProgressHouseholds = <HouseholdId>[];
  final List<HouseholdWeeklyReportRequest> weeklyReportRequests =
      <HouseholdWeeklyReportRequest>[];
  final List<ChoreListRequest> listRequests = <ChoreListRequest>[];
  final List<({HouseholdId householdId, ChoreOccurrenceId occurrenceId})>
  occurrenceTargetRequests =
      <({HouseholdId householdId, ChoreOccurrenceId occurrenceId})>[];
  final List<ChoreOccurrenceHistoryRequest> historyRequests =
      <ChoreOccurrenceHistoryRequest>[];
  final List<DeletedOneTimeChoreListRequest> deletedOneTimeChoresRequests =
      <DeletedOneTimeChoreListRequest>[];
  final List<CreateOneTimeChoreRequest> createRequests =
      <CreateOneTimeChoreRequest>[];
  final List<UpdateOneTimeChoreRequest> oneTimeUpdateRequests =
      <UpdateOneTimeChoreRequest>[];
  final List<DeleteOneTimeChoreRequest> oneTimeDeletionRequests =
      <DeleteOneTimeChoreRequest>[];
  final List<RestoreOneTimeChoreRequest> oneTimeRestoreRequests =
      <RestoreOneTimeChoreRequest>[];
  final List<SetChoreCompletionRequest> completionRequests =
      <SetChoreCompletionRequest>[];
  final List<CreateRecurringChoreRequest> recurringRequests =
      <CreateRecurringChoreRequest>[];
  final List<SkipChoreOccurrenceRequest> skipRequests =
      <SkipChoreOccurrenceRequest>[];
  final List<RestoreSkippedChoreOccurrenceRequest> restoreRequests =
      <RestoreSkippedChoreOccurrenceRequest>[];
  final List<RescheduleChoreOccurrenceRequest> rescheduleRequests =
      <RescheduleChoreOccurrenceRequest>[];
  final List<ReassignChoreOccurrenceRequest> reassignmentRequests =
      <ReassignChoreOccurrenceRequest>[];
  final List<UpdateRepeatingChoreSeriesRequest> seriesUpdateRequests =
      <UpdateRepeatingChoreSeriesRequest>[];
  final List<UpdateRepeatingChoreSeriesFromOccurrenceRequest>
  seriesFromOccurrenceUpdateRequests =
      <UpdateRepeatingChoreSeriesFromOccurrenceRequest>[];
  final List<CancelRepeatingChoreSeriesRequest> seriesCancellationRequests =
      <CancelRepeatingChoreSeriesRequest>[];
  final List<CancelRepeatingChoreSeriesFromOccurrenceRequest>
  seriesFromOccurrenceCancellationRequests =
      <CancelRepeatingChoreSeriesFromOccurrenceRequest>[];
  final List<ResumeRepeatingChoreSeriesCancellationRequest>
  seriesCancellationResumeRequests =
      <ResumeRepeatingChoreSeriesCancellationRequest>[];

  @override
  Future<LoadTodayChoresResult> loadToday(HouseholdId householdId) async {
    loadedHouseholds.add(householdId);
    final callback = loadCallback;
    if (callback != null) {
      return callback(householdId);
    }
    return _loadResults.isEmpty
        ? TodayChoresLoaded(defaultToday)
        : _loadResults.removeAt(0);
  }

  @override
  Future<LoadHouseholdActivationProgressResult> loadHouseholdActivationProgress(
    HouseholdId householdId,
  ) async {
    activationProgressHouseholds.add(householdId);
    final callback = activationProgressCallback;
    if (callback != null) {
      return callback(householdId);
    }
    return _activationProgressResults.isEmpty
        ? HouseholdActivationProgressLoaded(
            householdActivationProgressFixture(householdId: householdId),
          )
        : _activationProgressResults.removeAt(0);
  }

  @override
  Future<LoadHouseholdWeeklyReportResult> loadHouseholdWeeklyReport(
    HouseholdWeeklyReportRequest request,
  ) async {
    weeklyReportRequests.add(request);
    final callback = weeklyReportCallback;
    if (callback != null) {
      return callback(request);
    }
    return _weeklyReportResults.isEmpty
        ? HouseholdWeeklyReportLoaded(
            householdWeeklyReportFixture(
              householdId: request.householdId,
              weekOffset: request.weekOffset,
            ),
          )
        : _weeklyReportResults.removeAt(0);
  }

  @override
  Future<LoadTodayChoresResult> loadChoreList(ChoreListRequest request) async {
    loadedHouseholds.add(request.householdId);
    listRequests.add(request);
    final callback = listCallback;
    if (callback != null) {
      return callback(request);
    }
    final legacyCallback = loadCallback;
    if (legacyCallback != null) {
      final LoadTodayChoresResult result = await legacyCallback(
        request.householdId,
      );
      if (result case TodayChoresLoaded(:final today, :final cacheMetadata)) {
        final TodayChores queryTemplate = TodayChores(
          householdId: today.householdId,
          householdTimezone: today.householdTimezone,
          localDate: today.localDate,
          occurrences: const <ChoreOccurrence>[],
          view: request.view,
          assigneeFilterMemberId: request.assigneeMemberId,
          generatedAt: today.generatedAt,
          pageLimit: request.limit,
        );
        return TodayChoresLoaded(
          TodayChores(
            householdId: today.householdId,
            householdTimezone: today.householdTimezone,
            localDate: today.localDate,
            occurrences: today.occurrences
                .where(queryTemplate.matches)
                .toList(growable: false),
            view: request.view,
            assigneeFilterMemberId: request.assigneeMemberId,
            generatedAt: today.generatedAt,
            pageLimit: request.limit,
          ),
          cacheMetadata: cacheMetadata,
        );
      }
      return result;
    }
    if (_loadResults.isNotEmpty) {
      return _loadResults.removeAt(0);
    }
    final TodayChores queryTemplate = TodayChores(
      householdId: defaultToday.householdId,
      householdTimezone: defaultToday.householdTimezone,
      localDate: defaultToday.localDate,
      occurrences: const <ChoreOccurrence>[],
      view: request.view,
      assigneeFilterMemberId: request.assigneeMemberId,
      generatedAt:
          defaultToday.generatedAt ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      pageLimit: request.limit,
    );
    return TodayChoresLoaded(
      TodayChores(
        householdId: defaultToday.householdId,
        householdTimezone: defaultToday.householdTimezone,
        localDate: defaultToday.localDate,
        occurrences: defaultToday.occurrences
            .where(queryTemplate.matches)
            .toList(growable: false),
        view: request.view,
        assigneeFilterMemberId: request.assigneeMemberId,
        generatedAt: queryTemplate.generatedAt,
        pageLimit: request.limit,
      ),
    );
  }

  @override
  Future<LoadChoreOccurrenceTargetResult> loadOccurrenceTarget({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) async {
    occurrenceTargetRequests.add((
      householdId: householdId,
      occurrenceId: occurrenceId,
    ));
    final callback = occurrenceTargetCallback;
    if (callback != null) return callback(householdId, occurrenceId);
    if (_occurrenceTargetResults.isNotEmpty) {
      return _occurrenceTargetResults.removeAt(0);
    }
    for (final ChoreOccurrence occurrence in defaultToday.occurrences) {
      if (defaultToday.householdId == householdId &&
          occurrence.id == occurrenceId) {
        return ChoreOccurrenceTargetLoaded(occurrence);
      }
    }
    return const LoadChoreOccurrenceTargetFailed(
      ChoreFailure(ChoreFailureKind.notFoundOrForbidden),
    );
  }

  @override
  Future<LoadChoreOccurrenceHistoryResult> loadOccurrenceHistory(
    ChoreOccurrenceHistoryRequest request,
  ) async {
    historyRequests.add(request);
    final callback = historyCallback;
    if (callback != null) {
      return callback(request);
    }
    return _historyResults.isEmpty
        ? ChoreOccurrenceHistoryLoaded(
            ChoreOccurrenceHistoryPage.tryCreate(
              householdId: request.householdId,
              occurrenceId: request.occurrenceId,
              events: const <ChoreOccurrenceHistoryEvent>[],
              hasMore: false,
            )!,
          )
        : _historyResults.removeAt(0);
  }

  @override
  Future<LoadDeletedOneTimeChoresResult> loadDeletedOneTimeChores(
    DeletedOneTimeChoreListRequest request,
  ) async {
    deletedOneTimeChoresRequests.add(request);
    final callback = deletedOneTimeChoresCallback;
    if (callback != null) {
      return callback(request);
    }
    return _deletedOneTimeChoresResults.isEmpty
        ? DeletedOneTimeChoresLoaded(
            DeletedOneTimeChorePage.tryCreate(
              householdId: request.householdId,
              householdTimezone: 'Asia/Seoul',
              generatedAt: DateTime.parse('2026-08-09T10:00:00Z'),
              pageLimit: request.limit,
              hasMore: false,
              nextCursor: null,
              items: const <DeletedOneTimeChore>[],
            )!,
          )
        : _deletedOneTimeChoresResults.removeAt(0);
  }

  @override
  Future<CreateOneTimeChoreResult> createOneTimeChore(
    CreateOneTimeChoreRequest request,
  ) async {
    createRequests.add(request);
    final callback = createCallback;
    if (callback != null) {
      return callback(request);
    }
    return _createResults.isEmpty
        ? OneTimeChoreCreated(
            choreOccurrenceFixture(
              title: request.title,
              assigneeMemberId: request.assigneeMemberId,
              dueLocalDate: request.dueLocalDate,
              dueLocalTime: request.dueLocalTime,
              description: request.description,
            ),
          )
        : _createResults.removeAt(0);
  }

  @override
  Future<UpdateOneTimeChoreResult> updateOneTimeChore(
    UpdateOneTimeChoreRequest request,
  ) async {
    oneTimeUpdateRequests.add(request);
    final callback = oneTimeUpdateCallback;
    if (callback != null) {
      return callback(request);
    }
    return _oneTimeUpdateResults.isEmpty
        ? OneTimeChoreUpdated(
            OneTimeChoreUpdateSnapshot(
              householdId: request.householdId,
              seriesId: request.seriesId,
              occurrenceId: request.occurrenceId,
              revisionId: _revisionId(),
              revisionNumber: request.expectedSeriesVersion + 1,
              dueLocalDate: request.dueLocalDate,
              dueLocalTime: request.dueLocalTime,
              dueAt: _dueAt(request.dueLocalDate, request.dueLocalTime),
              assigneeMemberId: request.assigneeMemberId,
              seriesVersion: request.expectedSeriesVersion + 1,
              occurrenceVersion: request.expectedOccurrenceVersion + 1,
              changed: true,
            ),
          )
        : _oneTimeUpdateResults.removeAt(0);
  }

  @override
  Future<DeleteOneTimeChoreResult> deleteOneTimeChore(
    DeleteOneTimeChoreRequest request,
  ) async {
    oneTimeDeletionRequests.add(request);
    final callback = oneTimeDeletionCallback;
    if (callback != null) {
      return callback(request);
    }
    return _oneTimeDeletionResults.isEmpty
        ? OneTimeChoreDeleted(
            OneTimeChoreDeletionSnapshot(
              householdId: request.householdId,
              seriesId: request.seriesId,
              occurrenceId: request.occurrenceId,
              seriesVersion: request.expectedSeriesVersion + 1,
              occurrenceVersion: request.expectedOccurrenceVersion + 1,
              changed: true,
            ),
          )
        : _oneTimeDeletionResults.removeAt(0);
  }

  @override
  Future<RestoreOneTimeChoreResult> restoreOneTimeChore(
    RestoreOneTimeChoreRequest request,
  ) async {
    oneTimeRestoreRequests.add(request);
    final callback = oneTimeRestoreCallback;
    if (callback != null) {
      return callback(request);
    }
    return _oneTimeRestoreResults.isEmpty
        ? OneTimeChoreRestored(
            OneTimeChoreRestoreSnapshot(
              householdId: request.householdId,
              seriesId: request.seriesId,
              occurrenceId: request.occurrenceId,
              seriesVersion: request.expectedSeriesVersion + 1,
              occurrenceVersion: request.expectedOccurrenceVersion + 1,
              changed: true,
            ),
          )
        : _oneTimeRestoreResults.removeAt(0);
  }

  @override
  Future<CreateRecurringChoreResult> createRecurringChore(
    CreateRecurringChoreRequest request,
  ) async {
    recurringRequests.add(request);
    final callback = recurringCallback;
    if (callback != null) {
      return callback(request);
    }
    return _recurringResults.isEmpty
        ? RecurringChoreCreated(
            RecurringChoreSnapshot(
              householdId: request.householdId,
              seriesId: _seriesId(),
              firstOccurrenceId: _occurrenceId(),
              recurrenceRule: request.recurrenceRule,
              materializedThrough: request.startLocalDate,
              materializedCount: 1,
              created: true,
            ),
          )
        : _recurringResults.removeAt(0);
  }

  @override
  Future<SetChoreCompletionResult> setOccurrenceCompletion(
    SetChoreCompletionRequest request,
  ) async {
    completionRequests.add(request);
    final callback = completionCallback;
    if (callback != null) {
      return callback(request);
    }
    return _completionResults.isEmpty
        ? ChoreCompletionSet(
            ChoreCompletionSnapshot(
              householdId: request.householdId,
              occurrenceId: request.occurrenceId,
              status: request.completed
                  ? ChoreOccurrenceStatus.completed
                  : ChoreOccurrenceStatus.scheduled,
              version: request.expectedVersion + 1,
              completedByMemberId: request.completed ? _memberId() : null,
              completedAt: request.completed
                  ? DateTime.parse('2026-08-06T10:30:00Z')
                  : null,
              changed: true,
            ),
          )
        : _completionResults.removeAt(0);
  }

  @override
  Future<SkipChoreOccurrenceResult> skipOccurrence(
    SkipChoreOccurrenceRequest request,
  ) async {
    skipRequests.add(request);
    final callback = skipCallback;
    if (callback != null) {
      return callback(request);
    }
    return _skipResults.isEmpty
        ? ChoreOccurrenceSkipped(
            ChoreOccurrenceSkipSnapshot(
              householdId: request.householdId,
              occurrenceId: request.occurrenceId,
              version: request.expectedVersion + 1,
              changed: true,
            ),
          )
        : _skipResults.removeAt(0);
  }

  @override
  Future<RestoreSkippedChoreOccurrenceResult> restoreSkippedOccurrence(
    RestoreSkippedChoreOccurrenceRequest request,
  ) async {
    restoreRequests.add(request);
    final callback = restoreCallback;
    if (callback != null) {
      return callback(request);
    }
    return _restoreResults.isEmpty
        ? ChoreOccurrenceRestored(
            ChoreOccurrenceRestoreSnapshot(
              householdId: request.householdId,
              occurrenceId: request.occurrenceId,
              version: request.expectedVersion + 1,
              changed: true,
            ),
          )
        : _restoreResults.removeAt(0);
  }

  @override
  Future<RescheduleChoreOccurrenceResult> rescheduleOccurrence(
    RescheduleChoreOccurrenceRequest request,
  ) async {
    rescheduleRequests.add(request);
    final callback = rescheduleCallback;
    if (callback != null) {
      return callback(request);
    }
    return _rescheduleResults.isEmpty
        ? ChoreOccurrenceRescheduled(
            ChoreOccurrenceRescheduleSnapshot(
              householdId: request.householdId,
              occurrenceId: request.occurrenceId,
              dueLocalDate: request.dueLocalDate,
              dueLocalTime: request.dueLocalTime,
              dueAt: _dueAt(request.dueLocalDate, request.dueLocalTime),
              version: request.expectedVersion + 1,
              changed: true,
            ),
          )
        : _rescheduleResults.removeAt(0);
  }

  @override
  Future<ReassignChoreOccurrenceResult> reassignOccurrence(
    ReassignChoreOccurrenceRequest request,
  ) async {
    reassignmentRequests.add(request);
    final callback = reassignmentCallback;
    if (callback != null) {
      return callback(request);
    }
    return _reassignmentResults.isEmpty
        ? ChoreOccurrenceReassigned(
            ChoreOccurrenceReassignmentSnapshot(
              householdId: request.householdId,
              occurrenceId: request.occurrenceId,
              assigneeMemberId: request.assigneeMemberId,
              assigneeDisplayName: reassignmentDisplayName,
              version: request.expectedVersion + 1,
              changed: true,
            ),
          )
        : _reassignmentResults.removeAt(0);
  }

  @override
  Future<UpdateRepeatingChoreSeriesResult> updateRepeatingSeries(
    UpdateRepeatingChoreSeriesRequest request,
  ) async {
    seriesUpdateRequests.add(request);
    final callback = seriesUpdateCallback;
    if (callback != null) {
      return callback(request);
    }
    return _seriesUpdateResults.isEmpty
        ? RepeatingChoreSeriesUpdated(
            RepeatingChoreSeriesUpdateSnapshot(
              householdId: request.householdId,
              seriesId: request.seriesId,
              revisionId: _revisionId(),
              revisionNumber: request.expectedVersion + 1,
              effectiveLocalDate: request.effectiveLocalDate,
              version: request.expectedVersion + 1,
              rebuiltCount: 1,
              cancelledCount: 1,
              preservedCompletedCount: 0,
              changed: true,
            ),
          )
        : _seriesUpdateResults.removeAt(0);
  }

  @override
  Future<UpdateRepeatingChoreSeriesResult> updateRepeatingSeriesFromOccurrence(
    UpdateRepeatingChoreSeriesFromOccurrenceRequest request,
  ) async {
    seriesFromOccurrenceUpdateRequests.add(request);
    final callback = seriesFromOccurrenceUpdateCallback;
    if (callback != null) {
      return callback(request);
    }
    return _seriesFromOccurrenceUpdateResults.isEmpty
        ? RepeatingChoreSeriesUpdated(
            RepeatingChoreSeriesUpdateSnapshot(
              householdId: request.householdId,
              seriesId: request.seriesId,
              revisionId: _revisionId(),
              revisionNumber: request.expectedVersion + 1,
              effectiveLocalDate: defaultToday.localDate,
              version: request.expectedVersion + 1,
              rebuiltCount: 1,
              cancelledCount: 1,
              preservedCompletedCount: 0,
              changed: true,
            ),
          )
        : _seriesFromOccurrenceUpdateResults.removeAt(0);
  }

  @override
  Future<CancelRepeatingChoreSeriesResult> cancelRepeatingSeries(
    CancelRepeatingChoreSeriesRequest request,
  ) async {
    seriesCancellationRequests.add(request);
    final callback = seriesCancellationCallback;
    if (callback != null) {
      return callback(request);
    }
    return _seriesCancellationResults.isEmpty
        ? RepeatingChoreSeriesCancelled(
            RepeatingChoreSeriesCancellationSnapshot(
              householdId: request.householdId,
              seriesId: request.seriesId,
              effectiveLocalDate: defaultToday.localDate,
              version: request.expectedVersion + 1,
              cancelledCount: 1,
              preservedCompletedCount: 0,
              changed: true,
            ),
          )
        : _seriesCancellationResults.removeAt(0);
  }

  @override
  Future<CancelRepeatingChoreSeriesFromOccurrenceResult>
  cancelRepeatingSeriesFromOccurrence(
    CancelRepeatingChoreSeriesFromOccurrenceRequest request,
  ) async {
    seriesFromOccurrenceCancellationRequests.add(request);
    final callback = seriesFromOccurrenceCancellationCallback;
    if (callback != null) {
      return callback(request);
    }
    return _seriesFromOccurrenceCancellationResults.isEmpty
        ? RepeatingChoreSeriesCancelledFromOccurrence(
            RepeatingChoreSeriesFromOccurrenceCancellationSnapshot(
              householdId: request.householdId,
              seriesId: request.seriesId,
              effectiveLocalDate: defaultToday.localDate,
              version: request.expectedVersion + 1,
              cancelledCount: 1,
              preservedCompletedCount: 0,
              terminalRevisionId: _revisionId(),
              terminalRevisionNumber: request.expectedVersion + 1,
              changed: true,
            ),
          )
        : _seriesFromOccurrenceCancellationResults.removeAt(0);
  }

  @override
  Future<ResumeRepeatingChoreSeriesCancellationResult>
  resumeRepeatingSeriesCancellation(
    ResumeRepeatingChoreSeriesCancellationRequest request,
  ) async {
    seriesCancellationResumeRequests.add(request);
    final callback = seriesCancellationResumeCallback;
    if (callback != null) {
      return callback(request);
    }
    return _seriesCancellationResumeResults.isEmpty
        ? RepeatingChoreSeriesCancellationResumed(
            RepeatingChoreSeriesCancellationResumeSnapshot(
              householdId: request.householdId,
              seriesId: request.seriesId,
              effectiveLocalDate: defaultToday.localDate,
              version: request.expectedVersion + 1,
              restoredCount: 1,
              preservedCompletedCount: 0,
              revisionId: _revisionId(),
              revisionNumber: request.expectedVersion + 1,
              changed: true,
            ),
          )
        : _seriesCancellationResumeResults.removeAt(0);
  }
}

final class FakeChoreCommandIdGenerator implements ChoreCommandIdGenerator {
  FakeChoreCommandIdGenerator({
    List<String> values = const <String>[
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    ],
  }) : _values = values.map(_commandId).toList(growable: false);

  final List<ChoreCommandId> _values;
  var generateCount = 0;

  @override
  ChoreCommandId generate() {
    final int index = generateCount;
    generateCount += 1;
    if (index >= _values.length) {
      throw StateError('No fake chore command ID remains.');
    }
    return _values[index];
  }
}

final class FakeGuidedChoreSetupResumeStore
    implements GuidedChoreSetupResumeStore {
  FakeGuidedChoreSetupResumeStore({
    this.plan,
    this.throwOnRead = false,
    this.throwOnWrite = false,
    this.throwOnClear = false,
    List<bool> writeResults = const <bool>[],
    List<bool> clearResults = const <bool>[],
  }) : _writeResults = List<bool>.of(writeResults),
       _clearResults = List<bool>.of(clearResults);

  GuidedChoreSetupResumePlan? plan;
  final bool throwOnRead;
  final bool throwOnWrite;
  final bool throwOnClear;
  final List<bool> _writeResults;
  final List<bool> _clearResults;
  final List<GuidedChoreSetupResumePlan> writes =
      <GuidedChoreSetupResumePlan>[];
  var readCount = 0;
  var clearCount = 0;

  @override
  Future<GuidedChoreSetupResumePlan?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedAssigneeMemberId,
  }) async {
    readCount += 1;
    if (throwOnRead) {
      throw StateError('resume read failed');
    }
    final GuidedChoreSetupResumePlan? current = plan;
    if (current == null ||
        current.householdId != expectedHouseholdId ||
        current.assigneeMemberId != expectedAssigneeMemberId) {
      plan = null;
      return null;
    }
    return current;
  }

  @override
  Future<bool> write(GuidedChoreSetupResumePlan next) async {
    writes.add(next);
    if (throwOnWrite) {
      throw StateError('resume write failed');
    }
    final bool succeeds = _writeResults.isEmpty
        ? true
        : _writeResults.removeAt(0);
    if (succeeds) {
      plan = next;
    }
    return succeeds;
  }

  @override
  Future<bool> clear() async {
    clearCount += 1;
    if (throwOnClear) {
      throw StateError('resume clear failed');
    }
    final bool succeeds = _clearResults.isEmpty
        ? true
        : _clearResults.removeAt(0);
    if (succeeds) {
      plan = null;
    }
    return succeeds;
  }
}

TodayChores todayChoresFixture({
  List<ChoreOccurrence> occurrences = const <ChoreOccurrence>[],
  String localDate = '2026-08-06',
  ChoreListView view = ChoreListView.today,
  HouseholdMemberId? assigneeFilterMemberId,
  DateTime? generatedAt,
  int pageLimit = 30,
  bool hasMore = false,
  ChoreListCursor? nextCursor,
}) {
  return TodayChores(
    householdId: _householdId(),
    householdTimezone: 'Asia/Seoul',
    localDate: _localDate(localDate),
    occurrences: occurrences,
    view: view,
    assigneeFilterMemberId: assigneeFilterMemberId,
    generatedAt: generatedAt,
    pageLimit: pageLimit,
    hasMore: hasMore,
    nextCursor: nextCursor,
  );
}

HouseholdActivationProgress householdActivationProgressFixture({
  HouseholdId? householdId,
  int adultParticipantProgress = 1,
  int choreCreationProgress = 0,
  int distinctAdultCompleterProgress = 0,
  bool returnAfterFirstDayReached = false,
}) {
  return HouseholdActivationProgress.tryCreate(
    householdId: householdId ?? _householdId(),
    adultParticipantProgress: adultParticipantProgress,
    choreCreationProgress: choreCreationProgress,
    distinctAdultCompleterProgress: distinctAdultCompleterProgress,
    returnAfterFirstDayReached: returnAfterFirstDayReached,
  )!;
}

HouseholdWeeklyReport householdWeeklyReportFixture({
  HouseholdId? householdId,
  int weekOffset = 0,
  int dueCount = 4,
  int completedCount = 3,
  int completedByWeekEndCount = 2,
  int completedAfterWeekEndCount = 1,
  int openCount = 1,
  int skippedCount = 1,
  int viewerCompletedCount = 2,
  List<HouseholdWeeklyReportMember>? members,
  int otherMemberCompletedCount = 0,
  bool memberBreakdownTruncated = false,
}) {
  final DateTime start = DateTime.utc(
    2026,
    8,
    3,
  ).subtract(Duration(days: weekOffset * 7));
  return HouseholdWeeklyReport.tryCreate(
    householdId: householdId ?? _householdId(),
    householdTimezone: 'Asia/Seoul',
    generatedAt: DateTime.parse('2026-08-10T01:00:00Z'),
    weekOffset: weekOffset,
    weekStart: _localDate(_dateString(start)),
    weekEnd: _localDate(_dateString(start.add(const Duration(days: 6)))),
    dueCount: dueCount,
    completedCount: completedCount,
    completedByWeekEndCount: completedByWeekEndCount,
    completedAfterWeekEndCount: completedAfterWeekEndCount,
    openCount: openCount,
    skippedCount: skippedCount,
    viewerCompletedCount: viewerCompletedCount,
    members:
        members ??
        <HouseholdWeeklyReportMember>[
          HouseholdWeeklyReportMember.tryCreate(
            memberId: _memberId(),
            displayName: 'Alex',
            completedCount: 2,
            completedByWeekEndCount: 1,
            isViewer: true,
          )!,
          HouseholdWeeklyReportMember.tryCreate(
            memberId: HouseholdMemberId.tryParse(
              '33333333-3333-4333-8333-333333333334',
            )!,
            displayName: 'Sam',
            completedCount: 1,
            completedByWeekEndCount: 1,
            isViewer: false,
          )!,
        ],
    otherMemberCompletedCount: otherMemberCompletedCount,
    memberBreakdownTruncated: memberBreakdownTruncated,
  )!;
}

ChoreOccurrence choreOccurrenceFixture({
  String occurrenceId = '55555555-5555-4555-8555-555555555555',
  String seriesId = '44444444-4444-4444-8444-444444444444',
  String title = 'Take out recycling',
  String? description,
  HouseholdMemberId? assigneeMemberId,
  String assigneeDisplayName = 'Alex',
  ChoreLocalDate? dueLocalDate,
  ChoreLocalTime? dueLocalTime,
  DateTime? dueAt,
  ChoreOccurrenceStatus status = ChoreOccurrenceStatus.scheduled,
  int version = 1,
  ChoreRecurrenceFrequency? recurrenceFrequency,
  int seriesVersion = 1,
  HouseholdMemberId? seriesDefaultAssigneeMemberId,
  ChoreLocalTime? seriesDueLocalTime,
  ChoreRecurrenceRule? recurrenceRule,
  bool canManageSeries = false,
  bool canSetCompletion = true,
}) {
  final ChoreOccurrenceId? parsedOccurrenceId = ChoreOccurrenceId.tryParse(
    occurrenceId,
  );
  final ChoreSeriesId? parsedSeriesId = ChoreSeriesId.tryParse(seriesId);
  if (parsedOccurrenceId == null || parsedSeriesId == null) {
    throw StateError('Static chore fixture IDs must be UUIDs.');
  }
  final ChoreLocalTime? effectiveTime = dueLocalTime;
  return ChoreOccurrence(
    id: parsedOccurrenceId,
    seriesId: parsedSeriesId,
    title: title,
    description: description,
    assigneeMemberId: assigneeMemberId ?? _memberId(),
    assigneeDisplayName: assigneeDisplayName,
    dueLocalDate: dueLocalDate ?? _localDate('2026-08-06'),
    dueLocalTime: effectiveTime,
    dueAt: effectiveTime == null
        ? null
        : dueAt ?? DateTime.parse('2026-08-06T10:00:00Z'),
    status: status,
    version: version,
    recurrenceFrequency: recurrenceFrequency,
    seriesVersion: seriesVersion,
    seriesDefaultAssigneeMemberId: seriesDefaultAssigneeMemberId,
    seriesDueLocalTime: seriesDueLocalTime,
    recurrenceRule: recurrenceRule,
    canManageSeries: canManageSeries,
    canSetCompletion: canSetCompletion,
  );
}

HouseholdId _householdId() {
  return HouseholdId.tryParse('22222222-2222-4222-8222-222222222222')!;
}

HouseholdMemberId _memberId() {
  return HouseholdMemberId.tryParse('33333333-3333-4333-8333-333333333333')!;
}

ChoreLocalDate _localDate(String value) {
  final ChoreLocalDate? date = ChoreLocalDate.tryParse(value);
  if (date == null) {
    throw StateError('Static chore fixture date must be valid.');
  }
  return date;
}

String _dateString(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

ChoreCommandId _commandId(String value) {
  final ChoreCommandId? id = ChoreCommandId.tryParse(value);
  if (id == null) {
    throw StateError('Static chore command ID must be a UUID.');
  }
  return id;
}

ChoreSeriesId _seriesId() {
  return ChoreSeriesId.tryParse('44444444-4444-4444-8444-444444444444')!;
}

ChoreOccurrenceId _occurrenceId() {
  return ChoreOccurrenceId.tryParse('55555555-5555-4555-8555-555555555555')!;
}

ChoreRevisionId _revisionId() {
  return ChoreRevisionId.tryParse('77777777-7777-4777-8777-777777777777')!;
}

DateTime? _dueAt(ChoreLocalDate date, ChoreLocalTime? time) {
  if (time == null) {
    return null;
  }
  final DateTime localDate = date.toDateTime();
  return DateTime.utc(
    localDate.year,
    localDate.month,
    localDate.day,
    time.hour,
    time.minute,
  );
}
