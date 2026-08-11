import 'dart:async';

import 'package:kinflow_app/features/chores/application/household_weekly_report_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';

final class HouseholdWeeklyReportController {
  factory HouseholdWeeklyReportController({
    required ChoreRepository repository,
    HouseholdWeeklyReport? initialReport,
  }) => HouseholdWeeklyReportController._(repository, initialReport);

  HouseholdWeeklyReportController._(
    this._repository,
    HouseholdWeeklyReport? initialReport,
  ) : _state = initialReport == null
          ? const HouseholdWeeklyReportInitial()
          : HouseholdWeeklyReportReady(report: initialReport);

  final ChoreRepository _repository;
  final StreamController<HouseholdWeeklyReportState> _states =
      StreamController<HouseholdWeeklyReportState>.broadcast(sync: true);

  HouseholdWeeklyReportState _state;
  HouseholdWeeklyReportRequest? _pendingRequest;
  Future<void>? _pendingLoad;
  var _requestVersion = 0;
  var _disposed = false;

  HouseholdWeeklyReportState get state => _state;

  Stream<HouseholdWeeklyReportState> get states => _states.stream;

  Future<void> load(
    HouseholdWeeklyReportRequest request, {
    bool preserveContent = false,
    bool force = false,
  }) {
    if (_disposed) {
      return Future<void>.value();
    }
    final Future<void>? pendingLoad = _pendingLoad;
    if (!force && _pendingRequest == request && pendingLoad != null) {
      return pendingLoad;
    }

    final int requestVersion = ++_requestVersion;
    _pendingRequest = request;
    final HouseholdWeeklyReportState currentState = _state;
    if (preserveContent &&
        currentState is HouseholdWeeklyReportReady &&
        _matches(currentState.report, request)) {
      _emit(
        HouseholdWeeklyReportReady(
          report: currentState.report,
          refreshing: true,
        ),
      );
    } else {
      _emit(HouseholdWeeklyReportLoading(request));
    }

    final Future<void> load = _load(request, requestVersion);
    _pendingLoad = load;
    unawaited(
      load.whenComplete(() {
        if (_requestVersion == requestVersion) {
          _pendingRequest = null;
          _pendingLoad = null;
        }
      }),
    );
    return load;
  }

  Future<void> _load(
    HouseholdWeeklyReportRequest request,
    int requestVersion,
  ) async {
    final LoadHouseholdWeeklyReportResult result;
    try {
      result = await _repository.loadHouseholdWeeklyReport(request);
    } on Object {
      if (_isCurrent(requestVersion)) {
        _emit(
          HouseholdWeeklyReportFailed(
            request: request,
            failure: const ChoreFailure(ChoreFailureKind.internal),
          ),
        );
      }
      return;
    }
    if (!_isCurrent(requestVersion)) {
      return;
    }
    switch (result) {
      case HouseholdWeeklyReportLoaded(:final report):
        if (!_matches(report, request)) {
          _emit(
            HouseholdWeeklyReportFailed(
              request: request,
              failure: const ChoreFailure(ChoreFailureKind.invalidPayload),
            ),
          );
          return;
        }
        _emit(HouseholdWeeklyReportReady(report: report));
      case LoadHouseholdWeeklyReportFailed(:final failure):
        _emit(HouseholdWeeklyReportFailed(request: request, failure: failure));
    }
  }

  bool _matches(
    HouseholdWeeklyReport report,
    HouseholdWeeklyReportRequest request,
  ) {
    return report.householdId == request.householdId &&
        report.weekOffset == request.weekOffset;
  }

  bool _isCurrent(int requestVersion) {
    return !_disposed && _requestVersion == requestVersion;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _requestVersion += 1;
    await _states.close();
  }

  void _emit(HouseholdWeeklyReportState next) {
    if (_disposed) {
      return;
    }
    _state = next;
    _states.add(next);
  }
}
