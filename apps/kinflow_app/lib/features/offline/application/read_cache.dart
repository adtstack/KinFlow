import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';

typedef ReadCacheClock = DateTime Function();

enum ReadCacheSlot {
  activeHousehold('active_household_v1'),
  choreList('chore_list_v1'),
  todayChores('today_chores_v1'),
  todayCalendar('today_calendar_v1');

  const ReadCacheSlot(this.storageKey);

  final String storageKey;
}

final class ReadCacheSessionScope {
  ReadCacheSessionScope({
    required this.userId,
    required this.sessionId,
    required this.expiresAt,
  }) : assert(userId.isNotEmpty),
       assert(sessionId.isNotEmpty),
       assert(expiresAt.isUtc);

  final String userId;
  final String sessionId;
  final DateTime expiresAt;
}

abstract interface class ReadCacheSessionScopeResolver {
  ReadCacheSessionScope? currentScope();
}

final class ReadCacheRecord {
  const ReadCacheRecord({
    required this.householdId,
    required this.payload,
    required this.metadata,
  });

  final String householdId;
  final Object? payload;
  final ReadCacheMetadata metadata;
}

abstract interface class ReadCache {
  Future<ReadCacheRecord?> read(
    ReadCacheSlot slot, {
    String? expectedHouseholdId,
  });

  Future<bool> write(
    ReadCacheSlot slot, {
    required String householdId,
    required Object? payload,
    DateTime? validatedAt,
  });

  Future<bool> delete(ReadCacheSlot slot);

  Future<bool> clear();
}
