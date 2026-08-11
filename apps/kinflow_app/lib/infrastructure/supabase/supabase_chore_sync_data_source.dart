import 'dart:async';

import 'package:kinflow_app/features/chores/data/datasources/chore_sync_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Set<String> _choreSyncKeys = <String>{
  'household_id',
  'generation',
  'changed_at',
};

final class SupabaseChoreSyncDataSource implements ChoreSyncDataSource {
  SupabaseChoreSyncDataSource(this._client);

  final SupabaseClient _client;
  var _channelSequence = 0;

  @override
  Stream<ChoreSyncDataSignal> watchHousehold(String householdId) {
    late final StreamController<ChoreSyncDataSignal> controller;
    RealtimeChannel? channel;
    var cancelled = false;

    controller = StreamController<ChoreSyncDataSignal>(
      sync: true,
      onListen: () {
        if (cancelled) {
          return;
        }
        controller.add(
          const ChoreSyncDataSignal(ChoreSyncDataSignalKind.connecting),
        );
        try {
          channel = _client
              .channel('kinflow-chore-sync-${_channelSequence++}')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'chore_sync_watermarks',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'household_id',
                  value: householdId,
                ),
                select: _choreSyncKeys.toList(growable: false),
                callback: (PostgresChangePayload payload) {
                  if (cancelled) {
                    return;
                  }
                  final ChoreSyncDataSignal? signal =
                      choreSyncSignalFromPayload(
                        payload.newRecord,
                        expectedHouseholdId: householdId,
                      );
                  controller.add(
                    signal ??
                        const ChoreSyncDataSignal(
                          ChoreSyncDataSignalKind.disconnected,
                        ),
                  );
                },
              )
              .subscribe((RealtimeSubscribeStatus status, Object? _) {
                if (cancelled) {
                  return;
                }
                controller.add(
                  ChoreSyncDataSignal(switch (status) {
                    RealtimeSubscribeStatus.subscribed =>
                      ChoreSyncDataSignalKind.connected,
                    RealtimeSubscribeStatus.channelError ||
                    RealtimeSubscribeStatus.closed ||
                    RealtimeSubscribeStatus.timedOut =>
                      ChoreSyncDataSignalKind.disconnected,
                  }),
                );
              });
        } on Object {
          controller.add(
            const ChoreSyncDataSignal(ChoreSyncDataSignalKind.disconnected),
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

ChoreSyncDataSignal? choreSyncSignalFromPayload(
  Object? payload, {
  required String expectedHouseholdId,
}) {
  if (payload is! Map ||
      payload.keys.any((Object? key) => key is! String) ||
      payload.keys
          .cast<String>()
          .toSet()
          .difference(_choreSyncKeys)
          .isNotEmpty ||
      _choreSyncKeys
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
  return ChoreSyncDataSignal(
    ChoreSyncDataSignalKind.changed,
    generation: generation,
  );
}
