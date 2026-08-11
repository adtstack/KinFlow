import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/settings/application/diagnostic_report_controller.dart';
import 'package:kinflow_app/features/settings/application/diagnostic_report_state.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_clipboard.dart';
import 'package:kinflow_app/features/settings/application/unavailable_diagnostic_clipboard.dart';
import 'package:kinflow_app/features/settings/application/unavailable_diagnostic_report_repository.dart';
import 'package:kinflow_app/features/settings/domain/repositories/diagnostic_report_repository.dart';

final diagnosticReportRepositoryProvider = Provider<DiagnosticReportRepository>(
  (ref) => const UnavailableDiagnosticReportRepository(),
);

final diagnosticClipboardProvider = Provider<DiagnosticClipboard>(
  (ref) => const UnavailableDiagnosticClipboard(),
);

final diagnosticReportControllerProvider =
    Provider.autoDispose<DiagnosticReportController>((ref) {
      final DiagnosticReportController controller = DiagnosticReportController(
        ref.watch(diagnosticReportRepositoryProvider),
        ref.watch(diagnosticClipboardProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final diagnosticReportProvider =
    NotifierProvider.autoDispose<
      DiagnosticReportNotifier,
      DiagnosticReportState
    >(DiagnosticReportNotifier.new);

final class DiagnosticReportNotifier extends Notifier<DiagnosticReportState> {
  @override
  DiagnosticReportState build() {
    final DiagnosticReportController controller = ref.watch(
      diagnosticReportControllerProvider,
    );
    final StreamSubscription<DiagnosticReportState> subscription = controller
        .states
        .listen((DiagnosticReportState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load({bool preserveContent = false}) {
    return ref
        .read(diagnosticReportControllerProvider)
        .load(preserveContent: preserveContent);
  }

  Future<void> copy() {
    return ref.read(diagnosticReportControllerProvider).copy();
  }
}
