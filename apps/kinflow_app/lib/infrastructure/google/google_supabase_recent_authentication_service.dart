import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_google_token_exchange.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class RecentAuthenticationSessionSnapshot {
  const RecentAuthenticationSessionSnapshot({
    required this.userId,
    required this.accessToken,
  });

  final String userId;
  final String accessToken;
}

typedef RecentAuthenticationSessionReader =
    RecentAuthenticationSessionSnapshot? Function();

final class GoogleSupabaseRecentAuthenticationService
    implements RecentAuthenticationService {
  factory GoogleSupabaseRecentAuthenticationService({
    required String serverClientId,
    required GoogleIdentityGateway identityGateway,
    required GoogleTokenExchange tokenExchange,
    required SupabaseClient client,
  }) {
    return GoogleSupabaseRecentAuthenticationService.withSessionReader(
      () {
        final Session? session = client.auth.currentSession;
        final User? user = client.auth.currentUser;
        if (session == null || user == null) {
          return null;
        }
        return RecentAuthenticationSessionSnapshot(
          userId: user.id,
          accessToken: session.accessToken,
        );
      },
      serverClientId: serverClientId,
      identityGateway: identityGateway,
      tokenExchange: tokenExchange,
    );
  }

  const GoogleSupabaseRecentAuthenticationService.withSessionReader(
    this._sessionReader, {
    required this.serverClientId,
    required this.identityGateway,
    required this.tokenExchange,
  });

  final String serverClientId;
  final GoogleIdentityGateway identityGateway;
  final GoogleTokenExchange tokenExchange;
  final RecentAuthenticationSessionReader _sessionReader;

  @override
  bool get isAvailable => serverClientId.trim().isNotEmpty;

  @override
  Future<RecentAuthenticationResult> authenticate() async {
    if (!isAvailable) {
      return const RecentAuthenticationFailed(
        RecentAuthenticationFailureKind.providerUnavailable,
      );
    }
    final RecentAuthenticationSessionSnapshot? original = _sessionReader();
    if (original == null) {
      return const RecentAuthenticationFailed(
        RecentAuthenticationFailureKind.unauthenticated,
      );
    }

    try {
      await identityGateway.signOut(serverClientId: serverClientId);
      final GoogleIdentityAuthenticationResult identityResult =
          await identityGateway.authenticate(serverClientId: serverClientId);
      switch (identityResult) {
        case GoogleIdentityAuthenticationCancelled():
          return const RecentAuthenticationFailed(
            RecentAuthenticationFailureKind.cancelled,
          );
        case GoogleIdentityAuthenticationFailed(:final kind):
          return RecentAuthenticationFailed(_identityFailure(kind));
        case GoogleIdentityAuthenticated(:final tokens):
          final GoogleTokenExchangeResult exchangeResult = await tokenExchange
              .exchange(tokens);
          if (exchangeResult case GoogleTokenExchangeFailed(:final kind)) {
            return RecentAuthenticationFailed(_exchangeFailure(kind));
          }
      }

      final RecentAuthenticationSessionSnapshot? refreshed = _sessionReader();
      if (refreshed == null) {
        return const RecentAuthenticationFailed(
          RecentAuthenticationFailureKind.invalidProof,
        );
      }
      if (refreshed.userId != original.userId) {
        return const RecentAuthenticationFailed(
          RecentAuthenticationFailureKind.accountChanged,
        );
      }
      final RecentAuthenticationProof? proof =
          RecentAuthenticationProof.tryParse(refreshed.accessToken);
      return proof == null
          ? const RecentAuthenticationFailed(
              RecentAuthenticationFailureKind.invalidProof,
            )
          : RecentAuthenticationCompleted(proof);
    } on Object {
      return const RecentAuthenticationFailed(
        RecentAuthenticationFailureKind.internal,
      );
    }
  }

  RecentAuthenticationFailureKind _identityFailure(
    GoogleIdentityFailureKind kind,
  ) {
    return switch (kind) {
      GoogleIdentityFailureKind.providerUnavailable =>
        RecentAuthenticationFailureKind.providerUnavailable,
      GoogleIdentityFailureKind.temporarilyUnavailable =>
        RecentAuthenticationFailureKind.temporarilyUnavailable,
      GoogleIdentityFailureKind.invalidResponse =>
        RecentAuthenticationFailureKind.invalidProof,
      GoogleIdentityFailureKind.unknown =>
        RecentAuthenticationFailureKind.internal,
    };
  }

  RecentAuthenticationFailureKind _exchangeFailure(
    GoogleTokenExchangeFailureKind kind,
  ) {
    return switch (kind) {
      GoogleTokenExchangeFailureKind.providerUnavailable =>
        RecentAuthenticationFailureKind.providerUnavailable,
      GoogleTokenExchangeFailureKind.temporarilyUnavailable =>
        RecentAuthenticationFailureKind.temporarilyUnavailable,
      GoogleTokenExchangeFailureKind.identityConflict =>
        RecentAuthenticationFailureKind.accountChanged,
      GoogleTokenExchangeFailureKind.invalidResponse =>
        RecentAuthenticationFailureKind.invalidProof,
      GoogleTokenExchangeFailureKind.unknown =>
        RecentAuthenticationFailureKind.internal,
    };
  }
}
