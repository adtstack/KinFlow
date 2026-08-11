import 'dart:async';
import 'dart:convert';

import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/chores/application/chore_completion_outbox.dart';
import 'package:kinflow_app/features/chores/domain/entities/pending_chore_completion.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

final class SecureChoreCompletionOutbox
    implements ChoreCompletionOutbox, SensitiveLocalStatePurgeParticipant {
  SecureChoreCompletionOutbox(
    this._store,
    this._scopeResolver, {
    this._clock = DateTime.now,
    this.maxEncodedBytes = 4096,
  });

  static const String contractVersion = '2026-08-09-wp05-10-v1';
  static const String storageKey = 'kinflow.chore_completion_outbox.v1';
  static const String requestedStatus = 'completed';
  static const Duration _clockSkew = Duration(minutes: 5);
  static const Set<String> _envelopeKeys = <String>{
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
  };
  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  final SecureStringStore _store;
  final ReadCacheSessionScopeResolver _scopeResolver;
  final ReadCacheClock _clock;
  final int maxEncodedBytes;

  Future<void> _tail = Future<void>.value();
  var _initialized = false;

  @override
  bool get isAvailable => true;

  @override
  Future<PendingChoreCompletion?> read({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedActorMemberId,
  }) {
    return _serialized<PendingChoreCompletion?>(() async {
      try {
        await _initialize();
        return await _readUnsafe(
          expectedHouseholdId: expectedHouseholdId,
          expectedActorMemberId: expectedActorMemberId,
        );
      } on Object {
        return null;
      }
    });
  }

  @override
  Future<ChoreCompletionOutboxEnqueueResult> enqueue({
    required HouseholdId householdId,
    required HouseholdMemberId actorMemberId,
    required ChoreOccurrenceId occurrenceId,
    required int expectedVersion,
    required ChoreCommandId idempotencyKey,
  }) {
    return _serialized<ChoreCompletionOutboxEnqueueResult>(() async {
      try {
        await _initialize();
        final ReadCacheSessionScope? scope = _scopeResolver.currentScope();
        final DateTime now = _clock().toUtc();
        if (!_isValidScope(scope, now)) {
          await _deleteUnsafe();
          return const ChoreCompletionOutboxUnavailable();
        }
        final PendingChoreCompletion? existing = await _readUnsafe(
          expectedHouseholdId: householdId,
          expectedActorMemberId: actorMemberId,
        );
        if (existing != null) {
          if (existing.occurrenceId == occurrenceId &&
              existing.expectedVersion == expectedVersion &&
              existing.idempotencyKey == idempotencyKey) {
            return ChoreCompletionOutboxEnqueued(existing, created: false);
          }
          return ChoreCompletionOutboxOccupied(existing);
        }
        final DateTime policyExpiry = now.add(
          PendingChoreCompletion.maximumAge,
        );
        final DateTime expiresAt = policyExpiry.isBefore(scope!.expiresAt)
            ? policyExpiry
            : scope.expiresAt;
        final PendingChoreCompletion? item = PendingChoreCompletion.tryCreate(
          householdId: householdId,
          actorMemberId: actorMemberId,
          occurrenceId: occurrenceId,
          expectedVersion: expectedVersion,
          idempotencyKey: idempotencyKey,
          createdAt: now,
          expiresAt: expiresAt,
          attemptCount: 0,
        );
        if (item == null || !await _writeUnsafe(item, scope)) {
          return const ChoreCompletionOutboxUnavailable();
        }
        return ChoreCompletionOutboxEnqueued(item, created: true);
      } on Object {
        return const ChoreCompletionOutboxUnavailable();
      }
    });
  }

  @override
  Future<PendingChoreCompletion?> markNextAttempt(
    PendingChoreCompletion expected,
  ) {
    return _serialized<PendingChoreCompletion?>(() async {
      try {
        await _initialize();
        final PendingChoreCompletion? current = await _readUnsafe(
          expectedHouseholdId: expected.householdId,
          expectedActorMemberId: expected.actorMemberId,
        );
        final PendingChoreCompletion? next = current == expected
            ? current?.nextAttempt()
            : null;
        final ReadCacheSessionScope? scope = _scopeResolver.currentScope();
        if (next == null ||
            !_isValidScope(scope, _clock().toUtc()) ||
            !await _writeUnsafe(next, scope!)) {
          return null;
        }
        return next;
      } on Object {
        return null;
      }
    });
  }

  @override
  Future<PendingChoreCompletion?> exhaustAutomaticAttempts(
    PendingChoreCompletion expected,
  ) {
    return _serialized<PendingChoreCompletion?>(() async {
      try {
        await _initialize();
        final PendingChoreCompletion? current = await _readUnsafe(
          expectedHouseholdId: expected.householdId,
          expectedActorMemberId: expected.actorMemberId,
        );
        final PendingChoreCompletion? exhausted = current == expected
            ? current?.exhaustAutomaticAttempts()
            : null;
        final ReadCacheSessionScope? scope = _scopeResolver.currentScope();
        if (exhausted == null ||
            !_isValidScope(scope, _clock().toUtc()) ||
            !await _writeUnsafe(exhausted, scope!)) {
          return null;
        }
        return exhausted;
      } on Object {
        return null;
      }
    });
  }

  @override
  Future<bool> clear() {
    return _serialized<bool>(() async {
      try {
        await _initialize();
        await _deleteUnsafe();
        return true;
      } on Object {
        return false;
      }
    });
  }

  @override
  Future<void> purgeSensitiveLocalState() {
    return _serialized<void>(() async {
      await _initialize();
      await _store.deleteAll();
    });
  }

  Future<PendingChoreCompletion?> _readUnsafe({
    required HouseholdId expectedHouseholdId,
    required HouseholdMemberId expectedActorMemberId,
  }) async {
    final ReadCacheSessionScope? scope = _scopeResolver.currentScope();
    final DateTime now = _clock().toUtc();
    if (!_isValidScope(scope, now)) {
      await _deleteUnsafe();
      return null;
    }
    final String? encoded = await _store.read(storageKey);
    if (encoded == null) {
      return null;
    }
    if (utf8.encode(encoded).length > maxEncodedBytes) {
      await _deleteUnsafe();
      return null;
    }
    final Map<String, Object?>? envelope = _decodeEnvelope(encoded);
    if (envelope == null ||
        envelope['contractVersion'] != contractVersion ||
        envelope['userId'] != scope!.userId ||
        envelope['sessionId'] != scope.sessionId ||
        envelope['requestedStatus'] != requestedStatus ||
        envelope['householdId'] is! String ||
        envelope['actorMemberId'] is! String ||
        envelope['occurrenceId'] is! String ||
        envelope['expectedVersion'] is! int ||
        envelope['idempotencyKey'] is! String ||
        envelope['createdAt'] is! String ||
        envelope['expiresAt'] is! String ||
        envelope['attemptCount'] is! int) {
      await _deleteUnsafe();
      return null;
    }
    final String householdValue = envelope['householdId']! as String;
    final String actorValue = envelope['actorMemberId']! as String;
    final String occurrenceValue = envelope['occurrenceId']! as String;
    final String commandValue = envelope['idempotencyKey']! as String;
    final HouseholdId? householdId = HouseholdId.tryParse(householdValue);
    final HouseholdMemberId? actorMemberId = HouseholdMemberId.tryParse(
      actorValue,
    );
    final ChoreOccurrenceId? occurrenceId = ChoreOccurrenceId.tryParse(
      occurrenceValue,
    );
    final ChoreCommandId? idempotencyKey = ChoreCommandId.tryParse(
      commandValue,
    );
    final DateTime? createdAt = _parseCanonicalUtc(
      envelope['createdAt']! as String,
    );
    final DateTime? expiresAt = _parseCanonicalUtc(
      envelope['expiresAt']! as String,
    );
    if (householdId == null ||
        householdId.value != householdValue ||
        householdId != expectedHouseholdId ||
        actorMemberId == null ||
        actorMemberId.value != actorValue ||
        actorMemberId != expectedActorMemberId ||
        occurrenceId == null ||
        occurrenceId.value != occurrenceValue ||
        idempotencyKey == null ||
        idempotencyKey.value != commandValue ||
        createdAt == null ||
        expiresAt == null ||
        createdAt.isAfter(now.add(_clockSkew)) ||
        expiresAt.isAfter(scope.expiresAt) ||
        !now.isBefore(expiresAt)) {
      await _deleteUnsafe();
      return null;
    }
    final PendingChoreCompletion? item = PendingChoreCompletion.tryCreate(
      householdId: householdId,
      actorMemberId: actorMemberId,
      occurrenceId: occurrenceId,
      expectedVersion: envelope['expectedVersion']! as int,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      expiresAt: expiresAt,
      attemptCount: envelope['attemptCount']! as int,
    );
    if (item == null) {
      await _deleteUnsafe();
    }
    return item;
  }

  Future<bool> _writeUnsafe(
    PendingChoreCompletion item,
    ReadCacheSessionScope scope,
  ) async {
    if (!_uuidPattern.hasMatch(scope.userId) ||
        !_uuidPattern.hasMatch(scope.sessionId) ||
        item.expiresAt.isAfter(scope.expiresAt)) {
      await _deleteUnsafe();
      return false;
    }
    final String encoded = jsonEncode(<String, Object>{
      'contractVersion': contractVersion,
      'userId': scope.userId,
      'sessionId': scope.sessionId,
      'householdId': item.householdId.value,
      'actorMemberId': item.actorMemberId.value,
      'occurrenceId': item.occurrenceId.value,
      'expectedVersion': item.expectedVersion,
      'requestedStatus': requestedStatus,
      'idempotencyKey': item.idempotencyKey.value,
      'createdAt': item.createdAt.toIso8601String(),
      'expiresAt': item.expiresAt.toIso8601String(),
      'attemptCount': item.attemptCount,
    });
    if (utf8.encode(encoded).length > maxEncodedBytes) {
      await _deleteUnsafe();
      return false;
    }
    await _store.write(storageKey, encoded);
    return true;
  }

  bool _isValidScope(ReadCacheSessionScope? scope, DateTime now) {
    return scope != null &&
        _uuidPattern.hasMatch(scope.userId) &&
        _uuidPattern.hasMatch(scope.sessionId) &&
        scope.expiresAt.isUtc &&
        now.isBefore(scope.expiresAt);
  }

  Map<String, Object?>? _decodeEnvelope(String encoded) {
    final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return null;
    }
    if (decoded is! Map || decoded.keys.any((Object? key) => key is! String)) {
      return null;
    }
    final Map<String, Object?> envelope = Map<String, Object?>.from(decoded);
    if (envelope.length != _envelopeKeys.length ||
        !envelope.keys.toSet().containsAll(_envelopeKeys)) {
      return null;
    }
    return envelope;
  }

  DateTime? _parseCanonicalUtc(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null || !parsed.isUtc || parsed.toIso8601String() != value) {
      return null;
    }
    return parsed;
  }

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }
    await _store.initialize();
    _initialized = true;
  }

  Future<void> _deleteUnsafe() => _store.delete(storageKey);

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final Completer<T> completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
