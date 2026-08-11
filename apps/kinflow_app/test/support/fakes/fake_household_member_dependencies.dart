import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/features/household/application/ports/active_household_departure_committer.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member_command.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_member_repository.dart';
import 'package:kinflow_app/features/household/domain/services/household_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

final class FakeHouseholdMemberRepository implements HouseholdMemberRepository {
  FakeHouseholdMemberRepository({
    HouseholdMemberRoster? roster,
    List<LoadHouseholdMemberRosterResult> loadResults =
        const <LoadHouseholdMemberRosterResult>[],
    List<HouseholdMemberCommandResult> changeRoleResults =
        const <HouseholdMemberCommandResult>[],
    List<HouseholdMemberCommandResult> removeResults =
        const <HouseholdMemberCommandResult>[],
    List<HouseholdMemberCommandResult> leaveResults =
        const <HouseholdMemberCommandResult>[],
    List<HouseholdMemberCommandResult> transferResults =
        const <HouseholdMemberCommandResult>[],
    this.changeRoleCallback,
    this.removeCallback,
    this.leaveCallback,
    this.transferCallback,
  }) : defaultRoster = roster ?? householdMemberRosterFixture(),
       _loadResults = List<LoadHouseholdMemberRosterResult>.of(loadResults),
       _changeRoleResults = List<HouseholdMemberCommandResult>.of(
         changeRoleResults,
       ),
       _removeResults = List<HouseholdMemberCommandResult>.of(removeResults),
       _leaveResults = List<HouseholdMemberCommandResult>.of(leaveResults),
       _transferResults = List<HouseholdMemberCommandResult>.of(
         transferResults,
       );

  final HouseholdMemberRoster defaultRoster;
  final List<LoadHouseholdMemberRosterResult> _loadResults;
  final List<HouseholdMemberCommandResult> _changeRoleResults;
  final List<HouseholdMemberCommandResult> _removeResults;
  final List<HouseholdMemberCommandResult> _leaveResults;
  final List<HouseholdMemberCommandResult> _transferResults;
  final Future<HouseholdMemberCommandResult> Function(
    ChangeHouseholdMemberRoleCommand command,
  )?
  changeRoleCallback;
  final Future<HouseholdMemberCommandResult> Function(
    RemoveHouseholdMemberCommand command,
  )?
  removeCallback;
  final Future<HouseholdMemberCommandResult> Function(
    LeaveHouseholdCommand command,
  )?
  leaveCallback;
  final Future<HouseholdMemberCommandResult> Function(
    TransferHouseholdOwnerCommand command,
  )?
  transferCallback;

  final List<HouseholdId> loadedHouseholds = <HouseholdId>[];
  final List<ChangeHouseholdMemberRoleCommand> changeRoleCommands =
      <ChangeHouseholdMemberRoleCommand>[];
  final List<RemoveHouseholdMemberCommand> removeCommands =
      <RemoveHouseholdMemberCommand>[];
  final List<LeaveHouseholdCommand> leaveCommands = <LeaveHouseholdCommand>[];
  final List<TransferHouseholdOwnerCommand> transferCommands =
      <TransferHouseholdOwnerCommand>[];

  @override
  Future<LoadHouseholdMemberRosterResult> loadRoster(
    HouseholdId householdId,
  ) async {
    loadedHouseholds.add(householdId);
    if (_loadResults.isNotEmpty) {
      return _loadResults.removeAt(0);
    }
    return HouseholdMemberRosterLoaded(defaultRoster);
  }

  @override
  Future<HouseholdMemberCommandResult> changeRole(
    ChangeHouseholdMemberRoleCommand command,
  ) async {
    changeRoleCommands.add(command);
    final callback = changeRoleCallback;
    if (callback != null) {
      return callback(command);
    }
    return _next(_changeRoleResults);
  }

  @override
  Future<HouseholdMemberCommandResult> removeMember(
    RemoveHouseholdMemberCommand command,
  ) async {
    removeCommands.add(command);
    final callback = removeCallback;
    if (callback != null) {
      return callback(command);
    }
    return _next(_removeResults);
  }

  @override
  Future<HouseholdMemberCommandResult> leaveHousehold(
    LeaveHouseholdCommand command,
  ) async {
    leaveCommands.add(command);
    final callback = leaveCallback;
    if (callback != null) {
      return callback(command);
    }
    return _leaveResults.isEmpty
        ? const HouseholdLeaveCompleted(null)
        : _leaveResults.removeAt(0);
  }

