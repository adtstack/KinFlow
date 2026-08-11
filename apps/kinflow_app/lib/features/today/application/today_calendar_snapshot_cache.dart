import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/features/today/domain/entities/today_snapshot.dart';

final class CachedTodayCalendarSnapshot {
  const CachedTodayCalendarSnapshot({
    required this.snapshot,
    required this.metadata,
  });

  final TodayCalendarSnapshot snapshot;
  final ReadCacheMetadata metadata;
}

abstract interface class TodayCalendarSnapshotCache {
  Future<CachedTodayCalendarSnapshot?> read(TodayCalendarRequest request);

  Future<bool> write(TodayCalendarSnapshot snapshot);

  Future<bool> delete();

  Future<bool> clearAll();
}

final class UnavailableTodayCalendarSnapshotCache
    implements TodayCalendarSnapshotCache {
  const UnavailableTodayCalendarSnapshotCache();

  @override
  Future<CachedTodayCalendarSnapshot?> read(
    TodayCalendarRequest request,
  ) async => null;

  @override
  Future<bool> write(TodayCalendarSnapshot snapshot) async => true;

  @override
  Future<bool> delete() async => true;

  @override
  Future<bool> clearAll() async => true;
}
