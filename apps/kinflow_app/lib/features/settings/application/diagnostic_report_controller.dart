import 'dart:async';

import 'package:kinflow_app/features/settings/application/diagnostic_report_state.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_clipboard.dart';
import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';

final class DiagnosticReportController {
  DiagnosticReportController(this._repository, this._clipboard);

  final DiagnosticReportRepository _repository;
  final DiagnosticClipboard _clipboard;
  final StreamController<DiagnosticReportState> _states =
      StreamController<DiagnosticReportState>.broadcast(sync: true);

  DiagnosticReportState _state = const DiagnosticReportInitial();
  Future<void> _pending = Future<void>.value();
  bool _busy = false;
  bool _disposed = false;

  DiagnosticReportState get state => _state;

  Stream<DiagnosticReportState> get states => _states.stream;

  Future<void> load({bool preserveContent = false}) {
    if (_busy || _disposed) return _pending;
    final DiagnosticReportReady? fallback =
        preserveContent && _state is DiagnosticReportReady
        ? _state as DiagnosticReportReady
        : null;
    _busy = true;
    _emit(
      fallback == null
          ? const DiagnosticReportLoading()
          : DiagnosticReportReady(report: fallback.report, isRefreshing: true),
    );
    _pending = _load(fallback).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> copy() {
    if (_busy || _disposed) return _pending;
    final DiagnosticReportState current = _state;
    if (current is! DiagnosticReportReady) return Future<void>.value();
    _busy = true;
    _emit(DiagnosticReportReady(report: current.report, isCopying: true));
    _pending = _copy(current).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> _load(DiagnosticReportReady? fallback) async {
    final DiagnosticReportResult result;
    try {
      result = await _repository.create();
    } on Object {
      _loadFailure(
        fallback,
        const DiagnosticReportFailure(DiagnosticReportFailureKind.internal),
      );
      return;
    }
    switch (result) {
      case DiagnosticReportSucceeded(:final report):
        _emit(DiagnosticReportReady(report: report));
      case DiagnosticReportFailed(:final failure):
        _loadFailure(fallback, failure);
    }
  }

  Future<void> _copy(DiagnosticReportReady previous) async {
    final bool copied;
    try {
      copied = await _clipboard.write(previous.report.toClipboardText());
    } on Object {
      _emit(
        DiagnosticReportReady(
          report: previous.report,
          notice: DiagnosticReportNotice.copyFailed,
        ),
      );
      return;
    }
    _emit(
      DiagnosticReportReady(
        report: previous.report,
        notice: copied
            ? DiagnosticReportNotice.copied
            : DiagnosticReportNotice.copyFailed,
      ),
    );
  }

  void _loadFailure(
    DiagnosticReportReady? fallback,
    DiagnosticReportFailure failure,
  ) {
    _emit(
      fallback == null
          ? DiagnosticReportLoadFailed(failure)
          : DiagnosticReportReady(
              report: fallback.report,
              notice: DiagnosticReportNotice.refreshFailed,
            ),
    );
  }

  void _emit(DiagnosticReportState next) {
    if (_disposed) return;
    _state = next;
    _states.add(next);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _states.close();
  }
}