  @override
  Future<HouseholdMemberCommandResult> transferOwner(
    TransferHouseholdOwnerCommand command,
  ) async {
    transferCommands.add(command);
    final callback = transferCallback;
    if (callback != null) {
      return callback(command);
    }
    return _next(_transferResults);
  }

  HouseholdMemberCommandResult _next(
    List<HouseholdMemberCommandResult> results,
  ) {
    return results.isEmpty
        ? const HouseholdMemberCommandCompleted()
        : results.removeAt(0);
  }
}

final class FakeActiveHouseholdDepartureCommitter
    implements ActiveHouseholdDepartureCommitter {
  FakeActiveHouseholdDepartureCommitter({this.result = true, this.callback});

  final bool result;
  final Future<bool> Function(ActiveHousehold? nextHousehold)? callback;
  final List<ActiveHousehold?> nextHouseholds = <ActiveHousehold?>[];

  @override
  Future<bool> commitHouseholdDeparture(ActiveHousehold? nextHousehold) async {
    nextHouseholds.add(nextHousehold);
    final callback = this.callback;
    return callback == null ? result : callback(nextHousehold);
  }
}

final class FakeHouseholdCommandIdGenerator
    implements HouseholdCommandIdGenerator {
  FakeHouseholdCommandIdGenerator({
    List<String> values = const <String>[
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    ],
  }) : _values = values.map(_commandId).toList(growable: false);

  final List<HouseholdCommandId> _values;
  var generateCount = 0;

  @override
  HouseholdCommandId generate() {
    final int index = generateCount;
    generateCount += 1;
    if (index >= _values.length) {
      throw StateError('No fake household command ID remains.');
    }
    return _values[index];
  }
}

final class FakeRecentAuthenticationService
    implements RecentAuthenticationService {
  FakeRecentAuthenticationService({
    this.isAvailable = true,
    List<RecentAuthenticationResult> results =
        const <RecentAuthenticationResult>[],
  }) : _results = List<RecentAuthenticationResult>.of(results);

  @override
  final bool isAvailable;

  final List<RecentAuthenticationResult> _results;
  var authenticateCount = 0;

  @override
  Future<RecentAuthenticationResult> authenticate() async {
    authenticateCount += 1;
    if (_results.isNotEmpty) {
      return _results.removeAt(0);
    }
    return RecentAuthenticationCompleted(recentAuthenticationProofFixture());
  }
}

HouseholdMemberRoster householdMemberRosterFixture({
  HouseholdMemberRole currentRole = HouseholdMemberRole.owner,
  HouseholdMemberRole otherRole = HouseholdMemberRole.member,
  int householdVersion = 1,
}) {
  return HouseholdMemberRoster(
    householdId: householdIdFixture(),
    householdName: 'Kim Home',
    householdVersion: householdVersion,
    members: <HouseholdMember>[
      HouseholdMember(
        id: householdMemberIdFixture(),
        displayName: 'Alex',
        role: currentRole,
        version: 1,
        isCurrentUser: true,
      ),
      HouseholdMember(
        id: householdMemberIdFixture('33333333-3333-4333-8333-333333333334'),
        displayName: 'Sam',
        role: otherRole,
        version: 4,
        isCurrentUser: false,
      ),
    ],
  );
}

HouseholdId householdIdFixture([
  String value = '22222222-2222-4222-8222-222222222222',
]) {
  final HouseholdId? id = HouseholdId.tryParse(value);
  if (id == null) {
    throw StateError('Static household ID fixture must be a UUID.');
  }
  return id;
}

HouseholdMemberId householdMemberIdFixture([
  String value = '33333333-3333-4333-8333-333333333333',
]) {
  final HouseholdMemberId? id = HouseholdMemberId.tryParse(value);
  if (id == null) {
    throw StateError('Static household member ID fixture must be a UUID.');
  }
  return id;
}

RecentAuthenticationProof recentAuthenticationProofFixture([
  String value = 'fresh-supabase-access-token',
]) {
  final RecentAuthenticationProof? proof = RecentAuthenticationProof.tryParse(
    value,
  );
  if (proof == null) {
    throw StateError('Static recent authentication proof must be valid.');
  }
  return proof;
}

HouseholdCommandId _commandId(String value) {
  final HouseholdCommandId? id = HouseholdCommandId.tryParse(value);
  if (id == null) {
    throw StateError('Static command ID fixture must be a UUID.');
  }
  return id;
}
