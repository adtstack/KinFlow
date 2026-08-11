import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/application/diagnostic_report_controller.dart';
import 'package:kinflow_app/features/settings/application/diagnostic_report_state.dart';
import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';

import '../../support/fakes/fake_diagnostic_dependencies.dart';

void main() {
  test('loads the authoritative local report', () async {
    final DiagnosticReportController controller = DiagnosticReportController(
      FakeDiagnosticReportRepository(),
      FakeDiagnosticClipboard(),
    );
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.state, isA<DiagnosticReportReady>());
  });

  test('copy writes only the deterministic safe JSON', () async {
    final FakeDiagnosticClipboard clipboard = FakeDiagnosticClipboard();
    final DiagnosticReportController controller = DiagnosticReportController(
      FakeDiagnosticReportRepository(),
      clipboard,
    );
    addTearDown(controller.dispose);
    await controller.load();
    final DiagnosticReportReady loaded =
        controller.state as DiagnosticReportReady;

    await controller.copy();

    expect(clipboard.writes, <String>[loaded.report.toClipboardText()]);
    expect(
      (controller.state as DiagnosticReportReady).notice,
      DiagnosticReportNotice.copied,
    );
  });

  test('duplicate copy shares one in-flight clipboard write', () async {
    final Completer<bool> pending = Completer<bool>();
    final FakeDiagnosticClipboard clipboard = FakeDiagnosticClipboard(
      pending: pending,
    );
    final DiagnosticReportController controller = DiagnosticReportController(
      FakeDiagnosticReportRepository(),
      clipboard,
    );
    addTearDown(controller.dispose);
    await controller.load();

    final Future<void> first = controller.copy();
    final Future<void> second = controller.copy();

    expect(clipboard.writes, hasLength(1));
    pending.complete(true);
    await Future.wait(<Future<void>>[first, second]);
    expect(clipboard.writes, hasLength(1));
  });

  test(
    'clipboard rejection preserves report and exposes safe notice',
    () async {
      final DiagnosticReportController controller = DiagnosticReportController(
        FakeDiagnosticReportRepository(),
        FakeDiagnosticClipboard(results: <bool>[false]),
      );
      addTearDown(controller.dispose);
      await controller.load();
      final DiagnosticReportReady previous =
          controller.state as DiagnosticReportReady;

      await controller.copy();

      final DiagnosticReportReady state =
          controller.state as DiagnosticReportReady;
      expect(state.report, same(previous.report));
      expect(state.notice, DiagnosticReportNotice.copyFailed);
    },
  );

  test('refresh failure preserves the prior report and incident ID', () async {
    final report = diagnosticReportFixture();
    final FakeDiagnosticReportRepository repository =
        FakeDiagnosticReportRepository(
          results: <DiagnosticReportResult>[
            DiagnosticReportSucceeded(report),
            const DiagnosticReportFailed(
              DiagnosticReportFailure(DiagnosticReportFailureKind.unavailable),
            ),
          ],
        );
    final DiagnosticReportController controller = DiagnosticReportController(
      repository,
      FakeDiagnosticClipboard(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await controller.load(preserveContent: true);

    final DiagnosticReportReady state =
        controller.state as DiagnosticReportReady;
    expect(state.report, same(report));
    expect(state.notice, DiagnosticReportNotice.refreshFailed);
  });

  test('duplicate generation sends one request while pending', () async {
    final Completer<DiagnosticReportResult> pending =
        Completer<DiagnosticReportResult>();
    final FakeDiagnosticReportRepository repository =
        FakeDiagnosticReportRepository(pending: pending);
    final DiagnosticReportController controller = DiagnosticReportController(
      repository,
      FakeDiagnosticClipboard(),
    );
    addTearDown(controller.dispose);

    final Future<void> first = controller.load();
    final Future<void> second = controller.load();

    expect(repository.createCalls, 1);
    pending.complete(DiagnosticReportSucceeded(diagnosticReportFixture()));
    await Future.wait(<Future<void>>[first, second]);
    expect(repository.createCalls, 1);
  });
}
