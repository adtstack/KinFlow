import 'dart:async';

import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';

final class FakeAuthSessionRepository implements AuthSessionRepository {
  FakeAuthSessionRepository({
    this.restoreCallback,
    this.restoreResult = const AuthSessionAbsent(),
    List<AuthSessionResult> refreshResults = const <AuthSessionResult>[],
    List<AuthSignOutResult> signOutResults = const <AuthSignOutResult>[],
  }) : _refreshResults = List<AuthSessionResult>.of(refreshResults),
       _signOutResults = List<AuthSignOutResult>.of(signOutResults);

  final Future<AuthSessionResult> Function()? restoreCallback;
  final AuthSessionResult restoreResult;
  final List<AuthSessionResult> _refreshResults;
  final List<AuthSignOutResult> _signOutResults;
  final StreamController<AuthSessionEvent> _events =
      StreamController<AuthSessionEvent>.broadcast(sync: true);

  var restoreCount = 0;
  var refreshCount = 0;
  var signOutCount = 0;

  @override
  Stream<AuthSessionEvent> get sessionEvents => _events.stream;

  @override
  Future<AuthSessionResult> restoreSession() async {
    restoreCount += 1;
    final Future<AuthSessionResult> Function()? callback = restoreCallback;
    return callback == null ? restoreResult : callback();
  }

  @override
  Future<AuthSessionResult> refreshSession() async {
    refreshCount += 1;
    if (_refreshResults.isEmpty) {
      return const AuthSessionAbsent();
    }
    return _refreshResults.removeAt(0);
  }

  @override
  Future<AuthSignOutResult> signOut() async {
    signOutCount += 1;
    if (_signOutResults.isEmpty) {
      return const AuthSignOutCompleted();
    }
    return _signOutResults.removeAt(0);
  }

  void emit(AuthSessionEvent event) {
    _events.add(event);
  }

  Future<void> close() {
    return _events.close();
  }
}

final class FakeAuthSignInLauncher implements AuthSignInLauncher {
  FakeAuthSignInLauncher({
    this.isAvailable = true,
    List<AuthSignInRequestResult> results = const <AuthSignInRequestResult>[],
  }) : _results = List<AuthSignInRequestResult>.of(results);

  @override
  final bool isAvailable;

  final List<AuthSignInRequestResult> _results;
  var requestCount = 0;

  @override
  Future<AuthSignInRequestResult> requestSignIn() async {
    requestCount += 1;
    if (_results.isEmpty) {
      return const AuthSignInRequestStarted();
    }
    return _results.removeAt(0);
  }
}

final class RecordingSensitiveLocalStatePurger
    implements SensitiveLocalStatePurger {
  RecordingSensitiveLocalStatePurger({
    List<FutureOr<SensitiveLocalStatePurgeResult> Function()> results =
        const <FutureOr<SensitiveLocalStatePurgeResult> Function()>[],
  }) : _results = List<FutureOr<SensitiveLocalStatePurgeResult> Function()>.of(
         results,
       );

  final List<FutureOr<SensitiveLocalStatePurgeResult> Function()> _results;
  var purgeCount = 0;

  @override
  Future<SensitiveLocalStatePurgeResult> purge() async {
    purgeCount += 1;
    if (_results.isEmpty) {
      return const SensitiveLocalStatePurged();
    }
    return _results.removeAt(0)();
  }
}

AuthSession authSessionFixture({
  String userId = '11111111-1111-4111-8111-111111111111',
}) {
  final AuthUserId? parsedUserId = AuthUserId.tryParse(userId);
  if (parsedUserId == null) {
    throw StateError('Static auth user fixture must be a UUID.');
  }
  return AuthSession(userId: parsedUserId);
}
