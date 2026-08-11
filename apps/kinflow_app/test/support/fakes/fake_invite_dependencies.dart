import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite_request.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/services/invite_command_id_generator.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

import 'fake_household_dependencies.dart';

final class FakeInviteRepository implements InviteRepository {
  FakeInviteRepository({
    this.createCallback,
    this.previewCallback,
    this.previewShortCodeCallback,
    this.acceptCallback,
    this.acceptShortCodeCallback,
    this.revokeCallback,
    List<CreateHouseholdInviteResult> createResults =
        const <CreateHouseholdInviteResult>[],
    List<PreviewHouseholdInviteResult> previewResults =
        const <PreviewHouseholdInviteResult>[],
    List<AcceptHouseholdInviteResult> acceptResults =
        const <AcceptHouseholdInviteResult>[],
    List<RevokeHouseholdInviteResult> revokeResults =
        const <RevokeHouseholdInviteResult>[],
  }) : _createResults = List<CreateHouseholdInviteResult>.of(createResults),
       _previewResults = List<PreviewHouseholdInviteResult>.of(previewResults),
       _acceptResults = List<AcceptHouseholdInviteResult>.of(acceptResults),
       _revokeResults = List<RevokeHouseholdInviteResult>.of(revokeResults);

  final Future<CreateHouseholdInviteResult> Function(
    CreateHouseholdInviteRequest request,
  )?
  createCallback;
  final Future<PreviewHouseholdInviteResult> Function(InviteToken token)?
  previewCallback;
  final Future<PreviewHouseholdInviteResult> Function(
    InviteShortCode shortCode,
  )?
  previewShortCodeCallback;
  final Future<AcceptHouseholdInviteResult> Function(
    AcceptHouseholdInviteRequest request,
  )?
  acceptCallback;
  final Future<AcceptHouseholdInviteResult> Function(
    AcceptHouseholdInviteByShortCodeRequest request,
  )?
  acceptShortCodeCallback;
  final Future<RevokeHouseholdInviteResult> Function(
    RevokeHouseholdInviteRequest request,
  )?
  revokeCallback;
  final List<CreateHouseholdInviteResult> _createResults;
  final List<PreviewHouseholdInviteResult> _previewResults;
  final List<AcceptHouseholdInviteResult> _acceptResults;
  final List<RevokeHouseholdInviteResult> _revokeResults;

  final List<CreateHouseholdInviteRequest> createRequests =
      <CreateHouseholdInviteRequest>[];
  final List<InviteToken> previewTokens = <InviteToken>[];
  final List<InviteShortCode> previewShortCodes = <InviteShortCode>[];
  final List<AcceptHouseholdInviteRequest> acceptRequests =
      <AcceptHouseholdInviteRequest>[];
  final List<AcceptHouseholdInviteByShortCodeRequest> acceptShortCodeRequests =
      <AcceptHouseholdInviteByShortCodeRequest>[];
  final List<RevokeHouseholdInviteRequest> revokeRequests =
      <RevokeHouseholdInviteRequest>[];

  @override
  Future<CreateHouseholdInviteResult> createInvite(
    CreateHouseholdInviteRequest request,
  ) async {
    createRequests.add(request);
    final callback = createCallback;
    if (callback != null) {
      return callback(request);
    }
    if (_createResults.isNotEmpty) {
      return _createResults.removeAt(0);
    }
    return HouseholdInviteCreated(householdInviteFixture());
  }

  @override
  Future<PreviewHouseholdInviteResult> previewInvite(InviteToken token) async {
    previewTokens.add(token);
    final callback = previewCallback;
    if (callback != null) {
      return callback(token);
    }
    if (_previewResults.isNotEmpty) {
      return _previewResults.removeAt(0);
    }
    return HouseholdInvitePreviewed(householdInvitePreviewFixture());
  }

  @override
  Future<PreviewHouseholdInviteResult> previewInviteByShortCode(
    InviteShortCode shortCode,
  ) async {
    previewShortCodes.add(shortCode);
    final callback = previewShortCodeCallback;
    if (callback != null) {
      return callback(shortCode);
    }
    if (_previewResults.isNotEmpty) {
      return _previewResults.removeAt(0);
    }
    return HouseholdInvitePreviewed(householdInvitePreviewFixture());
  }

