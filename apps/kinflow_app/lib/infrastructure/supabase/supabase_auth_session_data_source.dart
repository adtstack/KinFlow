import 'package:kinflow_app/features/auth/data/datasources/auth_session_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// This adapter must only be composed with a [SupabaseClient] whose auth
/// persistence uses the approved platform secure-storage implementation.
final class SupabaseAuthSessionDataSource implements AuthSessionDataSource {
  const SupabaseAuthSessionDataSource(this._client);

  final SupabaseClient _client;

  @override
  Stream<AuthSessionDataEvent> get sessionEvents async* {
    try {
      await for (final AuthState state in _client.auth.onAuthStateChange) {
        final AuthSessionDataEvent? event = _mapEvent(state);
        if (event != null) {
          yield event;
        }
      }
    } on AuthException catch (error) {
      yield AuthSessionDataEventFailed(_mapFailure(error));
    } on Object {
      yield const AuthSessionDataEventFailed(
        AuthSessionDataFailureKind.unknown,
      );
    }
  }

  @override
  Future<AuthSessionDataResult> restoreSession() async {
    final Session? session = _client.auth.currentSession;
    if (session == null) {
      return const AuthSessionDataAbsent();
    }
    if (session.isExpired) {
      return refreshSession();
    }
    return _record(session);
  }

  @override
  Future<AuthSessionDataResult> refreshSession() async {
    try {
      final AuthResponse response = await _client.auth.refreshSession();
      final Session? session = response.session;
      if (session == null) {
        return const AuthSessionDataFailed(
          AuthSessionDataFailureKind.sessionExpired,
        );
      }
      return _record(session);
    } on AuthException catch (error) {
      return AuthSessionDataFailed(_mapFailure(error));
    } on Object {
      return const AuthSessionDataFailed(AuthSessionDataFailureKind.unknown);
    }
  }

  @override
  Future<AuthSignOutDataResult> signOut() async {
    try {
      await _client.auth.signOut();
      return const AuthSignOutDataCompleted();
    } on AuthException catch (error) {
      return AuthSignOutDataFailed(_mapFailure(error));
    } on Object {
      return const AuthSignOutDataFailed(AuthSessionDataFailureKind.unknown);
    }
  }

  AuthSessionDataEvent? _mapEvent(AuthState state) {
    return switch (state.event) {
      AuthChangeEvent.initialSession => null,
      AuthChangeEvent.signedOut => AuthSessionDataTerminated(
        switch (state.signOutReason) {
          SignOutReason.sessionExpired =>
            AuthSessionDataTerminationReason.expired,
          SignOutReason.sessionMissing =>
            AuthSessionDataTerminationReason.revoked,
          _ => AuthSessionDataTerminationReason.signedOut,
        },
      ),
      AuthChangeEvent.signedIn ||
      AuthChangeEvent.tokenRefreshed ||
      AuthChangeEvent.userUpdated ||
      AuthChangeEvent.passwordRecovery ||
      AuthChangeEvent.mfaChallengeVerified => _eventRecord(state.session),
      _ => null,
    };
  }

  AuthSessionDataEvent _eventRecord(Session? session) {
    if (session == null) {
      return const AuthSessionDataEventFailed(
        AuthSessionDataFailureKind.invalidPayload,
      );
    }
    return AuthSessionDataEstablished(
      AuthSessionRecord(userId: session.user.id),
    );
  }

  AuthSessionDataResult _record(Session session) {
    return AuthSessionDataAvailable(AuthSessionRecord(userId: session.user.id));
  }

  AuthSessionDataFailureKind _mapFailure(AuthException error) {
    if (error is AuthRetryableFetchException) {
      return AuthSessionDataFailureKind.temporarilyUnavailable;
    }
    if (error is AuthSessionMissingException ||
        error.code == ErrorCode.sessionExpired.code ||
        error.code == ErrorCode.sessionMissing.code) {
      return AuthSessionDataFailureKind.sessionExpired;
    }
    if (error.code == ErrorCode.sessionNotFound.code ||
        error.code == ErrorCode.userNotFound.code ||
        error.code == ErrorCode.userBanned.code ||
        error.code == ErrorCode.badJwt.code ||
        error.statusCode == '401') {
      return AuthSessionDataFailureKind.sessionRevoked;
    }
    return AuthSessionDataFailureKind.unknown;
  }
}
