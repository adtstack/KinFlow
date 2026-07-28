import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/data/datasources/auth_sign_in_data_source.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_state_purge_participant.dart';
import 'package:kinflow_app/infrastructure/google/google_supabase_auth_sign_in_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_google_token_exchange.dart';

void main() {
  const String clientId = '1234567890-kinflowdev.apps.googleusercontent.com';
  const GoogleIdentityTokens tokens = GoogleIdentityTokens(
    idToken: 'ephemeral-id-token',
    accessToken: 'ephemeral-access-token',
  );

  group('GoogleSupabaseAuthSignInDataSource', () {
    test('exchanges successful Google authentication exactly once', () async {
      final _FakeGoogleIdentityGateway gateway = _FakeGoogleIdentityGateway(
        result: const GoogleIdentityAuthenticated(tokens),
      );
      final _FakeGoogleTokenExchange exchange = _FakeGoogleTokenExchange(
        result: const GoogleTokenExchangeCompleted(),
      );
      final GoogleSupabaseAuthSignInDataSource dataSource =
          GoogleSupabaseAuthSignInDataSource(
            serverClientId: clientId,
            identityGateway: gateway,
            tokenExchange: exchange,
          );

      expect(dataSource.isAvailable, isTrue);
      expect(
        await dataSource.requestGoogleSignIn(),
        isA<AuthSignInDataCompleted>(),
      );
      expect(gateway.authenticateClientIds, <String>[clientId]);
      expect(exchange.tokens, <GoogleIdentityTokens>[tokens]);
    });

    test('does not exchange a cancelled Google request', () async {
      final _FakeGoogleTokenExchange exchange = _FakeGoogleTokenExchange(
        result: const GoogleTokenExchangeCompleted(),
      );
      final GoogleSupabaseAuthSignInDataSource dataSource =
          GoogleSupabaseAuthSignInDataSource(
            serverClientId: clientId,
            identityGateway: _FakeGoogleIdentityGateway(
              result: const GoogleIdentityAuthenticationCancelled(),
            ),
            tokenExchange: exchange,
          );

      expect(
        await dataSource.requestGoogleSignIn(),
        isA<AuthSignInDataCancelled>(),
      );
      expect(exchange.tokens, isEmpty);
    });

    test(
      'maps Google and Supabase failures to provider-neutral kinds',
      () async {
        const Map<GoogleIdentityFailureKind, AuthSignInDataFailureKind>
        identityExpectations =
            <GoogleIdentityFailureKind, AuthSignInDataFailureKind>{
              GoogleIdentityFailureKind.providerUnavailable:
                  AuthSignInDataFailureKind.providerUnavailable,
              GoogleIdentityFailureKind.temporarilyUnavailable:
                  AuthSignInDataFailureKind.temporarilyUnavailable,
              GoogleIdentityFailureKind.invalidResponse:
                  AuthSignInDataFailureKind.invalidPayload,
              GoogleIdentityFailureKind.unknown:
                  AuthSignInDataFailureKind.unknown,
            };
        for (final MapEntry<
              GoogleIdentityFailureKind,
              AuthSignInDataFailureKind
            >
            entry
            in identityExpectations.entries) {
          final GoogleSupabaseAuthSignInDataSource dataSource =
              GoogleSupabaseAuthSignInDataSource(
                serverClientId: clientId,
                identityGateway: _FakeGoogleIdentityGateway(
                  result: GoogleIdentityAuthenticationFailed(entry.key),
                ),
                tokenExchange: _FakeGoogleTokenExchange(
                  result: const GoogleTokenExchangeCompleted(),
                ),
              );

          final AuthSignInDataResult result = await dataSource
              .requestGoogleSignIn();
          expect((result as AuthSignInDataFailed).kind, entry.value);
        }

        const Map<GoogleTokenExchangeFailureKind, AuthSignInDataFailureKind>
        exchangeExpectations =
            <GoogleTokenExchangeFailureKind, AuthSignInDataFailureKind>{
              GoogleTokenExchangeFailureKind.providerUnavailable:
                  AuthSignInDataFailureKind.providerUnavailable,
              GoogleTokenExchangeFailureKind.temporarilyUnavailable:
                  AuthSignInDataFailureKind.temporarilyUnavailable,
              GoogleTokenExchangeFailureKind.invalidResponse:
                  AuthSignInDataFailureKind.invalidPayload,
              GoogleTokenExchangeFailureKind.unknown:
                  AuthSignInDataFailureKind.unknown,
            };
        for (final MapEntry<
              GoogleTokenExchangeFailureKind,
              AuthSignInDataFailureKind
            >
            entry
            in exchangeExpectations.entries) {
          final GoogleSupabaseAuthSignInDataSource dataSource =
              GoogleSupabaseAuthSignInDataSource(
                serverClientId: clientId,
                identityGateway: _FakeGoogleIdentityGateway(
                  result: const GoogleIdentityAuthenticated(tokens),
                ),
                tokenExchange: _FakeGoogleTokenExchange(
                  result: GoogleTokenExchangeFailed(entry.key),
                ),
              );

          final AuthSignInDataResult result = await dataSource
              .requestGoogleSignIn();
          expect((result as AuthSignInDataFailed).kind, entry.value);
        }
      },
    );

    test(
      'fails closed for empty configuration and unexpected errors',
      () async {
        final _FakeGoogleIdentityGateway emptyGateway =
            _FakeGoogleIdentityGateway(
              result: const GoogleIdentityAuthenticated(tokens),
            );
        final GoogleSupabaseAuthSignInDataSource unavailable =
            GoogleSupabaseAuthSignInDataSource(
              serverClientId: ' ',
              identityGateway: emptyGateway,
              tokenExchange: _FakeGoogleTokenExchange(
                result: const GoogleTokenExchangeCompleted(),
              ),
            );

        final AuthSignInDataResult unavailableResult = await unavailable
            .requestGoogleSignIn();
        expect(unavailable.isAvailable, isFalse);
        expect(
          (unavailableResult as AuthSignInDataFailed).kind,
          AuthSignInDataFailureKind.providerUnavailable,
        );
        expect(emptyGateway.authenticateClientIds, isEmpty);

        final GoogleSupabaseAuthSignInDataSource throwing =
            GoogleSupabaseAuthSignInDataSource(
              serverClientId: clientId,
              identityGateway: _FakeGoogleIdentityGateway(shouldThrow: true),
              tokenExchange: _FakeGoogleTokenExchange(
                result: const GoogleTokenExchangeCompleted(),
              ),
            );
        final AuthSignInDataResult throwingResult = await throwing
            .requestGoogleSignIn();
        expect(
          (throwingResult as AuthSignInDataFailed).kind,
          AuthSignInDataFailureKind.unknown,
        );
      },
    );
  });

  test('Google purge participant signs out the configured client', () async {
    final _FakeGoogleIdentityGateway gateway = _FakeGoogleIdentityGateway(
      result: const GoogleIdentityAuthenticationCancelled(),
    );
    final GoogleIdentityStatePurgeParticipant participant =
        GoogleIdentityStatePurgeParticipant(
          serverClientId: clientId,
          identityGateway: gateway,
        );

    await participant.purgeSensitiveLocalState();

    expect(gateway.signOutClientIds, <String>[clientId]);
  });
}

final class _FakeGoogleIdentityGateway implements GoogleIdentityGateway {
  _FakeGoogleIdentityGateway({this.result, this.shouldThrow = false});

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
      throw StateError('provider detail must not escape');
    }
    return result!;
  }

  @override
  Future<void> signOut({required String serverClientId}) async {
    signOutClientIds.add(serverClientId);
    if (shouldThrow) {
      throw StateError('provider detail must not escape');
    }
  }
}

final class _FakeGoogleTokenExchange implements GoogleTokenExchange {
  _FakeGoogleTokenExchange({required this.result});

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
