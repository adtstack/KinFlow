import 'dart:async';

import 'package:kinflow_app/features/calendar/data/datasources/calendar_sync_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _calendarSyncKeys = <String>{
  'household_id',
  'generation',
  'changed_at',
};

final class SupabaseCalendarSyncDataSource implements CalendarSyncDataSource {
  SupabaseCalendarSyncDataSource(this._client);

  final SupabaseClient _client;
  var _channelSequence = 0;

  @override
  Stream<CalendarSyncDataSignal> watchHousehold(String householdId) {
    late final StreamController<CalendarSyncDataSignal> controller;
    RealtimeChannel? channel;
    var cancelled = false;

    controller = StreamController<CalendarSyncDataSignal>(
      sync: true,
      onListen: () {
        if (cancelled) {
          return;
        }
        controller.add(
          const CalendarSyncDataSignal(CalendarSyncDataSignalKind.connecting),
        );
        try {
          channel = _client
              .channel('kinflow-calendar-sync-${_channelSequence++}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'calendar_sync_watermarks',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'household_id',
                  value: householdId,
                ),
                select: _calendarSyncKeys.toList(growable: false),
                callback: (PostgresChangePayload payload) {
                  if (cancelled) {
                    return;
                  }
                  final CalendarSyncDataSignal? signal =
                      calendarSyncSignalFromPayload(
                        payload.newRecord,
                        expectedHouseholdId: householdId,
                      );
                  controller.add(
                    signal ??
                        const CalendarSyncDataSignal(
                          CalendarSyncDataSignalKind.disconnected,
                        ),
                  );
                },
              )
              .subscribe((RealtimeSubscribeStatus status, Object? _) {
                if (cancelled) {
                  return;
                }
                controller.add(
                  CalendarSyncDataSignal(switch (status) {
                    RealtimeSubscribeStatus.subscribed =>
                      CalendarSyncDataSignalKind.connected,
                    RealtimeSubscribeStatus.channelError ||
                    RealtimeSubscribeStatus.closed ||
                    RealtimeSubscribeStatus.timedOut =>
                      CalendarSyncDataSignalKind.disconnected,
                  }),
                );
              });
        } on Object {
          controller.add(
            const CalendarSyncDataSignal(
              CalendarSyncDataSignalKind.disconnected,
            ),
          );
        }
      },
      onCancel: () async {
        cancelled = true;
        final RealtimeChannel? activeChannel = channel;
        if (activeChannel != null) {
          try {
            await _client.removeChannel(activeChannel);
          } on Object {
            // Disposal is best-effort and must not surface transport details.
          }
        }
        await controller.close();
      },
    );
    return controller.stream;
  }
}

CalendarSyncDataSignal? calendarSyncSignalFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
}) {
  if (payload is! Map ||
      payload.keys.any((Object? key) => key is! String) ||
      payload.keys
          .cast<String>()
          .toSet()
          .difference(_calendarSyncKeys)
          .isNotEmpty ||
      _calendarSyncKeys
          .difference(payload.keys.cast<String>().toSet())
          .isNotEmpty) {
    return null;
  }
  final Object? householdId = payload['household_id'];
  final Object? generation = payload['generation'];
  final Object? changedAt = payload['changed_at'];
  if (householdId is! String ||
      householdId.toLowerCase() != expectedHouseholdId.toLowerCase() ||
      generation is! int ||
      generation < 1 ||
      changedAt is! String) {
    return null;
  }
  final DateTime? parsedChangedAt = DateTime.tryParse(changedAt);
  if (parsedChangedAt == null || !parsedChangedAt.isUtc) {
    return null;
  }
  return CalendarSyncDataSignal(
    CalendarSyncDataSignalKind.changed,
    generation: generation,
  );
}
