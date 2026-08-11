import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/analytics/application/analytics_dispatcher.dart';
import 'package:kinflow_app/features/analytics/application/analytics_session_entry_coordinator.dart';
import 'package:kinflow_app/features/analytics/application/ports/analytics_sink.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/failures/analytics_preference_failure.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';

void main() {
  const AnalyticsDispatchMetadata metadata = AnalyticsDispatchMetadata(
    appRelease: 'me.newlines.kinflow@0.1.0+1',
    environment: AnalyticsEnvironment.prod,
  );

  test('event allowlist and envelope are exact and content-free', () {
    expect(AnalyticsEventName.values.map((value) => value.wireValue), <String>[
      'application.session.started',
      'household.activation.progressed',
      'invite.accept.succeeded',
      'chore.complete.succeeded',
      'calendar.occurrence.opened',
      'billing.purchase.pending_server_confirmation',
    ]);

    final Map<String, Object> json = const AnalyticsEnvelope(
      event: AnalyticsEventName.choreCompleteSucceeded,
      metadata: metadata,
    ).toSafeJson();
    expect(json.keys, <String>[
      'event_name',
      'event_version',
      'platform',
      'app_release',
      'environment',
    ]);
    expect(json['event_version'], 1);
    expect(json['platform'], 'android');
    expect(
      json.keys.join('|').toLowerCase(),
      isNot(
        matches(RegExp(r'user|household|member|child|email|token|content')),
      ),
    );
  });

  test(
    'managed child blocks before preference storage or sink access',
    () async {
      final _FakePreferenceRepository repository = _FakePreferenceRepository(
        const AnalyticsPreferenceSucceeded(AnalyticsUsagePreference.granted),
      );
      final _RecordingAnalyticsSink sink = _RecordingAnalyticsSink();
      final AnalyticsDispatcher dispatcher = AnalyticsDispatcher(
        repository,
        sink,
        metadata,
      );

      expect(
        await dispatcher.track(
          AnalyticsEventName.applicationSessionStarted,
          actorMode: AnalyticsActorMode.managedChild,
        ),
        AnalyticsDispatchResult.blockedChildMode,
      );
      expect(repository.loadCalls, 0);
      expect(sink.envelopes, isEmpty);
    },
  );

  test('withdrawn and failed preferences never reach the sink', () async {
    for (final AnalyticsPreferenceResult result in <AnalyticsPreferenceResult>[
      const AnalyticsPreferenceSucceeded(AnalyticsUsagePreference.withdrawn),
      const AnalyticsPreferenceFailed(
        AnalyticsPreferenceFailure(
          AnalyticsPreferenceFailureKind.temporarilyUnavailable,
        ),
      ),
    ]) {
      final _RecordingAnalyticsSink sink = _RecordingAnalyticsSink();
      final AnalyticsDispatcher dispatcher = AnalyticsDispatcher(
        _FakePreferenceRepository(result),
        sink,
        metadata,
      );

      expect(
        await dispatcher.track(AnalyticsEventName.inviteAcceptSucceeded),
        AnalyticsDispatchResult.blockedPreference,
      );
      expect(sink.envelopes, isEmpty);
    }
  });

  test('unavailable and throwing sinks cannot fail application work', () async {
    final _FakePreferenceRepository repository = _FakePreferenceRepository(
      const AnalyticsPreferenceSucceeded(AnalyticsUsagePreference.granted),
    );
    final _RecordingAnalyticsSink unavailable = _RecordingAnalyticsSink(
      availability: AnalyticsSinkAvailability.unavailable,
    );
    final _RecordingAnalyticsSink throwing = _RecordingAnalyticsSink(
      throwOnEmit: true,
    );

    expect(
      await AnalyticsDispatcher(
        repository,
        unavailable,
        metadata,
      ).track(AnalyticsEventName.calendarOccurrenceOpened),
      AnalyticsDispatchResult.unavailable,
    );
    expect(unavailable.envelopes, isEmpty);

    expect(
      await AnalyticsDispatcher(
        repository,
        throwing,
        metadata,
      ).track(AnalyticsEventName.calendarOccurrenceOpened),
      AnalyticsDispatchResult.failed,
    );
  });

  test('granted adult event reaches an available sink once', () async {
    final _RecordingAnalyticsSink sink = _RecordingAnalyticsSink();
    final AnalyticsDispatcher dispatcher = AnalyticsDispatcher(
      _FakePreferenceRepository(
        const AnalyticsPreferenceSucceeded(AnalyticsUsagePreference.granted),
      ),
      sink,
      metadata,
    );

    expect(
      await dispatcher.track(
        AnalyticsEventName.billingPurchasePendingServerConfirmation,
      ),
      AnalyticsDispatchResult.sent,
    );
    expect(sink.envelopes, hasLength(1));
    expect(sink.envelopes.single.toSafeJson(), <String, Object>{
      'event_name': 'billing.purchase.pending_server_confirmation',
      'event_version': 1,
      'platform': 'android',
      'app_release': 'me.newlines.kinflow@0.1.0+1',
      'environment': 'prod',
    });
  });

  test('session coordinator emits once per authenticated entry', () async {
    final _RecordingAnalyticsSink sink = _RecordingAnalyticsSink();
    final AnalyticsSessionEntryCoordinator coordinator =
        AnalyticsSessionEntryCoordinator(
          AnalyticsDispatcher(
            _FakePreferenceRepository(
              const AnalyticsPreferenceSucceeded(
                AnalyticsUsagePreference.granted,
              ),
            ),
            sink,
            metadata,
          ),
        );

    expect(await coordinator.synchronize(authenticatedEntry: false), isNull);
    expect(
      await coordinator.synchronize(authenticatedEntry: true),
      AnalyticsDispatchResult.sent,
    );
    expect(await coordinator.synchronize(authenticatedEntry: true), isNull);
    expect(sink.envelopes, hasLength(1));

    await coordinator.synchronize(authenticatedEntry: false);
    expect(
      await coordinator.synchronize(authenticatedEntry: true),
      AnalyticsDispatchResult.sent,
    );
    expect(sink.envelopes, hasLength(2));
    expect(
      sink.envelopes.map((value) => value.event).toSet(),
      <AnalyticsEventName>{AnalyticsEventName.applicationSessionStarted},
    );
  });
}

final class _FakePreferenceRepository implements AnalyticsPreferenceRepository {
  _FakePreferenceRepository(this.result);

  final AnalyticsPreferenceResult result;
  int loadCalls = 0;

  @override
  Future<AnalyticsPreferenceResult> load() async {
    loadCalls += 1;
    return result;
  }

  @override
  Future<AnalyticsPreferenceResult> save(
    AnalyticsUsagePreference preference,
  ) async => AnalyticsPreferenceSucceeded(preference);
}

final class _RecordingAnalyticsSink implements AnalyticsSink {
  _RecordingAnalyticsSink({
    this.availability = AnalyticsSinkAvailability.available,
    this.throwOnEmit = false,
  });

  @override
  final AnalyticsSinkAvailability availability;
  final bool throwOnEmit;
  final List<AnalyticsEnvelope> envelopes = <AnalyticsEnvelope>[];

  @override
  Future<void> emit(AnalyticsEnvelope envelope) async {
    envelopes.add(envelope);
    if (throwOnEmit) {
      throw StateError('private-provider-failure');
    }
  }
}
