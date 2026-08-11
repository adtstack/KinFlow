import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/analytics/application/analytics_dispatcher.dart';
import 'package:kinflow_app/features/analytics/application/analytics_preference_controller.dart';
import 'package:kinflow_app/features/analytics/application/analytics_preference_state.dart';
import 'package:kinflow_app/features/analytics/application/analytics_session_entry_coordinator.dart';
import 'package:kinflow_app/features/analytics/application/ports/analytics_sink.dart';
import 'package:kinflow_app/features/analytics/application/unavailable_analytics_dependencies.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';

final analyticsPreferenceRepositoryProvider =
    Provider<AnalyticsPreferenceRepository>((ref) {
      return const UnavailableAnalyticsPreferenceRepository();
    });

final analyticsSinkProvider = Provider<AnalyticsSink>((ref) {
  return const UnavailableAnalyticsSink();
});

final analyticsDispatchMetadataProvider = Provider<AnalyticsDispatchMetadata>((
  ref,
) {
  return const AnalyticsDispatchMetadata(
    appRelease: 'unavailable',
    environment: AnalyticsEnvironment.dev,
  );
});

final analyticsDispatcherProvider = Provider<AnalyticsDispatcher>((ref) {
  return AnalyticsDispatcher(
    ref.watch(analyticsPreferenceRepositoryProvider),
    ref.watch(analyticsSinkProvider),
    ref.watch(analyticsDispatchMetadataProvider),
  );
});

final analyticsSessionEntryCoordinatorProvider =
    Provider<AnalyticsSessionEntryCoordinator>((ref) {
      return AnalyticsSessionEntryCoordinator(
        ref.watch(analyticsDispatcherProvider),
      );
    });

final analyticsPreferenceControllerProvider =
    Provider.autoDispose<AnalyticsPreferenceController>((ref) {
      final AnalyticsPreferenceController controller =
          AnalyticsPreferenceController(
            ref.watch(analyticsPreferenceRepositoryProvider),
          );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final analyticsPreferenceProvider =
    NotifierProvider.autoDispose<
      AnalyticsPreferenceNotifier,
      AnalyticsPreferenceState
    >(AnalyticsPreferenceNotifier.new);

final class AnalyticsPreferenceNotifier
    extends Notifier<AnalyticsPreferenceState> {
  @override
  AnalyticsPreferenceState build() {
    final AnalyticsPreferenceController controller = ref.watch(
      analyticsPreferenceControllerProvider,
    );
    final StreamSubscription<AnalyticsPreferenceState> subscription = controller
        .states
        .listen((AnalyticsPreferenceState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load({bool preserveContent = false}) {
    return ref
        .read(analyticsPreferenceControllerProvider)
        .load(preserveContent: preserveContent);
  }

  Future<void> save(AnalyticsUsagePreference preference) {
    return ref.read(analyticsPreferenceControllerProvider).save(preference);
  }
}
