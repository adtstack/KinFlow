import 'package:kinflow_app/features/auth/data/datasources/auth_sign_in_data_source.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_google_token_exchange.dart';

final class GoogleSupabaseAuthSignInDataSource implements AuthSignInDataSource {
  const GoogleSupabaseAuthSignInDataSource({
    required this.serverClientId,
    required this.identityGateway,
    required this.tokenExchange,
  });

  final String serverClientId;
  final GoogleIdentityGateway identityGateway;
  final GoogleTokenExchange tokenExchange;

  @override
  bool get isAvailable => serverClientId.trim().isNotEmpty;

  @override
  Future<AuthSignInDataResult> requestGoogleSignIn() async {
    if (!isAvailable) {
      return const AuthSignInDataFailed(
        AuthSignInDataFailureKind.providerUnavailable,
      );
    }

    try {
      final GoogleIdentityAuthenticationResult identityResult =
          await identityGateway.authenticate(serverClientId: serverClientId);
      switch (identityResult) {
        case GoogleIdentityAuthenticationCancelled():
          return const AuthSignInDataCancelled();
        case GoogleIdentityAuthenticationFailed(:final kind):
          return AuthSignInDataFailed(_identityFailureKind(kind));
        case GoogleIdentityAuthenticated(:final tokens):
          final GoogleTokenExchangeResult exchangeResult = await tokenExchange
              .exchange(tokens);
          return switch (exchangeResult) {
            GoogleTokenExchangeCompleted() => const AuthSignInDataCompleted(),
            GoogleTokenExchangeFailed(:final kind) => AuthSignInDataFailed(
              _exchangeFailureKind(kind),
            ),
          };
      }
    } on Object {
      return const AuthSignInDataFailed(AuthSignInDataFailureKind.unknown);
    }
  }

  AuthSignInDataFailureKind _identityFailureKind(
    GoogleIdentityFailureKind kind,
  ) {
    return switch (kind) {
      GoogleIdentityFailureKind.providerUnavailable =>
        AuthSignInDataFailureKind.providerUnavailable,
      GoogleIdentityFailureKind.temporarilyUnavailable =>
        AuthSignInDataFailureKind.temporarilyUnavailable,
      GoogleIdentityFailureKind.invalidResponse =>
        AuthSignInDataFailureKind.invalidPayload,
      GoogleIdentityFailureKind.unknown => AuthSignInDataFailureKind.unknown,
    };
  }

  AuthSignInDataFailureKind _exchangeFailureKind(
    GoogleTokenExchangeFailureKind kind,
  ) {
    return switch (kind) {
      GoogleTokenExchangeFailureKind.providerUnavailable =>
        AuthSignInDataFailureKind.providerUnavailable,
      GoogleTokenExchangeFailureKind.temporarilyUnavailable =>
        AuthSignInDataFailureKind.temporarilyUnavailable,
      GoogleTokenExchangeFailureKind.invalidResponse =>
        AuthSignInDataFailureKind.invalidPayload,
      GoogleTokenExchangeFailureKind.unknown =>
        AuthSignInDataFailureKind.unknown,
    };
  }
}
