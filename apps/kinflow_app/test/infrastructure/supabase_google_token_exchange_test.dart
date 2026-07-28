import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_google_token_exchange.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const GoogleIdentityTokens tokens = GoogleIdentityTokens(
    idToken: 'ephemeral-id-token',
    accessToken: 'ephemeral-access-token',
  );

  group('SupabaseGoogleTokenExchange', () {
    test(
      'forwards both tokens and accepts only an established session',
      () async {
        String? receivedIdToken;
        String? receivedAccessToken;
        final SupabaseGoogleTokenExchange exchange =
            SupabaseGoogleTokenExchange.withCall((
              String idToken,
              String accessToken,
            ) async {
              receivedIdToken = idToken;
              receivedAccessToken = accessToken;
              return true;
            });

        expect(
          await exchange.exchange(tokens),
          isA<GoogleTokenExchangeCompleted>(),
        );
        expect(receivedIdToken, tokens.idToken);
        expect(receivedAccessToken, tokens.accessToken);
      },
    );

    test('rejects a provider response without a session', () async {
      final SupabaseGoogleTokenExchange exchange =
          SupabaseGoogleTokenExchange.withCall((_, _) async => false);

      final GoogleTokenExchangeResult result = await exchange.exchange(tokens);

      expect(
        (result as GoogleTokenExchangeFailed).kind,
        GoogleTokenExchangeFailureKind.invalidResponse,
      );
    });

    test('maps SDK errors without exposing their messages', () async {
      final List<
        (SupabaseGoogleIdTokenExchangeCall, GoogleTokenExchangeFailureKind)
      >
      expectations =
          <(SupabaseGoogleIdTokenExchangeCall, GoogleTokenExchangeFailureKind)>[
            (
              (_, _) async =>
                  throw AuthRetryableFetchException(message: 'network detail'),
              GoogleTokenExchangeFailureKind.temporarilyUnavailable,
            ),
            (
              (_, _) async => throw const AuthException('provider detail'),
              GoogleTokenExchangeFailureKind.providerUnavailable,
            ),
            (
              (_, _) async => throw StateError('internal detail'),
              GoogleTokenExchangeFailureKind.unknown,
            ),
          ];

      for (final (
            SupabaseGoogleIdTokenExchangeCall call,
            GoogleTokenExchangeFailureKind expected,
          )
          in expectations) {
        final SupabaseGoogleTokenExchange exchange =
            SupabaseGoogleTokenExchange.withCall(call);

        final GoogleTokenExchangeResult result = await exchange.exchange(
          tokens,
        );
        expect((result as GoogleTokenExchangeFailed).kind, expected);
        expect(result.toString(), isNot(contains('detail')));
      }
    });
  });
}
