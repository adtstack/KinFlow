import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:kinflow_app/features/today/application/today_calendar_controller.dart';
import 'package:kinflow_app/features/today/application/today_calendar_state.dart';
import 'package:kinflow_app/features/today/application/today_calendar_snapshot_cache.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';

final todayCalendarSnapshotCacheProvider = Provider<TodayCalendarSnapshotCache>(
  (ref) {
    return const UnavailableTodayCalendarSnapshotCache();
  },
);

final todayCalendarControllerProvider =
    Provider.autoDispose<TodayCalendarController>((ref) {
      final TodayCalendarController controller = TodayCalendarController(
        repository: ref.watch(calendarRepositoryProvider),
        syncRepository: ref.watch(calendarSyncRepositoryProvider),
        snapshotCache: ref.watch(todayCalendarSnapshotCacheProvider),
      );
      ref.onDispose(() => unawaited(controller.dispose()));
      return controller;
    });

final todayCalendarProvider =
    NotifierProvider.autoDispose<TodayCalendarNotifier, TodayCalendarState>(
      TodayCalendarNotifier.new,
    );

final class TodayCalendarNotifier extends Notifier<TodayCalendarState> {
  @override
  TodayCalendarState build() {
    final TodayCalendarController controller = ref.watch(
      todayCalendarControllerProvider,
    );
    final StreamSubscription<TodayCalendarState> subscription = controller
        .states
        .listen((TodayCalendarState next) => state = next);
    ref.onDispose(() => unawaited(subscription.cancel()));
    return controller.state;
  }

  Future<void> load(TodayCalendarRequest request) {
    return ref.read(todayCalendarControllerProvider).load(request);
  }

  Future<void> refresh() {
    return ref.read(todayCalendarControllerProvider).refresh();
  }

  Future<void> resume() {
    return ref.read(todayCalendarControllerProvider).resume();
  }

  Future<void> reconnect() {
    return ref.read(todayCalendarControllerProvider).reconnect();
  }
}