  @override
  Future<AcceptHouseholdInviteResult> acceptInvite(
    AcceptHouseholdInviteRequest request,
  ) async {
    acceptRequests.add(request);
    final callback = acceptCallback;
    if (callback != null) {
      return callback(request);
    }
    if (_acceptResults.isNotEmpty) {
      return _acceptResults.removeAt(0);
    }
    return HouseholdInviteAccepted(acceptedHouseholdInviteFixture());
  }

  @override
  Future<AcceptHouseholdInviteResult> acceptInviteByShortCode(
    AcceptHouseholdInviteByShortCodeRequest request,
  ) async {
    acceptShortCodeRequests.add(request);
    final callback = acceptShortCodeCallback;
    if (callback != null) {
      return callback(request);
    }
    if (_acceptResults.isNotEmpty) {
      return _acceptResults.removeAt(0);
    }
    return HouseholdInviteAccepted(acceptedHouseholdInviteFixture());
  }

  @override
  Future<RevokeHouseholdInviteResult> revokeInvite(
    RevokeHouseholdInviteRequest request,
  ) async {
    revokeRequests.add(request);
    final callback = revokeCallback;
    if (callback != null) {
      return callback(request);
    }
    if (_revokeResults.isNotEmpty) {
      return _revokeResults.removeAt(0);
    }
    return HouseholdInviteRevoked(request.inviteId);
  }
}

final class FakeInviteCommandIdGenerator implements InviteCommandIdGenerator {
  FakeInviteCommandIdGenerator({
    List<String> values = const <String>[
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    ],
  }) : _values = values.map(inviteCommandIdFixture).toList(growable: false);

  final List<InviteCommandId> _values;
  var generateCount = 0;

  @override
  InviteCommandId generate() {
    final int index = generateCount;
    generateCount += 1;
    if (index >= _values.length) {
      throw StateError('No fake invite command ID remains.');
    }
    return _values[index];
  }
}

HouseholdInvite householdInviteFixture({
  String rawToken = inviteTokenValue,
  String? rawShortCode,
  HouseholdInviteStatus status = HouseholdInviteStatus.active,
}) {
  return HouseholdInvite(
    id: inviteIdFixture(),
    householdId: householdIdFixture(),
    role: HouseholdInviteRole.member,
    expiresAt: DateTime.utc(2030, 1, 8),
    status: status,
    rawToken: InviteToken.tryParse(rawToken),
    rawShortCode: rawShortCode == null
        ? null
        : InviteShortCode.tryParse(rawShortCode),
    shortCodeExpiresAt: rawShortCode == null ? null : DateTime.utc(2030, 1, 2),
  );
}

HouseholdInvitePreview householdInvitePreviewFixture() {
  return HouseholdInvitePreview(
    householdDisplayName: 'Kim Home',
    inviterDisplayName: 'Alex',
    role: HouseholdInviteRole.member,
    expiresAt: DateTime.utc(2030, 1, 8),
  );
}

AcceptedHouseholdInvite acceptedHouseholdInviteFixture({
  bool activeHouseholdSet = true,
}) {
  return AcceptedHouseholdInvite(
    household: activeHouseholdFixture(
      householdId: '55555555-5555-4555-8555-555555555555',
      memberId: '66666666-6666-4666-8666-666666666666',
    ),
    displayName: 'Taylor',
    role: HouseholdInviteRole.member,
    activeHouseholdSet: activeHouseholdSet,
  );
}

InviteId inviteIdFixture() {
  final InviteId? id = InviteId.tryParse(
    '44444444-4444-4444-8444-444444444444',
  );
  if (id == null) {
    throw StateError('Static invite fixture must be a UUID.');
  }
  return id;
}

HouseholdId householdIdFixture() {
  final HouseholdId? id = HouseholdId.tryParse(
    '22222222-2222-4222-8222-222222222222',
  );
  if (id == null) {
    throw StateError('Static household fixture must be a UUID.');
  }
  return id;
}

InviteCommandId inviteCommandIdFixture(String value) {
  final InviteCommandId? id = InviteCommandId.tryParse(value);
  if (id == null) {
    throw StateError('Static invite command fixture must be a UUID.');
  }
  return id;
}

const String inviteTokenValue = 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';
const String inviteShortCodeValue = '2345-ABCD';
