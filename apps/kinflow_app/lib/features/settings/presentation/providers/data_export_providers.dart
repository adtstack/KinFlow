import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/presentation/providers/recent_authentication_provider.dart';
import 'package:kinflow_app/features/settings/application/data_export_controller.dart';
import 'package:kinflow_app/features/settings/application/data_export_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/repositories/data_export_repository.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_command_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/services/data_export_download_launcher.dart';

final dataExportRepositoryProvider = Provider<DataExportRepository>((ref) {
  throw StateError('DataExportRepository override is required.');
});

final dataExportCommandIdGeneratorProvider =
    Provider<DataExportCommandIdGenerator>((ref) {
      throw StateError('DataExportCommandIdGenerator override is required.');
    });

final dataExportDownloadLauncherProvider = Provider<DataExportDownloadLauncher>(
  (ref) {
    throw StateError('DataExportDownloadLauncher override is required.');
  },
);

final dataExportControllerProvider = Provider.autoDispose<DataExportController>(
  (ref) {
    final DataExportController controller = DataExportController(
      ref.watch(dataExportRepositoryProvider),
      ref.watch(dataExportCommandIdGeneratorProvider),
      ref.watch(recentAuthenticationServiceProvider),
      ref.watch(dataExportDownloadLauncherProvider),
    );
    ref.onDispose(() => unawaited(controller.dispose()));
    return controller;
  },
);

final dataExportProvider =
    NotifierProvider.autoDispose<DataExportNotifier, DataExportState>(
      DataExportNotifier.new,
    );

final class DataExportNotifier extends Notifier<DataExportState> {
  @override
  DataExportState build() {
    final DataExportController controller = ref.watch(
      dataExportControllerProvider,
    );
    final StreamSubscription<DataExportState> subscription = controller.states
        .listen((DataExportState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load({bool preserveContent = false}) {
    return ref
        .read(dataExportControllerProvider)
        .load(preserveContent: preserveContent);
  }

  Future<void> requestExport() {
    return ref.read(dataExportControllerProvider).requestExport();
  }

  Future<void> cancel() {
    return ref.read(dataExportControllerProvider).cancel();
  }

  Future<void> revoke() {
    return ref.read(dataExportControllerProvider).revoke();
  }

  Future<void> download(DataExportFormat format) {
    return ref.read(dataExportControllerProvider).download(format);
  }
}
