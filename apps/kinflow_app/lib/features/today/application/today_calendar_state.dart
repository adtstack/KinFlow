import 'package:kinflow_app/features/calendar/domain/failures/calendar_failure.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';

sealed class TodayCalendarState {
  const TodayCalendarState();
}

final class TodayCalendarInitial extends TodayCalendarState {
  const TodayCalendarInitial();
}

final class TodayCalendarLoading extends TodayCalendarState {
  const TodayCalendarLoading();
}

final class TodayCalendarReady extends TodayCalendarState {
  const TodayCalendarReady(
    this.snapshot, {
    this.refreshing = false,
    this.refreshFailure,
    this.syncStatus = CalendarSyncConnectionStatus.disabled,
    this.cacheMetadata,
  });

  final TodayCalendarSnapshot snapshot;
  final bool refreshing;
  final CalendarFailure? refreshFailure;
  final CalendarSyncConnectionStatus syncStatus;
  final ReadCacheMetadata? cacheMetadata;

  bool get isReadOnlyCache => cacheMetadata != null;
}

final class TodayCalendarLoadFailed extends TodayCalendarState {
  const TodayCalendarLoadFailed(this.failure);

  final CalendarFailure failure;
}
