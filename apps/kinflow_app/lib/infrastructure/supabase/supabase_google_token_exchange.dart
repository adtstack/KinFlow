import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum GoogleTokenExchangeFailureKind {
  providerUnavailable,
  temporarilyUnavailable,
  invalidResponse,
  unknown,
}

sealed class GoogleTokenExchangeResult {
  const GoogleTokenExchangeResult();
}

final class GoogleTokenExchangeCompleted extends GoogleTokenExchangeResult {
  const GoogleTokenExchangeCompleted();
}

final class GoogleTokenExchangeFailed extends GoogleTokenExchangeResult {
  const GoogleTokenExchangeFailed(this.kind);

  final GoogleTokenExchangeFailureKind kind;
}

abstract interface class GoogleTokenExchange {
  Future<GoogleTokenExchangeResult> exchange(GoogleIdentityTokens tokens);
}

typedef SupabaseGoogleIdTokenExchangeCall =
    Future<bool> Function(String idToken, String accessToken);

final class SupabaseGoogleTokenExchange implements GoogleTokenExchange {
  factory SupabaseGoogleTokenExchange(SupabaseClient client) {
    return SupabaseGoogleTokenExchange.withCall((
      String idToken,
      String accessToken,
    ) async {
      final AuthResponse response = await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return response.session != null && response.user != null;
    });
  }

  const SupabaseGoogleTokenExchange.withCall(this._exchange);

  final SupabaseGoogleIdTokenExchangeCall _exchange;

  @override
  Future<GoogleTokenExchangeResult> exchange(
    GoogleIdentityTokens tokens,
  ) async {
    try {
      final bool established = await _exchange(
        tokens.idToken,
        tokens.accessToken,
      );
      if (!established) {
        return const GoogleTokenExchangeFailed(
          GoogleTokenExchangeFailureKind.invalidResponse,
        );
      }
      return const GoogleTokenExchangeCompleted();
    } on AuthRetryableFetchException {
      return const GoogleTokenExchangeFailed(
        GoogleTokenExchangeFailureKind.temporarilyUnavailable,
      );
    } on AuthException {
      return const GoogleTokenExchangeFailed(
        GoogleTokenExchangeFailureKind.providerUnavailable,
      );
    } on Object {
      return const GoogleTokenExchangeFailed(
        GoogleTokenExchangeFailureKind.unknown,
      );
    }
  }
}
