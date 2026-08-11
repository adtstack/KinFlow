import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/offline/application/active_household_snapshot_writer.dart';
import 'package:kinflow_app/features/offline/application/active_household_transition_local_state.dart';

import '../../support/fakes/fake_household_selection_dependencies.dart';

void main() {
  test(
    'purges household-bound participants before writing new snapshot',
    () async {
      final List<String> order = <String>[];
      final CompositeActiveHouseholdTransitionLocalState transition =
          CompositeActiveHouseholdTransitionLocalState(
            snapshotWriter: _RecordingSnapshotWriter(order),
            participants: <SensitiveLocalStatePurgeParticipant>[
              _RecordingPurgeParticipant(order, 'read-cache'),
              _RecordingPurgeParticipant(order, 'guided-resume'),
              _RecordingPurgeParticipant(order, 'pending-invite'),
            ],
          );

      final bool result = await transition.replaceAfterSwitch(
        switchedActiveHouseholdFixture(),
      );

      expect(result, isTrue);
      expect(order, <String>[
        'read-cache',
        'guided-resume',
        'pending-invite',
        'snapshot:$householdSelectionBId',
      ]);
    },
  );

  test(
    'purge failure prevents the new active snapshot from being exposed',
    () async {
      final List<String> order = <String>[];
      final CompositeActiveHouseholdTransitionLocalState transition =
          CompositeActiveHouseholdTransitionLocalState(
            snapshotWriter: _RecordingSnapshotWriter(order),
            participants: <SensitiveLocalStatePurgeParticipant>[
              _RecordingPurgeParticipant(order, 'read-cache'),
              _RecordingPurgeParticipant(order, 'guided-resume', fail: true),
              _RecordingPurgeParticipant(order, 'pending-invite'),
            ],
          );

      final bool result = await transition.replaceAfterSwitch(
        switchedActiveHouseholdFixture(),
      );

      expect(result, isFalse);
      expect(order, <String>['read-cache', 'guided-resume']);
    },
  );

  test(
    'departure purges household state before clearing the snapshot',
    () async {
      final List<String> order = <String>[];
      final CompositeActiveHouseholdTransitionLocalState transition =
          CompositeActiveHouseholdTransitionLocalState(
            snapshotWriter: _RecordingSnapshotWriter(order),
            participants: <SensitiveLocalStatePurgeParticipant>[
              _RecordingPurgeParticipant(order, 'read-cache'),
              _RecordingPurgeParticipant(order, 'guided-resume'),
              _RecordingPurgeParticipant(order, 'pending-invite'),
            ],
          );

      final bool result = await transition.clearAfterDeparture();

      expect(result, isTrue);
      expect(order, <String>[
        'read-cache',
        'guided-resume',
        'pending-invite',
        'snapshot:clear',
      ]);
    },
  );

  test('departure purge failure prevents snapshot clearing', () async {
    final List<String> order = <String>[];
    final CompositeActiveHouseholdTransitionLocalState transition =
        CompositeActiveHouseholdTransitionLocalState(
          snapshotWriter: _RecordingSnapshotWriter(order),
          participants: <SensitiveLocalStatePurgeParticipant>[
            _RecordingPurgeParticipant(order, 'read-cache', fail: true),
          ],
        );

    expect(await transition.clearAfterDeparture(), isFalse);
    expect(order, <String>['read-cache']);
  });
}

final class _RecordingPurgeParticipant
    implements SensitiveLocalStatePurgeParticipant {
  const _RecordingPurgeParticipant(this.order, this.name, {this.fail = false});

  final List<String> order;
  final String name;
  final bool fail;

  @override
  Future<void> purgeSensitiveLocalState() async {
    order.add(name);
    if (fail) {
      throw StateError('private test failure');
    }
  }
}

final class _RecordingSnapshotWriter implements ActiveHouseholdSnapshotWriter {
  const _RecordingSnapshotWriter(this.order);

  final List<String> order;

  @override
  Future<bool> replace(ActiveHousehold household) async {
    order.add('snapshot:${household.householdId.value}');
    return true;
  }

  @override
  Future<bool> clear() async {
    order.add('snapshot:clear');
    return true;
  }
}
