import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/analytics/data/repositories/secure_analytics_preference_repository.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

void main() {
  test('missing stale and malformed values fail closed to withdrawn', () async {
    for (final String? stored in <String?>[
      null,
      'analytics-usage-v0|granted',
      'analytics-usage-v1|GRANTED',
      'adult@example.com',
    ]) {
      final _MemorySecureStringStore store = _MemorySecureStringStore();
      if (stored != null) {
        store.values[SecureAnalyticsPreferenceRepository.storageKey] = stored;
      }
      final AnalyticsPreferenceResult result =
          await SecureAnalyticsPreferenceRepository(store).load();

      expect(result, isA<AnalyticsPreferenceSucceeded>());
      expect(
        (result as AnalyticsPreferenceSucceeded).preference,
        AnalyticsUsagePreference.withdrawn,
      );
    }
  });

  test('exact current values round-trip through one fixed key', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore();
    final SecureAnalyticsPreferenceRepository repository =
        SecureAnalyticsPreferenceRepository(store);

    expect(
      await repository.save(AnalyticsUsagePreference.granted),
      isA<AnalyticsPreferenceSucceeded>(),
    );
    expect(store.values, <String, String>{
      SecureAnalyticsPreferenceRepository.storageKey:
          SecureAnalyticsPreferenceRepository.grantedValue,
    });
    expect(
      (await repository.load() as AnalyticsPreferenceSucceeded).preference,
      AnalyticsUsagePreference.granted,
    );

    await repository.save(AnalyticsUsagePreference.withdrawn);
    expect(
      store.values[SecureAnalyticsPreferenceRepository.storageKey],
      SecureAnalyticsPreferenceRepository.withdrawnValue,
    );
    expect(store.initializeCalls, 1);
  });

  test('concurrent first reads initialize the secure namespace once', () async {
    final Completer<void> gate = Completer<void>();
    final _MemorySecureStringStore store = _MemorySecureStringStore(
      initializationGate: gate,
    );
    final SecureAnalyticsPreferenceRepository repository =
        SecureAnalyticsPreferenceRepository(store);

    final Future<AnalyticsPreferenceResult> first = repository.load();
    final Future<AnalyticsPreferenceResult> second = repository.load();
    await Future<void>.delayed(Duration.zero);
    expect(store.initializeCalls, 1);

    gate.complete();
    expect(await first, isA<AnalyticsPreferenceSucceeded>());
    expect(await second, isA<AnalyticsPreferenceSucceeded>());
    expect(store.initializeCalls, 1);
  });

  test('initialization failure can retry and remains fail closed', () async {
    final _MemorySecureStringStore store = _MemorySecureStringStore(
      initializeFailuresRemaining: 1,
    );
    final SecureAnalyticsPreferenceRepository repository =
        SecureAnalyticsPreferenceRepository(store);

    expect(await repository.load(), isA<AnalyticsPreferenceFailed>());
    expect(
      (await repository.load() as AnalyticsPreferenceSucceeded).preference,
      AnalyticsUsagePreference.withdrawn,
    );
    expect(store.initializeCalls, 2);
  });

  test('read and write exceptions return stable failure results', () async {
    final _MemorySecureStringStore readFailure = _MemorySecureStringStore(
      throwOnRead: true,
    );
    final _MemorySecureStringStore writeFailure = _MemorySecureStringStore(
      throwOnWrite: true,
    );

    expect(
      await SecureAnalyticsPreferenceRepository(readFailure).load(),
      isA<AnalyticsPreferenceFailed>(),
    );
    expect(
      await SecureAnalyticsPreferenceRepository(
        writeFailure,
      ).save(AnalyticsUsagePreference.granted),
      isA<AnalyticsPreferenceFailed>(),
    );
    expect(writeFailure.values, isEmpty);
  });
}

final class _MemorySecureStringStore implements SecureStringStore {
  _MemorySecureStringStore({
    this.initializationGate,
    this.initializeFailuresRemaining = 0,
    this.throwOnRead = false,
    this.throwOnWrite = false,
  });

  final Completer<void>? initializationGate;
  int initializeFailuresRemaining;
  final bool throwOnRead;
  final bool throwOnWrite;
  final Map<String, String> values = <String, String>{};
  int initializeCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    if (initializeFailuresRemaining > 0) {
      initializeFailuresRemaining -= 1;
      throw StateError('private-initialize-failure');
    }
    await initializationGate?.future;
  }

  @override
  Future<bool> containsKey(String key) async => values.containsKey(key);

  @override
  Future<String?> read(String key) async {
    if (throwOnRead) throw StateError('private-read-failure');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (throwOnWrite) throw StateError('private-write-failure');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}
