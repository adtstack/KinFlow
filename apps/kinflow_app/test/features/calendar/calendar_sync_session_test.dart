import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/application/calendar_sync_session.dart';
import 'package:kinflow_app/features/calendar/domain/entities/calendar_sync_signal.dart';
import 'package:kinflow_app/features/calendar/domain/repositories/calendar_sync_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

import '../../support/fakes/fake_calendar_dependencies.dart';

void main() {
  test(
    'coalesces duplicate, out-of-order, and in-flight invalidations',
    () async {
      final _FakeCalendarSyncRepository repository =
          _FakeCalendarSyncRepository();
      final List<Completer<void>> refreshes = <Completer<void>>[];
      final List<CalendarSyncConnectionStatus> statuses =
          <CalendarSyncConnectionStatus>[];
      final CalendarSyncSession session = CalendarSyncSession(repository, () {
        final Completer<void> completer = Completer<void>();
        refreshes.add(completer);
        return completer.future;
      }, statuses.add);
      addTearDown(() async {
        for (final Completer<void> refresh in refreshes) {
          if (!refresh.isCompleted) {
            refresh.complete();
          }
        }
        await session.dispose();
        await repository.dispose();
      });

      await session.start(calendarHouseholdId());
      repository.latest.add(const CalendarSyncConnected());
      await _flush();
      expect(refreshes, hasLength(1));
      expect(statuses.last, CalendarSyncConnectionStatus.live);

      repository.latest
        ..add(const CalendarSyncChanged(8))
        ..add(const CalendarSyncChanged(8))
        ..add(const CalendarSyncChanged(7));
      await _flush();
      expect(refreshes, hasLength(1));

      refreshes.first.complete();
      await _flush();
      expect(refreshes, hasLength(2));
      refreshes.last.complete();
      await _flush();
      expect(refreshes, hasLength(2));
    },
  );

  test('retains disconnected status and full-refetches on reconnect', () async {
    final _FakeCalendarSyncRepository repository =
        _FakeCalendarSyncRepository();
    final List<CalendarSyncConnectionStatus> statuses =
        <CalendarSyncConnectionStatus>[];
    var refreshCount = 0;
    final CalendarSyncSession session = CalendarSyncSession(
      repository,
      () async => refreshCount += 1,
      statuses.add,
    );
    addTearDown(() async {
      await session.dispose();
      await repository.dispose();
    });

    await session.start(calendarHouseholdId());
    repository.latest.add(const CalendarSyncConnected());
    await _flush();
    expect(refreshCount, 1);

    repository.latest.add(const CalendarSyncDisconnected());
    expect(statuses.last, CalendarSyncConnectionStatus.disconnected);

    await session.reconnect();
    expect(repository.watchCount, 2);
    expect(statuses.last, CalendarSyncConnectionStatus.connecting);
    expect(refreshCount, 2);

    repository.latest.add(const CalendarSyncConnected());
    await _flush();
    expect(statuses.last, CalendarSyncConnectionStatus.live);
    expect(refreshCount, 3);
  });

  test('disabled session still performs a resume refetch', () async {
    var refreshCount = 0;
    final CalendarSyncSession session = CalendarSyncSession(
      null,
      () async => refreshCount += 1,
      (_) {},
    );
    addTearDown(session.dispose);

    await session.start(calendarHouseholdId());
    await session.resume();

    expect(refreshCount, 1);
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _FakeCalendarSyncRepository implements CalendarSyncRepository {
  final List<StreamController<CalendarSyncSignal>> _controllers =
      <StreamController<CalendarSyncSignal>>[];

  int get watchCount => _controllers.length;

  StreamController<CalendarSyncSignal> get latest => _controllers.last;

  @override
  Stream<CalendarSyncSignal> watch(HouseholdId householdId) {
    final StreamController<CalendarSyncSignal> controller =
        StreamController<CalendarSyncSignal>.broadcast(sync: true);
    _controllers.add(controller);
    return controller.stream;
  }

  Future<void> dispose() async {
    for (final StreamController<CalendarSyncSignal> controller
        in _controllers) {
      await controller.close();
    }
  }
}
