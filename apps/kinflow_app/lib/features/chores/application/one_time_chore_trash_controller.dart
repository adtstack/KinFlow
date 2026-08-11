import 'dart:async';

import 'package:kinflow_app/features/chores/application/one_time_chore_trash_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/one_time_chore_trash.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/services/chore_command_id_generator.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class OneTimeChoreTrashController {
  factory OneTimeChoreTrashController({
    required ChoreRepository repository,
    required ChoreCommandIdGenerator idGenerator,
  }) => OneTimeChoreTrashController._(repository, idGenerator);

  OneTimeChoreTrashController._(this._repository, this._idGenerator);

  final ChoreRepository _repository;
  final ChoreCommandIdGenerator _idGenerator;
  final StreamController<OneTimeChoreTrashState> _states =
      StreamController<OneTimeChoreTrashState>.broadcast(sync: true);

  OneTimeChoreTrashState _state = const OneTimeChoreTrashInitial();
  DeletedOneTimeChoreListRequest? _currentRequest;
  Future<void> _pending = Future<void>.value();
  String? _retryFingerprint;
  ChoreCommandId? _retryId;
  var _busy = false;
  var _disposed = false;

  OneTimeChoreTrashState get state => _state;

  Stream<OneTimeChoreTrashState> get states => _states.stream;

  Future<void> load(DeletedOneTimeChoreListRequest request) {
    if (_busy || _disposed) {
      return _pending;
    }
    final DeletedOneTimeChoreListRequest firstPage = request.firstPage;
    if (_currentRequest?.householdId != firstPage.householdId) {
      _clearRetry();
    }
    _currentRequest = firstPage;
    return _start(() => _loadInitial(firstPage, preserveContent: false));
  }

  Future<void> refresh() {
    if (_busy || _disposed) {
      return _pending;
    }
    final DeletedOneTimeChoreListRequest? request = _currentRequest;
    return request == null
        ? Future<void>.value()
        : _start(() => _loadInitial(request, preserveContent: true));
  }

  Future<void> retry() {
    if (_busy || _disposed) {
      return _pending;
    }
    final OneTimeChoreTrashState current = _state;
    if (current case OneTimeChoreTrashReady(
      loadMoreFailure: final ChoreFailure _,
    )) {
      return loadMore();
    }
    final DeletedOneTimeChoreListRequest? request = _currentRequest;
    return request == null
        ? Future<void>.value()
        : _start(() => _loadInitial(request, preserveContent: false));
  }

  Future<void> loadMore() {
    if (_busy || _disposed) {
      return _pending;
    }
    final OneTimeChoreTrashReady? ready = _state is OneTimeChoreTrashReady
        ? _state as OneTimeChoreTrashReady
        : null;
    final DeletedOneTimeChoreListRequest? currentRequest = _currentRequest;
    final DeletedOneTimeChoreCursor? cursor = ready?.nextCursor;
    if (ready == null ||
        currentRequest == null ||
        !ready.hasMore ||
        cursor == null) {
      return Future<void>.value();
    }
    _emitReady(ready, loadingMore: true);
    return _start(
      () => _loadContinuation(ready, currentRequest.continuation(cursor)),
    );
  }

  Future<void> restore({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
  }) {
    if (_busy || _disposed) {
      return _pending;
    }
    final OneTimeChoreTrashReady? ready = _state is OneTimeChoreTrashReady
        ? _state as OneTimeChoreTrashReady
        : null;
    final DeletedOneTimeChore? item =
        ready == null || ready.householdId != householdId
        ? null
        : _findItem(ready.items, occurrenceId);
    if (ready == null || item == null) {
      return Future<void>.value();
    }
    final OneTimeChoreRestoreDraft? draft = OneTimeChoreRestoreDraft.tryCreate(
      householdId: householdId,
      seriesId: item.seriesId,
      occurrenceId: item.occurrenceId,
      expectedSeriesVersion: item.seriesVersion,
      expectedOccurrenceVersion: item.occurrenceVersion,
    );
    if (draft == null) {
      _emitReady(
        ready,
        actionFailure: const ChoreFailure(ChoreFailureKind.invalidInput),
      );
      return Future<void>.value();
    }
    return _start(() => _restore(ready, draft));
  }

  Future<void> _loadInitial(
    DeletedOneTimeChoreListRequest request, {
    required bool preserveContent,
  }) async {
    final OneTimeChoreTrashReady? previous =
        preserveContent && _state is OneTimeChoreTrashReady
        ? _state as OneTimeChoreTrashReady
        : null;
    if (previous == null) {
      _emit(const OneTimeChoreTrashLoading());
    } else {
      _emitReady(previous, refreshing: true);
    }
    final LoadDeletedOneTimeChoresResult result;
    try {
      result = await _repository.loadDeletedOneTimeChores(request);
    } on Object {
      _emitInitialFailure(
        previous,
        const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case DeletedOneTimeChoresLoaded(:final page):
        _emitPage(page);
      case LoadDeletedOneTimeChoresFailed(:final failure):
        _emitInitialFailure(previous, failure);
    }
  }

  Future<void> _loadContinuation(
    OneTimeChoreTrashReady previous,
    DeletedOneTimeChoreListRequest request,
  ) async {
    final LoadDeletedOneTimeChoresResult result;
    try {
      result = await _repository.loadDeletedOneTimeChores(request);
    } on Object {
      _emitReady(
        previous,
        loadMoreFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case DeletedOneTimeChoresLoaded(:final page):
        final List<DeletedOneTimeChore> merged = <DeletedOneTimeChore>[
          ...previous.items,
          ...page.items,
        ];
        if (page.householdId != previous.householdId ||
            page.householdTimezone != previous.householdTimezone ||
            page.pageLimit != previous.pageLimit ||
            merged
                    .map((DeletedOneTimeChore item) => item.occurrenceId)
                    .toSet()
                    .length !=
                merged.length ||
            !_isStrictlyOrdered(merged)) {
          _emitReady(
            previous,
            loadMoreFailure: const ChoreFailure(
              ChoreFailureKind.invalidPayload,
            ),
          );
          return;
        }
        _emit(
          OneTimeChoreTrashReady(
            householdId: previous.householdId,
            householdTimezone: previous.householdTimezone,
            generatedAt: previous.generatedAt,
            pageLimit: previous.pageLimit,
            hasMore: page.hasMore,
            nextCursor: page.nextCursor,
            items: merged,
          ),
        );
      case LoadDeletedOneTimeChoresFailed(:final failure):
        _emitReady(previous, loadMoreFailure: failure);
    }
  }

  Future<void> _restore(
    OneTimeChoreTrashReady previous,
    OneTimeChoreRestoreDraft draft,
  ) async {
    if (_retryFingerprint != draft.fingerprint || _retryId == null) {
      _retryFingerprint = draft.fingerprint;
      _retryId = _idGenerator.generate();
    }
    _emitReady(previous, restoringOccurrenceId: draft.occurrenceId);
    final RestoreOneTimeChoreResult result;
    try {
      result = await _repository.restoreOneTimeChore(draft.withId(_retryId!));
    } on Object {
      _emitReady(
        previous,
        actionFailure: const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case OneTimeChoreRestored():
        _clearRetry();
        await _reconcileAfterRestore(
          previous,
          restoredOccurrenceId: draft.occurrenceId,
        );
      case RestoreOneTimeChoreFailed(:final failure)
          when failure.kind == ChoreFailureKind.staleVersion ||
              failure.kind == ChoreFailureKind.invalidTransition:
        await _reconcileAfterRestore(previous, actionFailure: failure);
      case RestoreOneTimeChoreFailed(:final failure):
        _emitReady(previous, actionFailure: failure);
    }
  }

  Future<void> _reconcileAfterRestore(
    OneTimeChoreTrashReady fallback, {
    ChoreOccurrenceId? restoredOccurrenceId,
    ChoreFailure? actionFailure,
  }) async {
    final DeletedOneTimeChoreListRequest? request = _currentRequest;
    if (request == null) {
      _emitReady(
        fallback,
        restoredOccurrenceId: restoredOccurrenceId,
        actionFailure: actionFailure,
      );
      return;
    }
    final LoadDeletedOneTimeChoresResult result;
    try {
      result = await _repository.loadDeletedOneTimeChores(request.firstPage);
    } on Object {
      _emitReady(
        fallback,
        restoredOccurrenceId: restoredOccurrenceId,
        actionFailure:
            actionFailure ?? const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case DeletedOneTimeChoresLoaded(:final page):
        _emitPage(
          page,
          restoredOccurrenceId: restoredOccurrenceId,
          actionFailure: actionFailure,
        );
      case LoadDeletedOneTimeChoresFailed(:final failure):
        _emitReady(
          fallback,
          restoredOccurrenceId: restoredOccurrenceId,
          actionFailure: actionFailure ?? failure,
        );
    }
  }

  void _emitInitialFailure(
    OneTimeChoreTrashReady? previous,
    ChoreFailure failure,
  ) {
    if (previous == null) {
      _emit(OneTimeChoreTrashLoadFailed(failure));
    } else {
      _emitReady(previous, refreshFailure: failure);
    }
  }

  void _emitPage(
    DeletedOneTimeChorePage page, {
    ChoreOccurrenceId? restoredOccurrenceId,
    ChoreFailure? actionFailure,
  }) {
    _emit(
      OneTimeChoreTrashReady(
        householdId: page.householdId,
        householdTimezone: page.householdTimezone,
        generatedAt: page.generatedAt,
        pageLimit: page.pageLimit,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        items: page.items,
        restoredOccurrenceId: restoredOccurrenceId,
        actionFailure: actionFailure,
      ),
    );
  }

  void _emitReady(
    OneTimeChoreTrashReady previous, {
    ChoreOccurrenceId? restoringOccurrenceId,
    ChoreOccurrenceId? restoredOccurrenceId,
    ChoreFailure? actionFailure,
    bool refreshing = false,
    ChoreFailure? refreshFailure,
    bool loadingMore = false,
    ChoreFailure? loadMoreFailure,
  }) {
    _emit(
      OneTimeChoreTrashReady(
        householdId: previous.householdId,
        householdTimezone: previous.householdTimezone,
        generatedAt: previous.generatedAt,
        pageLimit: previous.pageLimit,
        hasMore: previous.hasMore,
        nextCursor: previous.nextCursor,
        items: previous.items,
        restoringOccurrenceId: restoringOccurrenceId,
        restoredOccurrenceId: restoredOccurrenceId,
        actionFailure: actionFailure,
        refreshing: refreshing,
        refreshFailure: refreshFailure,
        loadingMore: loadingMore,
        loadMoreFailure: loadMoreFailure,
      ),
    );
  }

  DeletedOneTimeChore? _findItem(
    List<DeletedOneTimeChore> items,
    ChoreOccurrenceId occurrenceId,
  ) {
    for (final DeletedOneTimeChore item in items) {
      if (item.occurrenceId == occurrenceId) {
        return item;
      }
    }
    return null;
  }

  bool _isStrictlyOrdered(List<DeletedOneTimeChore> items) {
    for (var index = 1; index < items.length; index += 1) {
      if (compareDeletedOneTimeChores(items[index - 1], items[index]) >= 0) {
        return false;
      }
    }
    return true;
  }

  Future<void> _start(Future<void> Function() action) {
    _busy = true;
    _pending = action().whenComplete(() => _busy = false);
    return _pending;
  }

  void _clearRetry() {
    _retryFingerprint = null;
    _retryId = null;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(OneTimeChoreTrashState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
