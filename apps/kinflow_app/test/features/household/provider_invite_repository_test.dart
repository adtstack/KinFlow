import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/data/datasources/invite_data_source.dart';
import 'package:kinflow_app/features/household/data/dto/invite_dto.dart';
import 'package:kinflow_app/features/household/data/repositories/provider_invite_repository.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite_request.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/invite_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

import '../../support/fakes/fake_invite_dependencies.dart';

void main() {
  group('ProviderInviteRepository', () {
    test(
      'maps one-time create token without exposing it in diagnostics',
      () async {
        final _FakeInviteDataSource dataSource = _FakeInviteDataSource(
          createResult: InviteDataSucceeded<CreatedInviteRecord>(
            CreatedInviteRecord(dto: _inviteDto(), rawToken: inviteTokenValue),
          ),
        );
        final ProviderInviteRepository repository = ProviderInviteRepository(
          dataSource,
        );

        final CreateHouseholdInviteResult result = await repository
            .createInvite(_createRequest());

        final HouseholdInvite invite =
            (result as HouseholdInviteCreated).invite;
        expect(invite.rawToken?.value, inviteTokenValue);
        expect(invite.toString(), isNot(contains(inviteTokenValue)));
        expect(dataSource.lastTargetEmail, 'adult@example.com');
        expect(dataSource.lastRole, 'member');
        expect(dataSource.lastExpiresInHours, 168);
      },
    );

    test('rejects malformed created identifiers and raw tokens', () async {
      final ProviderInviteRepository malformedId = ProviderInviteRepository(
        _FakeInviteDataSource(
          createResult: InviteDataSucceeded<CreatedInviteRecord>(
            CreatedInviteRecord(
              dto: _inviteDto(id: 'provider-controlled-id'),
              rawToken: inviteTokenValue,
            ),
          ),
        ),
      );
      final ProviderInviteRepository malformedToken = ProviderInviteRepository(
        _FakeInviteDataSource(
          createResult: InviteDataSucceeded<CreatedInviteRecord>(
            CreatedInviteRecord(dto: _inviteDto(), rawToken: 'short'),
          ),
        ),
      );

      expect(
        (await malformedId.createInvite(_createRequest())
                as CreateHouseholdInviteFailed)
            .failure
            .kind,
        InviteFailureKind.invalidPayload,
      );
      expect(
        (await malformedToken.createInvite(_createRequest())
                as CreateHouseholdInviteFailed)
            .failure
            .kind,
        InviteFailureKind.invalidPayload,
      );
    });

    test('maps only a complete one-time short-code companion', () async {
      final ProviderInviteRepository repository = ProviderInviteRepository(
        _FakeInviteDataSource(
          createResult: InviteDataSucceeded<CreatedInviteRecord>(
            CreatedInviteRecord(
              dto: _inviteDto(),
              rawToken: inviteTokenValue,
              rawShortCode: inviteShortCodeValue,
              shortCodeExpiresAt: '2030-01-02T00:00:00Z',
            ),
          ),
        ),
      );
      final ProviderInviteRepository partial = ProviderInviteRepository(
        _FakeInviteDataSource(
          createResult: InviteDataSucceeded<CreatedInviteRecord>(
            CreatedInviteRecord(
              dto: _inviteDto(),
              rawToken: inviteTokenValue,
              rawShortCode: inviteShortCodeValue,
            ),
          ),
        ),
      );

      final HouseholdInvite invite =
          (await repository.createInvite(_createRequest())
                  as HouseholdInviteCreated)
              .invite;

      expect(invite.rawShortCode?.formatted, inviteShortCodeValue);
      expect(invite.shortCodeExpiresAt, DateTime.utc(2030, 1, 2));
      expect(invite.toString(), isNot(contains(inviteShortCodeValue)));
      expect(
        (await partial.createInvite(_createRequest())
                as CreateHouseholdInviteFailed)
            .failure
            .kind,
        InviteFailureKind.invalidPayload,
      );
    });

    test('maps minimal preview and rejects provider field drift', () async {
      final ProviderInviteRepository repository = ProviderInviteRepository(
        _FakeInviteDataSource(
          previewResult: const InviteDataSucceeded<InvitePreviewDto>(
            InvitePreviewDto(
              valid: true,
              householdDisplayName: 'Kim Home',
              inviterDisplayName: 'Alex',
              role: 'member',
              expiresAt: '2030-01-08T00:00:00Z',
            ),
          ),
        ),
      );
      final ProviderInviteRepository drifted = ProviderInviteRepository(
        _FakeInviteDataSource(
          previewResult: const InviteDataSucceeded<InvitePreviewDto>(
            InvitePreviewDto(
              valid: false,
              householdDisplayName: 'Kim Home',
              inviterDisplayName: 'Alex',
              role: 'owner',
              expiresAt: 'not-a-date',
            ),
          ),
        ),
      );

      final HouseholdInvitePreviewed result =
          await repository.previewInvite(_token()) as HouseholdInvitePreviewed;
      expect(result.preview.householdDisplayName, 'Kim Home');
      expect(
        (await drifted.previewInvite(_token()) as PreviewHouseholdInviteFailed)
            .failure
            .kind,
        InviteFailureKind.invalidPayload,
      );
    });

    test('maps accepted membership and revoked status', () async {
      final ProviderInviteRepository repository = ProviderInviteRepository(
        _FakeInviteDataSource(
          acceptResult: const InviteDataSucceeded<InviteMemberDto>(
            InviteMemberDto(
              id: '66666666-6666-4666-8666-666666666666',
              householdId: '55555555-5555-4555-8555-555555555555',
              displayName: 'Taylor',
              role: 'member',
              activeHouseholdSet: true,
            ),
          ),
          revokeResult: const InviteDataSucceeded<RevokedInviteDto>(
            RevokedInviteDto(
              id: '44444444-4444-4444-8444-444444444444',
              householdId: '22222222-2222-4222-8222-222222222222',
              status: 'revoked',
            ),
          ),
        ),
      );

      final HouseholdInviteAccepted accepted =
          await repository.acceptInvite(_acceptRequest())
              as HouseholdInviteAccepted;
      final HouseholdInviteRevoked revoked =
          await repository.revokeInvite(_revokeRequest())
              as HouseholdInviteRevoked;

      expect(accepted.acceptance.activeHouseholdSet, isTrue);
      expect(
        accepted.acceptance.household.householdId.value,
        '55555555-5555-4555-8555-555555555555',
      );
      expect(revoked.inviteId, inviteIdFixture());
    });

    test(
      'selects short-code provider operations without a link token',
      () async {
        final _FakeInviteDataSource dataSource = _FakeInviteDataSource(
          previewResult: const InviteDataSucceeded<InvitePreviewDto>(
            InvitePreviewDto(
              valid: true,
              householdDisplayName: 'Kim Home',
              inviterDisplayName: 'Alex',
              role: 'member',
              expiresAt: '2030-01-02T00:00:00Z',
            ),
          ),
          acceptResult: const InviteDataSucceeded<InviteMemberDto>(
            InviteMemberDto(
              id: '66666666-6666-4666-8666-666666666666',
              householdId: '55555555-5555-4555-8555-555555555555',
              displayName: 'Taylor',
              role: 'member',
              activeHouseholdSet: true,
            ),
          ),
        );
        final ProviderInviteRepository repository = ProviderInviteRepository(
          dataSource,
        );
        final InviteShortCode shortCode = InviteShortCode.tryParse(
          inviteShortCodeValue,
        )!;

        expect(
          await repository.previewInviteByShortCode(shortCode),
          isA<HouseholdInvitePreviewed>(),
        );
        expect(
          await repository.acceptInviteByShortCode(
            AcceptHouseholdInviteByShortCodeRequest(
              idempotencyKey: inviteCommandIdFixture(
                'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              ),
              shortCode: shortCode,
              setActiveHousehold: true,
            ),
          ),
          isA<HouseholdInviteAccepted>(),
        );

        expect(dataSource.lastPreviewShortCode, '2345ABCD');
        expect(dataSource.lastPreviewToken, isNull);
        expect(dataSource.lastAcceptShortCode, '2345ABCD');
        expect(dataSource.lastAcceptToken, isNull);
      },
    );

    test('maps every data failure to a stable domain failure', () async {
      const Map<InviteDataFailureKind, InviteFailureKind>
      cases = <InviteDataFailureKind, InviteFailureKind>{
        InviteDataFailureKind.unauthenticated:
            InviteFailureKind.unauthenticated,
        InviteDataFailureKind.invalidInput: InviteFailureKind.invalidInput,
        InviteDataFailureKind.permissionDenied:
            InviteFailureKind.permissionDenied,
        InviteDataFailureKind.idempotencyConflict:
            InviteFailureKind.idempotencyConflict,
        InviteDataFailureKind.invalid: InviteFailureKind.invalid,
        InviteDataFailureKind.expired: InviteFailureKind.expired,
        InviteDataFailureKind.revoked: InviteFailureKind.revoked,
        InviteDataFailureKind.alreadyUsed: InviteFailureKind.alreadyUsed,
        InviteDataFailureKind.emailMismatch: InviteFailureKind.emailMismatch,
        InviteDataFailureKind.rateLimited: InviteFailureKind.rateLimited,
        InviteDataFailureKind.profileUnavailable:
            InviteFailureKind.profileUnavailable,
        InviteDataFailureKind.featurePolicyUnavailable:
            InviteFailureKind.featurePolicyUnavailable,
        InviteDataFailureKind.featureLimitReached:
            InviteFailureKind.featureLimitReached,
        InviteDataFailureKind.temporarilyUnavailable:
            InviteFailureKind.temporarilyUnavailable,
        InviteDataFailureKind.invalidPayload: InviteFailureKind.invalidPayload,
        InviteDataFailureKind.unknown: InviteFailureKind.internal,
      };

      for (final entry in cases.entries) {
        final ProviderInviteRepository repository = ProviderInviteRepository(
          _FakeInviteDataSource(
            previewResult: InviteDataFailed<InvitePreviewDto>(entry.key),
          ),
        );
        final PreviewHouseholdInviteFailed result =
            await repository.previewInvite(_token())
                as PreviewHouseholdInviteFailed;
        expect(result.failure.kind, entry.value, reason: entry.key.name);
      }
    });
  });
}

final class _FakeInviteDataSource implements InviteDataSource {
  _FakeInviteDataSource({
    this.createResult = const InviteDataFailed<CreatedInviteRecord>(
      InviteDataFailureKind.temporarilyUnavailable,
    ),
    this.previewResult = const InviteDataFailed<InvitePreviewDto>(
      InviteDataFailureKind.temporarilyUnavailable,
    ),
    this.acceptResult = const InviteDataFailed<InviteMemberDto>(
      InviteDataFailureKind.temporarilyUnavailable,
    ),
    this.revokeResult = const InviteDataFailed<RevokedInviteDto>(
      InviteDataFailureKind.temporarilyUnavailable,
    ),
  });

  final InviteDataResult<CreatedInviteRecord> createResult;
  final InviteDataResult<InvitePreviewDto> previewResult;
  final InviteDataResult<InviteMemberDto> acceptResult;
  final InviteDataResult<RevokedInviteDto> revokeResult;
  String? lastTargetEmail;
  String? lastRole;
  int? lastExpiresInHours;
  String? lastPreviewToken;
  String? lastPreviewShortCode;
  String? lastAcceptToken;
  String? lastAcceptShortCode;

  @override
  Future<InviteDataResult<CreatedInviteRecord>> createInvite({
    required String idempotencyKey,
    required String householdId,
    required String role,
    required int expiresInHours,
    required String? targetEmail,
  }) async {
    lastTargetEmail = targetEmail;
    lastRole = role;
    lastExpiresInHours = expiresInHours;
    return createResult;
  }

  @override
  Future<InviteDataResult<InvitePreviewDto>> previewInvite({
    required String token,
  }) async {
    lastPreviewToken = token;
    return previewResult;
  }

  @override
  Future<InviteDataResult<InvitePreviewDto>> previewInviteByShortCode({
    required String shortCode,
  }) async {
    lastPreviewShortCode = shortCode;
    return previewResult;
  }

  @override
  Future<InviteDataResult<InviteMemberDto>> acceptInvite({
    required String idempotencyKey,
    required String token,
    required bool setActiveHousehold,
  }) async {
    lastAcceptToken = token;
    return acceptResult;
  }

  @override
  Future<InviteDataResult<InviteMemberDto>> acceptInviteByShortCode({
    required String idempotencyKey,
    required String shortCode,
    required bool setActiveHousehold,
  }) async {
    lastAcceptShortCode = shortCode;
    return acceptResult;
  }

  @override
  Future<InviteDataResult<RevokedInviteDto>> revokeInvite({
    required String idempotencyKey,
    required String householdId,
    required String inviteId,
  }) async => revokeResult;
}

InviteDto _inviteDto({String id = '44444444-4444-4444-8444-444444444444'}) {
  return InviteDto(
    id: id,
    householdId: '22222222-2222-4222-8222-222222222222',
    role: 'member',
    expiresAt: '2030-01-08T00:00:00Z',
    status: 'active',
  );
}

CreateHouseholdInviteRequest _createRequest() {
  return CreateHouseholdInviteRequest(
    idempotencyKey: inviteCommandIdFixture(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    ),
    householdId: householdIdFixture(),
    role: HouseholdInviteRole.member,
    expiresInHours: 168,
    targetEmail: 'adult@example.com',
  );
}

AcceptHouseholdInviteRequest _acceptRequest() {
  return AcceptHouseholdInviteRequest(
    idempotencyKey: inviteCommandIdFixture(
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    ),
    token: _token(),
    setActiveHousehold: true,
  );
}

RevokeHouseholdInviteRequest _revokeRequest() {
  return RevokeHouseholdInviteRequest(
    idempotencyKey: inviteCommandIdFixture(
      'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    ),
    householdId: householdIdFixture(),
    inviteId: inviteIdFixture(),
  );
}

InviteToken _token() {
  final InviteToken? token = InviteToken.tryParse(inviteTokenValue);
  if (token == null) {
    throw StateError('Static token fixture must be valid.');
  }
  return token;
}
