import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/features/offline/data/services/secure_read_cache.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

void main() {
  const String userId = '11111111-1111-4111-8111-111111111111';
  const String sessionId = '22222222-2222-4222-8222-222222222222';
  const String householdId = '33333333-3333-4333-8333-333333333333';
  final DateTime now = DateTime.parse('2026-08-08T01:00:00.000Z');

  test(
    'round-trips a versioned record within the exact session scope',
    () async {
      final _MemorySecureStringStore store = _MemorySecureStringStore();
      final _MutableScopeResolver resolver = _MutableScopeResolver(
        ReadCacheSessionScope(
          userId: userId,
          sessionId: sessionId,
          expiresAt: now.add(const Duration(hours: 2)),
        ),
      );
      final SecureReadCache cache = SecureReadCache(
        store,
        resolver,
        clock: () => now,
      );
      final DateTime validatedAt = now.subtract(const Duration(minutes: 10));

      expect(
        await cache.write(
          ReadCacheSlot.activeHousehold,
          householdId: householdId,
          payload: const <String, Object?>{'memberId': 'member-1'},
          validatedAt: validatedAt,
        ),
        isTrue,
      );

      final String encoded = store.values['active_household_v1']!;
      final Map<String, Object?> envelope = Map<String, Object?>.from(
        jsonDecode(encoded) as Map<dynamic, dynamic>,
      );
      expect(envelope.keys, <String>[
        'contractVersion',
        'userId',
        'sessionId',
        'householdId',
        'validatedAt',
        'expiresAt',
        'payload',
      ]);
      expect(envelope['contractVersion'], SecureReadCache.contractVersion);
      expect(envelope['userId'], userId);
      expect(envelope['sessionId'], sessionId);

      final ReadCacheRecord? record = await cache.read(
        ReadCacheSlot.activeHousehold,
        expectedHouseholdId: householdId,
      );

      expect(record?.householdId, householdId);
      expect(record?.payload, const <String, Object?>{'memberId': 'member-1'});
      expect(record?.metadata.validatedAt, validatedAt);
      expect(record?.metadata.expiresAt, now.add(const Duration(hours: 2)));
      expect(store.initializationCount, 1);
    },
  );

  test(
    'rejects and deletes records after session or household changes',
    () async {
      final _MemorySecureStringStore store = _MemorySecureStringStore();
      final _MutableScopeResolver resolver = _MutableScopeResolver(
        ReadCacheSessionScope(
          userId: userId,
          sessionId: sessionId,
          expiresAt: now.add(const Duration(hours: 4)),
        ),
      );
      final SecureReadCache cache = SecureReadCache(
        store,
        resolver,
        clock: () => now,
      );
      await cache.write(
        ReadCacheSlot.todayChores,
        householdId: householdId,
        payload: const <Object?>['cached'],
      );
      resolver.scope = ReadCacheSessionScope(
        userId: userId,
        sessionId: '44444444-4444-4444-8444-444444444444',
        expiresAt: now.add(const Duration(hours: 4)),
      );

      expect(await cache.read(ReadCacheSlot.todayChores), isNull);
      expect(store.values, isNot(contains('today_chores_v1')));

      resolver.scope = ReadCacheSessionScope(
        userId: userId,
        sessionId: sessionId,
        expiresAt: now.add(const Duration(hours: 4)),
      );
      await cache.write(
        ReadCacheSlot.todayChores,
        householdId: householdId,
        payload: const <Object?>['cached'],
      );

      expect(
        await cache.read(
          ReadCacheSlot.todayChores,
          expectedHouseholdId: '55555555-5555-4555-8555-555555555555',
        ),
        isNull,
      );
      expect(store.values, isNot(contains('today_chores_v1')));
    },
  );

  test(
    'expires at the session boundary and fails closed without a session',
    () async {
      var clock = now;
      final _MemorySecureStringStore store = _MemorySecureStringStore();
      final _MutableScopeResolver resolver = _MutableScopeResolver(
        ReadCacheSessionScope(
          userId: userId,
          sessionId: sessionId,
          expiresAt: now.add(const Duration(hours: 1)),
        ),
      );
      final SecureReadCache cache = SecureReadCache(
        store,
        resolver,
        clock: () => clock,
      );
      await cache.write(
        ReadCacheSlot.choreList,
        householdId: householdId,
        payload: const <Object?>['cached'],
      );
      clock = now.add(const Duration(hours: 1));

      expect(await cache.read(ReadCacheSlot.choreList), isNull);
      expect(store.values, isEmpty);

      clock = now;
      resolver.scope = null;
      store.values['chore_list_v1'] = 'opaque';
      expect(await cache.read(ReadCacheSlot.choreList), isNull);
      expect(store.values, isEmpty);
    },
  );

  test('deletes malformed records and refuses oversized writes', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    final _MutableScopeResolver resolver = _MutableScopeResolver(
      ReadCacheSessionScope(
        userId: userId,
        sessionId: sessionId,
        expiresAt: now.add(const Duration(hours: 2)),
      ),
    );
    final SecureReadCache cache = SecureReadCache(
      store,
      resolver,
      clock: () => now,
      maxEncodedBytes: 256,
    );
    store.values['active_household_v1'] = '{malformed';

    expect(await cache.read(ReadCacheSlot.activeHousehold), isNull);
    expect(store.values, isEmpty);
    expect(
      await cache.write(
        ReadCacheSlot.activeHousehold,
        householdId: householdId,
        payload: <String, Object?>{
          'large': List<String>.filled(512, 'x').join(),
        },
      ),
      isFalse,
    );
    expect(store.values, isEmpty);
  });

  test('clear and auth purge remove every fixed cache slot', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    final _MutableScopeResolver resolver = _MutableScopeResolver(
      ReadCacheSessionScope(
        userId: userId,
        sessionId: sessionId,
        expiresAt: now.add(const Duration(hours: 2)),
      ),
    );
    final SecureReadCache cache = SecureReadCache(
      store,
      resolver,
      clock: () => now,
    );
    for (final ReadCacheSlot slot in ReadCacheSlot.values) {
      await cache.write(
        slot,
        householdId: householdId,
        payload: <String, Object?>{'slot': slot.name},
      );
    }
    expect(store.values, hasLength(4));

    expect(await cache.clear(), isTrue);
    expect(store.values, isEmpty);
    await cache.write(
      ReadCacheSlot.activeHousehold,
      householdId: householdId,
      payload: const <String, Object?>{'memberId': 'member-1'},
    );

    await cache.purgeSensitiveLocalState();
    expect(store.values, isEmpty);
    expect(store.deleteAllCount, 2);
  });
}

final class _MutableScopeResolver implements ReadCacheSessionScopeResolver {
  _MutableScopeResolver(this.scope);

  ReadCacheSessionScope? scope;

  @override
  ReadCacheSessionScope? currentScope() => scope;
}

final class _MemorySecureStringStore implements SecureStringStore {
  final Map<String, String> values = <String, String>{};
  var initializationCount = 0;
  var deleteAllCount = 0;

  @override
  Future<void> initialize() async {
    initializationCount += 1;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCount += 1;
    values.clear();
  }
}
