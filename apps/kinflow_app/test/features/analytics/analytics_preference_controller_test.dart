import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/analytics/application/analytics_preference_controller.dart';
import 'package:kinflow_app/features/analytics/application/analytics_preference_state.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/failures/analytics_preference_failure.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';

void main() {
  test('loads default-off preference and saves a new choice', () async {
    final _FakeAnalyticsPreferenceRepository repository =
        _FakeAnalyticsPreferenceRepository(
          loadResult: const AnalyticsPreferenceSucceeded(
            AnalyticsUsagePreference.withdrawn,
          ),
          saveResult: const AnalyticsPreferenceSucceeded(
            AnalyticsUsagePreference.granted,
          ),
        );
    final AnalyticsPreferenceController controller =
        AnalyticsPreferenceController(repository);
    addTearDown(controller.dispose);

    await controller.load();
    expect(controller.state, isA<AnalyticsPreferenceReady>());
    expect(
      (controller.state as AnalyticsPreferenceReady).preference,
      AnalyticsUsagePreference.withdrawn,
    );

    await controller.save(AnalyticsUsagePreference.granted);
    final AnalyticsPreferenceReady ready =
        controller.state as AnalyticsPreferenceReady;
    expect(ready.preference, AnalyticsUsagePreference.granted);
    expect(ready.saveCount, 1);
  });

  test('save is single-flight and duplicate taps do not write twice', () async {
    final Completer<AnalyticsPreferenceResult> saveGate =
        Completer<AnalyticsPreferenceResult>();
    final _FakeAnalyticsPreferenceRepository repository =
        _FakeAnalyticsPreferenceRepository(
          loadResult: const AnalyticsPreferenceSucceeded(
            AnalyticsUsagePreference.withdrawn,
          ),
          saveFuture: saveGate.future,
        );
    final AnalyticsPreferenceController controller =
        AnalyticsPreferenceController(repository);
    addTearDown(controller.dispose);
    await controller.load();

    final Future<void> first = controller.save(
      AnalyticsUsagePreference.granted,
    );
    final Future<void> second = controller.save(
      AnalyticsUsagePreference.granted,
    );
    expect(repository.saveCalls, 1);
    expect((controller.state as AnalyticsPreferenceReady).isSaving, isTrue);

    saveGate.complete(
      const AnalyticsPreferenceSucceeded(AnalyticsUsagePreference.granted),
    );
    await Future.wait(<Future<void>>[first, second]);
    expect(repository.saveCalls, 1);
    expect(
      (controller.state as AnalyticsPreferenceReady).preference,
      AnalyticsUsagePreference.granted,
    );
  });

  test('failed save preserves previous choice with stable failure', () async {
    final _FakeAnalyticsPreferenceRepository repository =
        _FakeAnalyticsPreferenceRepository(
          loadResult: const AnalyticsPreferenceSucceeded(
            AnalyticsUsagePreference.withdrawn,
          ),
          saveResult: const AnalyticsPreferenceFailed(
            AnalyticsPreferenceFailure(
              AnalyticsPreferenceFailureKind.temporarilyUnavailable,
            ),
          ),
        );
    final AnalyticsPreferenceController controller =
        AnalyticsPreferenceController(repository);
    addTearDown(controller.dispose);
    await controller.load();

    await controller.save(AnalyticsUsagePreference.granted);
    final AnalyticsPreferenceReady ready =
        controller.state as AnalyticsPreferenceReady;
    expect(ready.preference, AnalyticsUsagePreference.withdrawn);
    expect(ready.failure?.stableCode, 'ANALYTICS_PREFERENCE_UNAVAILABLE');
  });

  test('raw repository exception becomes an internal load failure', () async {
    final AnalyticsPreferenceController controller =
        AnalyticsPreferenceController(
          _FakeAnalyticsPreferenceRepository(throwOnLoad: true),
        );
    addTearDown(controller.dispose);

    await controller.load();
    final AnalyticsPreferenceLoadFailed failed =
        controller.state as AnalyticsPreferenceLoadFailed;
    expect(failed.failure.stableCode, 'ANALYTICS_PREFERENCE_INTERNAL');
    expect(failed.failure.stableCode, isNot(contains('private')));
  });
}

final class _FakeAnalyticsPreferenceRepository
    implements AnalyticsPreferenceRepository {
  _FakeAnalyticsPreferenceRepository({
    this.loadResult = const AnalyticsPreferenceSucceeded(
      AnalyticsUsagePreference.withdrawn,
    ),
    this.saveResult,
    this.saveFuture,
    this.throwOnLoad = false,
  });

  final AnalyticsPreferenceResult loadResult;
  final AnalyticsPreferenceResult? saveResult;
  final Future<AnalyticsPreferenceResult>? saveFuture;
  final bool throwOnLoad;
  int saveCalls = 0;

  @override
  Future<AnalyticsPreferenceResult> load() async {
    if (throwOnLoad) throw StateError('private-load-failure');
    return loadResult;
  }

  @override
  Future<AnalyticsPreferenceResult> save(AnalyticsUsagePreference preference) {
    saveCalls += 1;
    return saveFuture ??
        Future<AnalyticsPreferenceResult>.value(
          saveResult ?? AnalyticsPreferenceSucceeded(preference),
        );
  }
}
