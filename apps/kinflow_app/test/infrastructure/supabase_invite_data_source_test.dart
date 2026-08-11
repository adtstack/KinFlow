import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/data/datasources/invite_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_invite_data_source.dart';

void main() {
  group('SupabaseInviteDataSource contract mapping', () {
    test('copies only an object data envelope for defensive parsing', () {
      final Map<String, Object?> source = <String, Object?>{
        'data': <String, Object?>{'id': 'invite-id'},
      };

      final Map<String, Object?>? parsed = inviteDataFromEnvelope(source);
      expect(parsed, <String, Object?>{'id': 'invite-id'});
      parsed!['id'] = 'changed';
      expect((source['data']! as Map<String, Object?>)['id'], 'invite-id');
      expect(inviteDataFromEnvelope(null), isNull);
      expect(inviteDataFromEnvelope(const <Object>[]), isNull);
      expect(
        inviteDataFromEnvelope(const <String, Object?>{'data': 7}),
        isNull,
      );
    });

    test('requires the exact one-time create response shape', () {
      const Set<String> allowed = <String>{
        'id',
        'householdId',
        'role',
        'expiresAt',
        'status',
        'rawToken',
        'shortCode',
        'shortCodeExpiresAt',
      };
      final Map<String, Object?> valid = <String, Object?>{
        'id': 'id',
        'householdId': 'household',
        'role': 'member',
        'expiresAt': 'date',
        'status': 'active',
        'rawToken': 'redacted-in-test',
        'shortCode': 'redacted-in-test',
        'shortCodeExpiresAt': 'date',
      };

      expect(hasExactCreatedInviteKeys(valid, allowed), isTrue);
      expect(
        hasExactCreatedInviteKeys(
          <String, Object?>{...valid}..remove('id'),
          allowed,
        ),
        isFalse,
      );
      expect(
        hasExactCreatedInviteKeys(<String, Object?>{
          ...valid,
          'extra': true,
        }, allowed),
        isFalse,
      );
    });

    test('requires all one-time credentials together or omits all', () {
      final Map<String, Object?> created = <String, Object?>{
        'rawToken': 'redacted-link-token',
        'shortCode': 'redacted-short-code',
        'shortCodeExpiresAt': '2030-01-02T00:00:00Z',
      };

      expect(hasCompleteOneTimeInviteCredentials(created), isTrue);
      expect(hasCompleteOneTimeInviteCredentials(<String, Object?>{}), isTrue);
      expect(
        hasCompleteOneTimeInviteCredentials(
          <String, Object?>{...created}..remove('shortCodeExpiresAt'),
        ),
        isFalse,
      );
    });

    test('maps stable function errors and hides malformed details', () {
      const Map<String, InviteDataFailureKind> cases =
          <String, InviteDataFailureKind>{
            'AUTH_REQUIRED': InviteDataFailureKind.unauthenticated,
            'VALIDATION_FAILED': InviteDataFailureKind.invalidInput,
            'IDEMPOTENCY_KEY_REQUIRED': InviteDataFailureKind.invalidInput,
            'CAPABILITY_UNSUPPORTED': InviteDataFailureKind.invalidInput,
            'PERMISSION_DENIED': InviteDataFailureKind.permissionDenied,
            'IDEMPOTENCY_KEY_REUSED': InviteDataFailureKind.idempotencyConflict,
            'INVITE_INVALID': InviteDataFailureKind.invalid,
            'INVITE_EXPIRED': InviteDataFailureKind.expired,
            'INVITE_REVOKED': InviteDataFailureKind.revoked,
            'INVITE_ALREADY_USED': InviteDataFailureKind.alreadyUsed,
            'INVITE_EMAIL_MISMATCH': InviteDataFailureKind.emailMismatch,
            'RATE_LIMITED': InviteDataFailureKind.rateLimited,
            'PROFILE_UNAVAILABLE': InviteDataFailureKind.profileUnavailable,
            'FEATURE_POLICY_UNAVAILABLE':
                InviteDataFailureKind.featurePolicyUnavailable,
            'FEATURE_LIMIT_REACHED': InviteDataFailureKind.featureLimitReached,
            'TEMPORARILY_UNAVAILABLE':
                InviteDataFailureKind.temporarilyUnavailable,
          };

      for (final entry in cases.entries) {
        expect(
          inviteDataFailureFromFunctionDetails(<String, Object?>{
            'error': <String, Object?>{'code': entry.key},
          }),
          entry.value,
          reason: entry.key,
        );
      }
      expect(
        inviteDataFailureFromFunctionDetails('provider details'),
        InviteDataFailureKind.unknown,
      );
      expect(
        inviteDataFailureFromFunctionDetails(const <String, Object?>{
          'error': <String, Object?>{'code': 7},
        }),
        InviteDataFailureKind.unknown,
      );
    });
  });
}
