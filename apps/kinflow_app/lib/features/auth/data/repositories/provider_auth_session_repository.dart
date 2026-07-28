import 'package:kinflow_app/features/auth/data/datasources/auth_session_data_source.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';

final class ProviderAuthSessionRepository implements AuthSessionRepository {
  const ProviderAuthSessionRepository(this._dataSource);

  final AuthSessionDataSource _dataSource;

  @override
  Stream<AuthSessionEvent> get sessionEvents {
    return _dataSource.sessionEvents.map(_mapEvent);
  }

  @override
  Future<AuthSessionResult> restoreSession() async {
    return _mapResult(await _dataSource.restoreSession());
  }

  @override
  Future<AuthSessionResult> refreshSession() async {
    return _mapResult(await _dataSource.refreshSession());
  }

  @override
  Future<AuthSignOutResult> signOut() async {
    final AuthSignOutDataResult result = await _dataSource.signOut();
    return switch (result) {
      AuthSignOutDataCompleted() => const AuthSignOutCompleted(),
      AuthSignOutDataFailed(:final kind) => AuthSignOutFailed(
        _mapFailure(kind),
      ),
    };
  }

  AuthSessionResult _mapResult(AuthSessionDataResult result) {
    return switch (result) {
      AuthSessionDataAvailable(:final record) => _mapRecord(record),
      AuthSessionDataAbsent() => const AuthSessionAbsent(),
      AuthSessionDataFailed(:final kind) => AuthSessionFailed(
        _mapFailure(kind),
      ),
    };
  }

  AuthSessionResult _mapRecord(AuthSessionRecord record) {
    final AuthUserId? userId = AuthUserId.tryParse(record.userId);
    if (userId == null) {
      return const AuthSessionFailed(
        AuthFailure(AuthFailureKind.invalidSession),
      );
    }
    return AuthSessionAvailable(AuthSession(userId: userId));
  }

  AuthSessionEvent _mapEventRecord(AuthSessionRecord record) {
    final AuthSessionResult result = _mapRecord(record);
    return switch (result) {
      AuthSessionAvailable(:final session) => AuthSessionEstablished(session),
      AuthSessionAbsent() => const AuthSessionEventFailed(
        AuthFailure(AuthFailureKind.invalidSession),
      ),
      AuthSessionFailed(:final failure) => AuthSessionEventFailed(failure),
    };
  }

  AuthSessionEvent _mapEvent(AuthSessionDataEvent event) {
    return switch (event) {
      AuthSessionDataEstablished(:final record) => _mapEventRecord(record),
      AuthSessionDataTerminated(:final reason) => AuthSessionTerminated(
        switch (reason) {
          AuthSessionDataTerminationReason.signedOut =>
            AuthSessionTerminationReason.signedOut,
          AuthSessionDataTerminationReason.expired =>
            AuthSessionTerminationReason.expired,
          AuthSessionDataTerminationReason.revoked =>
            AuthSessionTerminationReason.revoked,
        },
      ),
      AuthSessionDataEventFailed(:final kind) => AuthSessionEventFailed(
        _mapFailure(kind),
      ),
    };
  }

  AuthFailure _mapFailure(AuthSessionDataFailureKind kind) {
    return AuthFailure(switch (kind) {
      AuthSessionDataFailureKind.temporarilyUnavailable =>
        AuthFailureKind.temporarilyUnavailable,
      AuthSessionDataFailureKind.sessionExpired =>
        AuthFailureKind.sessionExpired,
      AuthSessionDataFailureKind.sessionRevoked =>
        AuthFailureKind.sessionRevoked,
      AuthSessionDataFailureKind.invalidPayload =>
        AuthFailureKind.invalidSession,
      AuthSessionDataFailureKind.unknown => AuthFailureKind.internal,
    });
  }
}
