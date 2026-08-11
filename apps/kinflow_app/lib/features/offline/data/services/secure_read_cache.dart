import 'dart:async';
import 'dart:convert';

import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/features/offline/domain/read_cache_metadata.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

final class SecureReadCache
    implements ReadCache, SensitiveLocalStatePurgeParticipant {
  SecureReadCache(
    this._store,
    this._scopeResolver, {
    this._clock = DateTime.now,
    this.maxAge = const Duration(hours: 24),
    this.maxEncodedBytes = 196608,
  });

  static const String contractVersion = '2026-08-08-wp05-06-v1';
  static const Set<String> _envelopeKeys = <String>{
    'contractVersion',
    'userId',
    'sessionId',
    'householdId',
    'validatedAt',
    'expiresAt',
    'payload',
  };
  static const Duration _clockSkew = Duration(minutes: 5);

  final SecureStringStore _store;
  final ReadCacheSessionScopeResolver _scopeResolver;
  final ReadCacheClock _clock;
  final Duration maxAge;
  final int maxEncodedBytes;

  Future<void> _tail = Future<void>.value();
  var _initialized = false;

  @override
  Future<ReadCacheRecord?> read(
    ReadCacheSlot slot, {
    String? expectedHouseholdId,
  }) {
    return _serialized<ReadCacheRecord?>(() async {
      try {
        await _initialize();
        final ReadCacheSessionScope? scope = _scopeResolver.currentScope();
        if (scope == null) {
          await _deleteUnsafe(slot);
          return null;
        }
        final String? encoded = await _store.read(slot.storageKey);
        if (encoded == null) {
          return null;
        }
        if (utf8.encode(encoded).length > maxEncodedBytes) {
          await _deleteUnsafe(slot);
          return null;
        }
        final Map<String, Object?>? envelope = _decodeEnvelope(encoded);
        final DateTime now = _clock().toUtc();
        if (envelope == null ||
            envelope['contractVersion'] != contractVersion ||
            envelope['userId'] != scope.userId ||
            envelope['sessionId'] != scope.sessionId ||
            envelope['householdId'] is! String ||
            expectedHouseholdId != null &&
                envelope['householdId'] != expectedHouseholdId ||
            envelope['validatedAt'] is! String ||
            envelope['expiresAt'] is! String) {
          await _deleteUnsafe(slot);
          return null;
        }
        final DateTime? validatedAt = _parseCanonicalUtc(
          envelope['validatedAt']! as String,
        );
        final DateTime? expiresAt = _parseCanonicalUtc(
          envelope['expiresAt']! as String,
        );
        if (validatedAt == null ||
            expiresAt == null ||
            validatedAt.isAfter(now.add(_clockSkew)) ||
            !expiresAt.isAfter(validatedAt) ||
            expiresAt.isAfter(validatedAt.add(maxAge)) ||
            expiresAt.isAfter(scope.expiresAt) ||
            !now.isBefore(expiresAt) ||
            !now.isBefore(scope.expiresAt)) {
          await _deleteUnsafe(slot);
          return null;
        }
        return ReadCacheRecord(
          householdId: envelope['householdId']! as String,
          payload: envelope['payload'],
          metadata: ReadCacheMetadata(
            validatedAt: validatedAt,
            expiresAt: expiresAt,
          ),
        );
      } on Object {
        return null;
      }
    });
  }

  @override
  Future<bool> write(
    ReadCacheSlot slot, {
    required String householdId,
    required Object? payload,
    DateTime? validatedAt,
  }) {
    return _serialized<bool>(() async {
      try {
        await _initialize();
        final ReadCacheSessionScope? scope = _scopeResolver.currentScope();
        final DateTime now = _clock().toUtc();
        final DateTime validated = (validatedAt ?? now).toUtc();
        if (scope == null ||
            householdId.isEmpty ||
            validated.isAfter(now.add(_clockSkew)) ||
            !now.isBefore(scope.expiresAt)) {
          await _deleteUnsafe(slot);
          return false;
        }
        final DateTime policyExpiry = validated.add(maxAge);
        final DateTime expiresAt = policyExpiry.isBefore(scope.expiresAt)
            ? policyExpiry
            : scope.expiresAt;
        if (!expiresAt.isAfter(validated)) {
          await _deleteUnsafe(slot);
          return false;
        }
        final String encoded = jsonEncode(<String, Object?>{
          'contractVersion': contractVersion,
          'userId': scope.userId,
          'sessionId': scope.sessionId,
          'householdId': householdId,
          'validatedAt': validated.toIso8601String(),
          'expiresAt': expiresAt.toIso8601String(),
          'payload': payload,
        });
        if (utf8.encode(encoded).length > maxEncodedBytes) {
          await _deleteUnsafe(slot);
          return false;
        }
        await _store.write(slot.storageKey, encoded);
        return true;
      } on Object {
        try {
          await _deleteUnsafe(slot);
        } on Object {
          // The caller receives false and the auth lifecycle can fail closed
          // when this write protects a household transition.
        }
        return false;
      }
    });
  }

  @override
  Future<bool> delete(ReadCacheSlot slot) {
    return _serialized<bool>(() async {
      try {
        await _initialize();
        await _deleteUnsafe(slot);
        return true;
      } on Object {
        return false;
      }
    });
  }

  @override
  Future<bool> clear() {
    return _serialized<bool>(() async {
      try {
        await _initialize();
        await _store.deleteAll();
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

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }
    await _store.initialize();
    _initialized = true;
  }

  Future<void> _deleteUnsafe(ReadCacheSlot slot) {
    return _store.delete(slot.storageKey);
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
