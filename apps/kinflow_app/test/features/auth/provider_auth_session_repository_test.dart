import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/data/datasources/auth_session_data_source.dart';
import 'package:kinflow_app/features/auth/data/repositories/provider_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';

void main() {
  group('ProviderAuthSessionRepository', () {
    test('maps a provider record to an opaque domain session', () async {
      final _FakeAuthSessionDataSource dataSource = _FakeAuthSessionDataSource(
        restoreResult: const AuthSessionDataAvailable(
          AuthSessionRecord(userId: '11111111-1111-4111-8111-111111111111'),
        ),
      );
      final ProviderAuthSessionRepository repository =
          ProviderAuthSessionRepository(dataSource);
      addTearDown(dataSource.close);

      final AuthSessionResult result = await repository.restoreSession();

      expect(result, isA<AuthSessionAvailable>());
      expect(
        (result as AuthSessionAvailable).session.userId.toString(),
        'AuthUserId(<redacted>)',
      );
    });

    test('rejects an invalid provider user identifier', () async {
      final _FakeAuthSessionDataSource dataSource = _FakeAuthSessionDataSource(
        restoreResult: const AuthSessionDataAvailable(
          AuthSessionRecord(userId: 'raw-provider-identity'),
        ),
      );
      final ProviderAuthSessionRepository repository =
          ProviderAuthSessionRepository(dataSource);
      addTearDown(dataSource.close);

      final AuthSessionResult result = await repository.restoreSession();

      expect(result, isA<AuthSessionFailed>());
      expect(
        (result as AuthSessionFailed).failure.kind,
        AuthFailureKind.invalidSession,
      );
    });

    test('maps refresh failures to stable domain failures', () async {
      final _FakeAuthSessionDataSource dataSource = _FakeAuthSessionDataSource(
        refreshResult: const AuthSessionDataFailed(
          AuthSessionDataFailureKind.sessionExpired,
        ),
      );
      final ProviderAuthSessionRepository repository =
          ProviderAuthSessionRepository(dataSource);
      addTearDown(dataSource.close);

      final AuthSessionResult result = await repository.refreshSession();

      expect(result, isA<AuthSessionFailed>());
      expect((result as AuthSessionFailed).failure.code, 'SESSION_EXPIRED');
    });

    test('maps provider events and failures without payload details', () async {
      final _FakeAuthSessionDataSource dataSource =
          _FakeAuthSessionDataSource();
      final ProviderAuthSessionRepository repository =
          ProviderAuthSessionRepository(dataSource);
      final List<AuthSessionEvent> events = <AuthSessionEvent>[];
      final StreamSubscription<AuthSessionEvent> subscription = repository
          .sessionEvents
          .listen(events.add);
      addTearDown(() async {
        await subscription.cancel();
        await dataSource.close();
      });
      await Future<void>.delayed(Duration.zero);

      dataSource.emit(
        const AuthSessionDataEstablished(
          AuthSessionRecord(userId: '22222222-2222-4222-8222-222222222222'),
        ),
      );
      dataSource.emit(
        const AuthSessionDataEventFailed(
          AuthSessionDataFailureKind.temporarilyUnavailable,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events.first, isA<AuthSessionEstablished>());
      expect(events.last, isA<AuthSessionEventFailed>());
      expect(
        (events.last as AuthSessionEventFailed).failure.code,
        'TEMPORARILY_UNAVAILABLE',
      );
    });

    test('maps revoked sign-out and typed sign-out failures', () async {
      final _FakeAuthSessionDataSource dataSource = _FakeAuthSessionDataSource(
        signOutResult: const AuthSignOutDataFailed(
          AuthSessionDataFailureKind.sessionRevoked,
        ),
      );
      final ProviderAuthSessionRepository repository =
          ProviderAuthSessionRepository(dataSource);
      addTearDown(dataSource.close);

      final AuthSignOutResult result = await repository.signOut();

      expect(result, isA<AuthSignOutFailed>());
      expect(
        (result as AuthSignOutFailed).failure.kind,
        AuthFailureKind.sessionRevoked,
      );
    });
  });
}

final class _FakeAuthSessionDataSource implements AuthSessionDataSource {
  _FakeAuthSessionDataSource({
    this.restoreResult = const AuthSessionDataAbsent(),
    this.refreshResult = const AuthSessionDataAbsent(),
    this.signOutResult = const AuthSignOutDataCompleted(),
  });

  final AuthSessionDataResult restoreResult;
  final AuthSessionDataResult refreshResult;
  final AuthSignOutDataResult signOutResult;
  final StreamController<AuthSessionDataEvent> _events =
      StreamController<AuthSessionDataEvent>.broadcast(sync: true);

  @override
  Stream<AuthSessionDataEvent> get sessionEvents => _events.stream;

  @override
  Future<AuthSessionDataResult> restoreSession() async => restoreResult;

  @override
  Future<AuthSessionDataResult> refreshSession() async => refreshResult;

  @override
  Future<AuthSignOutDataResult> signOut() async => signOutResult;

  void emit(AuthSessionDataEvent event) {
    _events.add(event);
  }

  Future<void> close() {
    return _events.close();
  }
}
