import 'package:kinflow_app/features/household/data/datasources/household_data_source.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';

final class CachedHouseholdDataSource
    implements HouseholdDataSource, ActiveHouseholdSnapshotWriter {
  const CachedHouseholdDataSource(this._delegate, this._cache);

  static const Set<String> _payloadKeys = <String>{'householdId', 'memberId'};

  final HouseholdDataSource _delegate;
  final ReadCache _cache;

  @override
  Future<LoadActiveHouseholdDataResult> loadActiveHousehold() async {
    final LoadActiveHouseholdDataResult result = await _delegate
        .loadActiveHousehold();
    switch (result) {
      case ActiveHouseholdDataFound(:final record):
        if (!await _replaceRecord(record)) {
          return const LoadActiveHouseholdDataFailed(
            HouseholdDataFailureKind.unknown,
          );
        }
        return result;
      case ActiveHouseholdDataAbsent():
        if (!await _cache.clear()) {
          return const LoadActiveHouseholdDataFailed(
            HouseholdDataFailureKind.unknown,
          );
        }
        return result;
      case LoadActiveHouseholdDataFailed(
        kind: HouseholdDataFailureKind.temporarilyUnavailable,
      ):
        final ReadCacheRecord? cached = await _cache.read(
          ReadCacheSlot.activeHousehold,
        );
        final ActiveHouseholdRecord? record = _recordFromPayload(
          cached?.payload,
          expectedHouseholdId: cached?.householdId,
        );
        if (cached == null || record == null) {
          if (cached != null) {
            await _cache.delete(ReadCacheSlot.activeHousehold);
          }
          return result;
        }
        return ActiveHouseholdDataFound(record, cacheMetadata: cached.metadata);
      case LoadActiveHouseholdDataFailed(:final kind):
        if (kind == HouseholdDataFailureKind.unauthenticated ||
            kind == HouseholdDataFailureKind.invalidPayload) {
          await _cache.clear();
        }
        return result;
    }
  }

  @override
  Future<CreateFirstHouseholdDataResult> createFirstHousehold({
    required String idempotencyKey,
    required String householdName,
    required String ownerDisplayName,
    required String locale,
    required String timezone,
  }) async {
    final CreateFirstHouseholdDataResult result = await _delegate
        .createFirstHousehold(
          idempotencyKey: idempotencyKey,
          householdName: householdName,
          ownerDisplayName: ownerDisplayName,
          locale: locale,
          timezone: timezone,
        );
    if (result is FirstHouseholdDataCreated &&
        !await _replaceRecord(result.record)) {
      return const CreateFirstHouseholdDataFailed(
        HouseholdDataFailureKind.unknown,
      );
    }
    return result;
  }

  @override
  Future<bool> replace(ActiveHousehold household) {
    return _replaceRecord(
      ActiveHouseholdRecord(
        householdId: household.householdId.value,
        memberId: household.memberId.value,
      ),
    );
  }

  @override
  Future<bool> clear() => _cache.clear();

  Future<bool> _replaceRecord(ActiveHouseholdRecord record) async {
    await Future.wait<ReadCacheRecord?>(<Future<ReadCacheRecord?>>[
      _cache.read(
        ReadCacheSlot.choreList,
        expectedHouseholdId: record.householdId,
      ),
      _cache.read(
        ReadCacheSlot.todayChores,
        expectedHouseholdId: record.householdId,
      ),
      _cache.read(
        ReadCacheSlot.todayCalendar,
        expectedHouseholdId: record.householdId,
      ),
    ]);
    return _cache.write(
      ReadCacheSlot.activeHousehold,
      householdId: record.householdId,
      payload: <String, Object?>{
        'householdId': record.householdId,
        'memberId': record.memberId,
      },
    );
  }

  ActiveHouseholdRecord? _recordFromPayload(
    Object? payload, {
    required String? expectedHouseholdId,
  }) {
    if (payload is! Map || payload.keys.any((Object? key) => key is! String)) {
      return null;
    }
    final Map<String, Object?> value = Map<String, Object?>.from(payload);
    if (value.length != _payloadKeys.length ||
        !value.keys.toSet().containsAll(_payloadKeys) ||
        value['householdId'] is! String ||
        value['memberId'] is! String ||
        value['householdId'] != expectedHouseholdId) {
      return null;
    }
    return ActiveHouseholdRecord(
      householdId: value['householdId']! as String,
      memberId: value['memberId']! as String,
    );
  }
}
