import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/chores/application/chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/data/services/secure_chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/domain/entities/pending_chore_completion.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

void main() {
  const String userId = '11111111-1111-4111-8111-111111111111';
  const String sessionId = '22222222-2222-4222-8222-222222222222';
  final HouseholdId householdId = HouseholdId.tryParse(
    '33333333-3333-4333-8333-333333333333',
  )!;
  final HouseholdMemberId actorMemberId = HouseholdMemberId.tryParse(
    '44444444-4444-4444-8444-444444444444',
  )!;
  final ChoreOccurrenceId occurrenceId = ChoreOccurrenceId.tryParse(
    '55555555-5555-4555-8555-555555555555',
  )!;
  final ChoreCommandId commandId = ChoreCommandId.tryParse(
    '66666666-6666-4666-8666-666666666666',
  )!;
  final DateTime now = DateTime.parse('2026-08-09T02:00:00.000Z');

  late _MemorySecureStringStore store;
  late _MutableScopeResolver resolver;
  late SecureChoreCompletionOutbox outbox;

  setUp(() {
    store = _MemorySecureStringStore();
    resolver = _MutableScopeResolver(
      ReadCacheSessionScope(
        userId: userId,
        sessionId: sessionId,
        expiresAt: now.add(const Duration(hours: 2)),
      ),
    );
    outbox = SecureChoreCompletionOutbox(store, resolver, clock: () => now);
  });

  test('writes and reads the exact encrypted-envelope contract', () async {
    final ChoreCompletionOutboxEnqueueResult result = await outbox.enqueue(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: 7,
      idempotencyKey: commandId,
    );

    expect(result, isA<ChoreCompletionOutboxEnqueued>());
    final ChoreCompletionOutboxEnqueued stored =
        result as ChoreCompletionOutboxEnqueued;
    expect(stored.created, isTrue);
    expect(stored.item.expiresAt, now.add(const Duration(minutes: 30)));
    final Map<String, Object?> envelope = Map<String, Object?>.from(
      jsonDecode(store.values[SecureChoreCompletionOutbox.storageKey]!)
          as Map<dynamic, dynamic>,
    );
    expect(envelope.keys, <String>[
      'contractVersion',
      'userId',
      'sessionId',
      'householdId',
      'actorMemberId',
      'occurrenceId',
      'expectedVersion',
      'requestedStatus',
      'idempotencyKey',
      'createdAt',
      'expiresAt',
      'attemptCount',
    ]);
    expect(envelope['requestedStatus'], 'completed');
    expect(envelope['attemptCount'], 0);

    final PendingChoreCompletion? read = await outbox.read(
      expectedHouseholdId: householdId,
      expectedActorMemberId: actorMemberId,
    );
    expect(read, stored.item);
    expect(store.initializationCount, 1);
  });

  test('clamps expiry to the current access-session expiry', () async {
    resolver.scope = ReadCacheSessionScope(
      userId: userId,
      sessionId: sessionId,
      expiresAt: now.add(const Duration(minutes: 12)),
    );

    final ChoreCompletionOutboxEnqueued result =
        await outbox.enqueue(
              householdId: householdId,
              actorMemberId: actorMemberId,
              occurrenceId: occurrenceId,
              expectedVersion: 1,
              idempotencyKey: commandId,
            )
            as ChoreCompletionOutboxEnqueued;

    expect(result.item.expiresAt, now.add(const Duration(minutes: 12)));
  });

  test('is idempotent for one exact item and rejects a second item', () async {
    final ChoreCompletionOutboxEnqueueResult first = await outbox.enqueue(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: 2,
      idempotencyKey: commandId,
    );
    final ChoreCompletionOutboxEnqueueResult duplicate = await outbox.enqueue(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: 2,
      idempotencyKey: commandId,
    );
    final ChoreCompletionOutboxEnqueueResult occupied = await outbox.enqueue(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: ChoreOccurrenceId.tryParse(
        '77777777-7777-4777-8777-777777777777',
      )!,
      expectedVersion: 1,
      idempotencyKey: ChoreCommandId.tryParse(
        '88888888-8888-4888-8888-888888888888',
      )!,
    );

    expect(first, isA<ChoreCompletionOutboxEnqueued>());
    expect((duplicate as ChoreCompletionOutboxEnqueued).created, isFalse);
    expect(occupied, isA<ChoreCompletionOutboxOccupied>());
    expect(store.writeCount, 1);
  });

  test('persists every attempt before returning the next item', () async {
    final ChoreCompletionOutboxEnqueued result =
        await outbox.enqueue(
              householdId: householdId,
              actorMemberId: actorMemberId,
              occurrenceId: occurrenceId,
              expectedVersion: 4,
              idempotencyKey: commandId,
            )
            as ChoreCompletionOutboxEnqueued;
    PendingChoreCompletion? item = result.item;

    for (var attempt = 1; attempt <= 3; attempt += 1) {
      item = await outbox.markNextAttempt(item!);
      expect(item?.attemptCount, attempt);
      final Map<String, Object?> envelope = Map<String, Object?>.from(
        jsonDecode(store.values[SecureChoreCompletionOutbox.storageKey]!)
            as Map<dynamic, dynamic>,
      );
      expect(envelope['attemptCount'], attempt);
    }
    expect(await outbox.markNextAttempt(item!), isNull);
  });

  test('persists terminal replay exhaustion for the exact item', () async {
    final ChoreCompletionOutboxEnqueued result =
        await outbox.enqueue(
              householdId: householdId,
              actorMemberId: actorMemberId,
              occurrenceId: occurrenceId,
              expectedVersion: 4,
              idempotencyKey: commandId,
            )
            as ChoreCompletionOutboxEnqueued;
    final PendingChoreCompletion exhausted = (await outbox
        .exhaustAutomaticAttempts(result.item))!;

    expect(exhausted.attemptCount, 3);
    expect(exhausted.canAttemptAutomatically, isFalse);
    expect(
      (await outbox.read(
        expectedHouseholdId: householdId,
        expectedActorMemberId: actorMemberId,
      ))?.attemptCount,
      3,
    );
    expect(await outbox.markNextAttempt(exhausted), isNull);
  });

  test('purges on exact session, household, or actor mismatch', () async {
    Future<void> seed() async {
      await outbox.enqueue(
        householdId: householdId,
        actorMemberId: actorMemberId,
        occurrenceId: occurrenceId,
        expectedVersion: 1,
        idempotencyKey: commandId,
      );
    }

    await seed();
    resolver.scope = ReadCacheSessionScope(
      userId: userId,
      sessionId: '99999999-9999-4999-8999-999999999999',
      expiresAt: now.add(const Duration(hours: 2)),
    );
    expect(
      await outbox.read(
        expectedHouseholdId: householdId,
        expectedActorMemberId: actorMemberId,
      ),
      isNull,
    );
    expect(store.values, isEmpty);

    resolver.scope = ReadCacheSessionScope(
      userId: userId,
      sessionId: sessionId,
      expiresAt: now.add(const Duration(hours: 2)),
    );
    await seed();
    expect(
      await outbox.read(
        expectedHouseholdId: HouseholdId.tryParse(
          'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        )!,
        expectedActorMemberId: actorMemberId,
      ),
      isNull,
    );
    expect(store.values, isEmpty);

    await seed();
    expect(
      await outbox.read(
        expectedHouseholdId: householdId,
        expectedActorMemberId: HouseholdMemberId.tryParse(
          'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        )!,
      ),
      isNull,
    );
    expect(store.values, isEmpty);
  });

  test('deletes malformed, extra-key, expired, and oversized values', () async {
    store.values[SecureChoreCompletionOutbox.storageKey] = '{malformed';
    expect(
      await outbox.read(
        expectedHouseholdId: householdId,
        expectedActorMemberId: actorMemberId,
      ),
      isNull,
    );
    expect(store.values, isEmpty);

    final ChoreCompletionOutboxEnqueued result =
        await outbox.enqueue(
              householdId: householdId,
              actorMemberId: actorMemberId,
              occurrenceId: occurrenceId,
              expectedVersion: 1,
              idempotencyKey: commandId,
            )
            as ChoreCompletionOutboxEnqueued;
    final Map<String, Object?> withExtra = Map<String, Object?>.from(
      jsonDecode(store.values[SecureChoreCompletionOutbox.storageKey]!)
          as Map<dynamic, dynamic>,
    )..['extra'] = true;
    store.values[SecureChoreCompletionOutbox.storageKey] = jsonEncode(
      withExtra,
    );
    expect(
      await outbox.read(
        expectedHouseholdId: householdId,
        expectedActorMemberId: actorMemberId,
      ),
      isNull,
    );

    store.values[SecureChoreCompletionOutbox.storageKey] = jsonEncode(
      <String, Object?>{'large': List<String>.filled(5000, 'x').join()},
    );
    expect(
      await outbox.read(
        expectedHouseholdId: householdId,
        expectedActorMemberId: actorMemberId,
      ),
      isNull,
    );
    expect(store.values, isEmpty);
    expect(result.item.attemptCount, 0);
  });

  test('purges a command at its exact bounded expiry', () async {
    var clock = now;
    final _MemorySecureStringStore expiringStore = _MemorySecureStringStore();
    final SecureChoreCompletionOutbox expiringOutbox =
        SecureChoreCompletionOutbox(
          expiringStore,
          resolver,
          clock: () => clock,
        );
    await expiringOutbox.enqueue(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: 1,
      idempotencyKey: commandId,
    );
    clock = now.add(const Duration(minutes: 30));

    expect(
      await expiringOutbox.read(
        expectedHouseholdId: householdId,
        expectedActorMemberId: actorMemberId,
      ),
      isNull,
    );
    expect(expiringStore.values, isEmpty);
  });

  test('fails closed without a session and supports auth purge', () async {
    resolver.scope = null;
    expect(
      await outbox.enqueue(
        householdId: householdId,
        actorMemberId: actorMemberId,
        occurrenceId: occurrenceId,
        expectedVersion: 1,
        idempotencyKey: commandId,
      ),
      isA<ChoreCompletionOutboxUnavailable>(),
    );

    resolver.scope = ReadCacheSessionScope(
      userId: userId,
      sessionId: sessionId,
      expiresAt: now.add(const Duration(hours: 1)),
    );
    await outbox.enqueue(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: 1,
      idempotencyKey: commandId,
    );
    await outbox.purgeSensitiveLocalState();

    expect(store.values, isEmpty);
    expect(store.deleteAllCount, 1);
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
  var writeCount = 0;
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
    writeCount += 1;
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
