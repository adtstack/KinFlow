import 'dart:async';

import 'package:kinflow_app/features/chores/application/chore_occurrence_history_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/chore_occurrence_history.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class ChoreOccurrenceHistoryController {
  ChoreOccurrenceHistoryController({required this._repository});

  final ChoreRepository _repository;
  final StreamController<ChoreOccurrenceHistoryState> _states =
      StreamController<ChoreOccurrenceHistoryState>.broadcast(sync: true);

  ChoreOccurrenceHistoryState _state = const ChoreOccurrenceHistoryInitial();
  ChoreOccurrenceHistoryRequest? _initialRequest;
  Future<void> _pending = Future<void>.value();
  var _busy = false;
  var _disposed = false;

  ChoreOccurrenceHistoryState get state => _state;

  Stream<ChoreOccurrenceHistoryState> get states => _states.stream;

  Future<void> load({
    required HouseholdId householdId,
    required ChoreOccurrenceId occurrenceId,
    int limit = 20,
  }) {
    if (_busy || _disposed) {
      return _pending;
    }
    final ChoreOccurrenceHistoryRequest? request =
        ChoreOccurrenceHistoryRequest.tryCreate(
          householdId: householdId,
          occurrenceId: occurrenceId,
          limit: limit,
        );
    if (request == null) {
      _emit(
        const ChoreOccurrenceHistoryLoadFailed(
          ChoreFailure(ChoreFailureKind.invalidInput),
        ),
      );
      return Future<void>.value();
    }
    _initialRequest = request;
    return _start(() => _loadInitial(request));
  }

  Future<void> retry() {
    if (_busy || _disposed) {
      return _pending;
    }
    final ChoreOccurrenceHistoryState current = _state;
    if (current case ChoreOccurrenceHistoryReady(
      loadMoreFailure: final ChoreFailure _,
    )) {
      return loadMore();
    }
    final ChoreOccurrenceHistoryRequest? request = _initialRequest;
    return request == null
        ? Future<void>.value()
        : _start(() => _loadInitial(request));
  }

  Future<void> loadMore() {
    if (_busy || _disposed) {
      return _pending;
    }
    final ChoreOccurrenceHistoryState current = _state;
    if (current is! ChoreOccurrenceHistoryReady ||
        !current.hasMore ||
        current.events.isEmpty) {
      return Future<void>.value();
    }
    final ChoreOccurrenceHistoryEvent last = current.events.last;
    final ChoreOccurrenceHistoryCursor? cursor =
        ChoreOccurrenceHistoryCursor.tryCreate(
          occurredAt: last.occurredAt,
          entryId: last.id,
        );
    final ChoreOccurrenceHistoryRequest? initial = _initialRequest;
    final ChoreOccurrenceHistoryRequest? request =
        cursor == null || initial == null
        ? null
        : ChoreOccurrenceHistoryRequest.tryCreate(
            householdId: current.householdId,
            occurrenceId: current.occurrenceId,
            limit: initial.limit,
            cursor: cursor,
          );
    if (request == null) {
      _emit(
        ChoreOccurrenceHistoryReady(
          householdId: current.householdId,
          occurrenceId: current.occurrenceId,
          events: current.events,
          hasMore: current.hasMore,
          loadMoreFailure: const ChoreFailure(ChoreFailureKind.invalidPayload),
        ),
      );
      return Future<void>.value();
    }
    _emit(
      ChoreOccurrenceHistoryReady(
        householdId: current.householdId,
        occurrenceId: current.occurrenceId,
        events: current.events,
        hasMore: current.hasMore,
        loadingMore: true,
      ),
    );
    return _start(() => _loadNext(current, request));
  }

  Future<void> _loadInitial(ChoreOccurrenceHistoryRequest request) async {
    _emit(const ChoreOccurrenceHistoryLoading());
    final LoadChoreOccurrenceHistoryResult result;
    try {
      result = await _repository.loadOccurrenceHistory(request);
    } on Object {
      _emit(
        const ChoreOccurrenceHistoryLoadFailed(
          ChoreFailure(ChoreFailureKind.internal),
        ),
      );
      return;
    }
    switch (result) {
      case ChoreOccurrenceHistoryLoaded(:final page):
        _emit(
          ChoreOccurrenceHistoryReady(
            householdId: page.householdId,
            occurrenceId: page.occurrenceId,
            events: page.events,
            hasMore: page.hasMore,
          ),
        );
      case LoadChoreOccurrenceHistoryFailed(:final failure):
        _emit(ChoreOccurrenceHistoryLoadFailed(failure));
    }
  }

  Future<void> _loadNext(
    ChoreOccurrenceHistoryReady previous,
    ChoreOccurrenceHistoryRequest request,
  ) async {
    final LoadChoreOccurrenceHistoryResult result;
    try {
      result = await _repository.loadOccurrenceHistory(request);
    } on Object {
      _emitLoadMoreFailure(
        previous,
        const ChoreFailure(ChoreFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case ChoreOccurrenceHistoryLoaded(:final page):
        final Set<ChoreHistoryEntryId> existing = previous.events
            .map((ChoreOccurrenceHistoryEvent event) => event.id)
            .toSet();
        if (page.householdId != previous.householdId ||
            page.occurrenceId != previous.occurrenceId ||
            page.events.any(
              (ChoreOccurrenceHistoryEvent event) =>
                  existing.contains(event.id),
            )) {
          _emitLoadMoreFailure(
            previous,
            const ChoreFailure(ChoreFailureKind.invalidPayload),
          );
          return;
        }
        _emit(
          ChoreOccurrenceHistoryReady(
            householdId: previous.householdId,
            occurrenceId: previous.occurrenceId,
            events: <ChoreOccurrenceHistoryEvent>[
              ...previous.events,
              ...page.events,
            ],
            hasMore: page.hasMore,
          ),
        );
      case LoadChoreOccurrenceHistoryFailed(:final failure):
        _emitLoadMoreFailure(previous, failure);
    }
  }

  void _emitLoadMoreFailure(
    ChoreOccurrenceHistoryReady previous,
    ChoreFailure failure,
  ) {
    _emit(
      ChoreOccurrenceHistoryReady(
        householdId: previous.householdId,
        occurrenceId: previous.occurrenceId,
        events: previous.events,
        hasMore: previous.hasMore,
        loadMoreFailure: failure,
      ),
    );
  }

  Future<void> _start(Future<void> Function() action) {
    _busy = true;
    _pending = action().whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _pending;
    await _states.close();
  }

  void _emit(ChoreOccurrenceHistoryState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
