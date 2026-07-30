import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:kinflow_app/infrastructure/google/google_supabase_recent_authentication_service.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_google_token_exchange.dart';

void main() {
  const String clientId = '1234567890-kinflowdev.apps.googleusercontent.com';
  const GoogleIdentityTokens tokens = GoogleIdentityTokens(
    idToken: 'ephemeral-id-token',
    accessToken: 'ephemeral-access-token',
  );
  const RecentAuthenticationSessionSnapshot original =
      RecentAuthenticationSessionSnapshot(
        userId: '11111111-1111-4111-8111-111111111111',
        accessToken: 'original-session-token',
      );

  test(
    'returns only the refreshed same-account access token as proof',
    () async {
      final _FakeIdentityGateway gateway = _FakeIdentityGateway(
        result: const GoogleIdentityAuthenticated(tokens),
      );
      final _FakeTokenExchange exchange = _FakeTokenExchange(
        result: const GoogleTokenExchangeCompleted(),
      );
      final List<RecentAuthenticationSessionSnapshot?> snapshots =
          <RecentAuthenticationSessionSnapshot?>[
            original,
            const RecentAuthenticationSessionSnapshot(
              userId: '11111111-1111-4111-8111-111111111111',
              accessToken: 'fresh-supabase-access-token',
            ),
          ];
      final GoogleSupabaseRecentAuthenticationService service =
          GoogleSupabaseRecentAuthenticationService.withSessionReader(
            () => snapshots.removeAt(0),
            serverClientId: clientId,
            identityGateway: gateway,
            tokenExchange: exchange,
          );

      final RecentAuthenticationResult result = await service.authenticate();

      expect(result, isA<RecentAuthenticationCompleted>());
      final RecentAuthenticationProof proof =
          (result as RecentAuthenticationCompleted).proof;
      expect(proof.value, 'fresh-supabase-access-token');
      expect(proof.toString(), 'RecentAuthenticationProof(redacted)');
      expect(gateway.signOutClientIds, <String>[clientId]);
      expect(gateway.authenticateClientIds, <String>[clientId]);
      expect(exchange.tokens, <GoogleIdentityTokens>[tokens]);
    },
  );

  test('different Google account stops the protected mutation proof', () async {
    final List<RecentAuthenticationSessionSnapshot?> snapshots =
        <RecentAuthenticationSessionSnapshot?>[
          original,
          const RecentAuthenticationSessionSnapshot(
            userId: '22222222-2222-4222-8222-222222222222',
            accessToken: 'other-account-access-token',
          ),
        ];
    final GoogleSupabaseRecentAuthenticationService service =
        GoogleSupabaseRecentAuthenticationService.withSessionReader(
          () => snapshots.removeAt(0),
          serverClientId: clientId,
          identityGateway: _FakeIdentityGateway(
            result: const GoogleIdentityAuthenticated(tokens),
          ),
          tokenExchange: _FakeTokenExchange(
            result: const GoogleTokenExchangeCompleted(),
          ),
        );

    final RecentAuthenticationResult result = await service.authenticate();

    expect(
      (result as RecentAuthenticationFailed).kind,
      RecentAuthenticationFailureKind.accountChanged,
    );
  });

  test(
    'cancel, missing session, invalid token, and exceptions fail closed',
    () async {
      final GoogleSupabaseRecentAuthenticationService cancelled =
          GoogleSupabaseRecentAuthenticationService.withSessionReader(
            () => original,
            serverClientId: clientId,
            identityGateway: _FakeIdentityGateway(
              result: const GoogleIdentityAuthenticationCancelled(),
            ),
            tokenExchange: _FakeTokenExchange(
              result: const GoogleTokenExchangeCompleted(),
            ),
          );
      expect(
        ((await cancelled.authenticate()) as RecentAuthenticationFailed).kind,
        RecentAuthenticationFailureKind.cancelled,
      );

      final GoogleSupabaseRecentAuthenticationService missing =
          GoogleSupabaseRecentAuthenticationService.withSessionReader(
            () => null,
            serverClientId: clientId,
            identityGateway: _FakeIdentityGateway(
              result: const GoogleIdentityAuthenticated(tokens),
            ),
            tokenExchange: _FakeTokenExchange(
              result: const GoogleTokenExchangeCompleted(),
            ),
          );
      expect(
        ((await missing.authenticate()) as RecentAuthenticationFailed).kind,
        RecentAuthenticationFailureKind.unauthenticated,
      );

      final List<RecentAuthenticationSessionSnapshot?> invalidSnapshots =
          <RecentAuthenticationSessionSnapshot?>[
            original,
            const RecentAuthenticationSessionSnapshot(
              userId: '11111111-1111-4111-8111-111111111111',
              accessToken: 'short',
            ),
          ];
      final GoogleSupabaseRecentAuthenticationService invalid =
          GoogleSupabaseRecentAuthenticationService.withSessionReader(
            () => invalidSnapshots.removeAt(0),
            serverClientId: clientId,
            identityGateway: _FakeIdentityGateway(
              result: const GoogleIdentityAuthenticated(tokens),
            ),
            tokenExchange: _FakeTokenExchange(
              result: const GoogleTokenExchangeCompleted(),
            ),
          );
      expect(
        ((await invalid.authenticate()) as RecentAuthenticationFailed).kind,
        RecentAuthenticationFailureKind.invalidProof,
      );

      final GoogleSupabaseRecentAuthenticationService throwing =
          GoogleSupabaseRecentAuthenticationService.withSessionReader(
            () => original,
            serverClientId: clientId,
            identityGateway: _FakeIdentityGateway(shouldThrow: true),
            tokenExchange: _FakeTokenExchange(
              result: const GoogleTokenExchangeCompleted(),
            ),
          );
      expect(
        ((await throwing.authenticate()) as RecentAuthenticationFailed).kind,
        RecentAuthenticationFailureKind.internal,
      );
    },
  );

  test(
    'provider and exchange failures map without exposing provider details',
    () async {
      const Map<GoogleIdentityFailureKind, RecentAuthenticationFailureKind>
      identityCases =
          <GoogleIdentityFailureKind, RecentAuthenticationFailureKind>{
            GoogleIdentityFailureKind.providerUnavailable:
                RecentAuthenticationFailureKind.providerUnavailable,
            GoogleIdentityFailureKind.temporarilyUnavailable:
                RecentAuthenticationFailureKind.temporarilyUnavailable,
            GoogleIdentityFailureKind.invalidResponse:
                RecentAuthenticationFailureKind.invalidProof,
            GoogleIdentityFailureKind.unknown:
                RecentAuthenticationFailureKind.internal,
          };
      for (final entry in identityCases.entries) {
        final service =
            GoogleSupabaseRecentAuthenticationService.withSessionReader(
              () => original,
              serverClientId: clientId,
              identityGateway: _FakeIdentityGateway(
                result: GoogleIdentityAuthenticationFailed(entry.key),
              ),
              tokenExchange: _FakeTokenExchange(
                result: const GoogleTokenExchangeCompleted(),
              ),
            );
        expect(
          ((await service.authenticate()) as RecentAuthenticationFailed).kind,
          entry.value,
        );
      }

      const Map<GoogleTokenExchangeFailureKind, RecentAuthenticationFailureKind>
      exchangeCases =
          <GoogleTokenExchangeFailureKind, RecentAuthenticationFailureKind>{
            GoogleTokenExchangeFailureKind.providerUnavailable:
                RecentAuthenticationFailureKind.providerUnavailable,
            GoogleTokenExchangeFailureKind.temporarilyUnavailable:
                RecentAuthenticationFailureKind.temporarilyUnavailable,
            GoogleTokenExchangeFailureKind.invalidResponse:
                RecentAuthenticationFailureKind.invalidProof,
            GoogleTokenExchangeFailureKind.unknown:
                RecentAuthenticationFailureKind.internal,
          };
      for (final entry in exchangeCases.entries) {
        final service =
            GoogleSupabaseRecentAuthenticationService.withSessionReader(
              () => original,
              serverClientId: clientId,
              identityGateway: _FakeIdentityGateway(
                result: const GoogleIdentityAuthenticated(tokens),
              ),
              tokenExchange: _FakeTokenExchange(
                result: GoogleTokenExchangeFailed(entry.key),
              ),
            );
        expect(
          ((await service.authenticate()) as RecentAuthenticationFailed).kind,
          entry.value,
        );
      }
    },
  );
}

final class _FakeIdentityGateway implements GoogleIdentityGateway {
  _FakeIdentityGateway({this.result, this.shouldThrow = false});

  final GoogleIdentityAuthenticationResult? result;
  final bool shouldThrow;
  final List<String> authenticateClientIds = <String>[];
  final List<String> signOutClientIds = <String>[];

  @override
  Future<GoogleIdentityAuthenticationResult> authenticate({
    required String serverClientId,
  }) async {
    authenticateClientIds.add(serverClientId);
    if (shouldThrow) {
      throw StateError('provider detail must remain private');
    }
    return result!;
  }

  @override
  Future<void> signOut({required String serverClientId}) async {
    signOutClientIds.add(serverClientId);
    if (shouldThrow) {
      throw StateError('provider detail must remain private');
    }
  }
}

final class _FakeTokenExchange implements GoogleTokenExchange {
  _FakeTokenExchange({required this.result});

  final GoogleTokenExchangeResult result;
  final List<GoogleIdentityTokens> tokens = <GoogleIdentityTokens>[];

  @override
  Future<GoogleTokenExchangeResult> exchange(
    GoogleIdentityTokens tokens,
  ) async {
    this.tokens.add(tokens);
    return result;
  }
}
