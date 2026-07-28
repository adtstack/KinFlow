import 'dart:async';

import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/domain/entities/auth_session.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/household/domain/failures/household_failure.dart';
import 'package:kinflow_app/features/household/domain/repositories/household_repository.dart';

final class AuthLifecycleController {
  factory AuthLifecycleController({
    required AuthSessionRepository repository,
    required AuthSignInLauncher signInLauncher,
    required SensitiveLocalStatePurger localStatePurger,
    required HouseholdRepository householdRepository,
  }) {
    return AuthLifecycleController._(
      repository,
      signInLauncher,
      localStatePurger,
      householdRepository,
    );
  }

  AuthLifecycleController._(
    this._repository,
    this._signInLauncher,
    this._localStatePurger,
    this._householdRepository,
  );

  final AuthSessionRepository _repository;
  final AuthSignInLauncher _signInLauncher;
  final SensitiveLocalStatePurger _localStatePurger;
  final HouseholdRepository _householdRepository;
  final StreamController<AuthLifecycleState> _states =
      StreamController<AuthLifecycleState>.broadcast(sync: true);

  AuthLifecycleState _state = const AuthBootstrapping();
  StreamSubscription<AuthSessionEvent>? _sessionSubscription;
  Future<void> _pendingOperation = Future<void>.value();
  AuthUserId? _currentUserId;
  var _providerEventRevision = 0;
  var _started = false;
  var _disposed = false;

  AuthLifecycleState get state => _state;

  Stream<AuthLifecycleState> get states => _states.stream;

  bool get isSignInAvailable => _signInLauncher.isAvailable;

  bool get canRequestSignIn {
    if (!isSignInAvailable || _state is AuthAuthenticating) {
      return false;
    }
    if (_state is AuthLocked &&
        _state.failure?.kind == AuthFailureKind.localPurgeFailed) {
      return false;
    }
    return _state is AuthUnauthenticated || _state is AuthLocked;
  }

  Future<void> start() {
    if (_started || _disposed) {
      return _pendingOperation;
    }
    _started = true;
    _sessionSubscription = _repository.sessionEvents.listen(
      (AuthSessionEvent event) {
        _providerEventRevision += 1;
        unawaited(_enqueue(() => _handleSessionEvent(event)));
      },
      onError: (Object error, StackTrace stackTrace) {
        _providerEventRevision += 1;
        unawaited(
          _enqueue(
            () => _handleSessionEvent(
              const AuthSessionEventFailed(
                AuthFailure(AuthFailureKind.temporarilyUnavailable),
              ),
            ),
          ),
        );
      },
    );
    final int restoreRevision = _providerEventRevision;

    return _enqueue(() async {
      final AuthSessionResult result = await _restoreSafely();
      if (restoreRevision != _providerEventRevision) {
        return;
      }
      await _applySessionResult(result, fromRefresh: false);
    });
  }

  Future<void> requestSignIn() {
    return _enqueue(() async {
      if (!canRequestSignIn) {
        if (!isSignInAvailable && _state is AuthUnauthenticated) {
          _emit(
            const AuthUnauthenticated(
              failure: AuthFailure(AuthFailureKind.providerUnavailable),
            ),
          );
        }
        return;
      }

      _emit(const AuthAuthenticating());
      final AuthSignInRequestResult result = await _requestSignInSafely();
      switch (result) {
        case AuthSignInRequestStarted():
          return;
        case AuthSignInRequestCancelled():
          _emit(const AuthUnauthenticated());
        case AuthSignInRequestFailed(:final failure):
          _emit(AuthUnauthenticated(failure: failure));
      }
    });
  }

  Future<void> refresh() {
    return _enqueue(() async {
      final AuthSession? session = _state.session;
      if (session == null || !_state.permitsProtectedRoutes) {
        return;
      }

      _emit(AuthRefreshing(session, activeHousehold: _state.activeHousehold));
      final AuthSessionResult result = await _refreshSafely();
      await _applySessionResult(result, fromRefresh: true);
    });
  }

  Future<void> logout() {
    return _enqueue(() async {
      _emit(const AuthLocked());
      final AuthSignOutResult signOutResult = await _signOutSafely();
      final bool purged = await _purgeLocalState();
      if (!purged) {
        return;
      }

      _currentUserId = null;
      final AuthFailure? failure = switch (signOutResult) {
        AuthSignOutCompleted() => null,
        AuthSignOutFailed(:final failure) => failure,
      };
      _emit(AuthUnauthenticated(failure: failure));
    });
  }

  Future<void> markActiveHousehold(ActiveHousehold household) {
    return _enqueue(() async {
      final AuthSession? session = _state.session;
      if (session == null || _currentUserId != session.userId) {
        return;
      }
      _emit(AuthAuthenticatedActiveHousehold(session, household));
    });
  }

  Future<void> retryHouseholdResolution() {
    return _enqueue(() async {
      final AuthLifecycleState current = _state;
      if (current is! AuthHouseholdResolutionFailed ||
          _currentUserId != current.session.userId) {
        return;
      }
      await _resolveActiveHousehold(current.session);
    });
  }

  Future<void> waitForPendingOperations() async {
    while (true) {
      final Future<void> pending = _pendingOperation;
      await pending;
      if (identical(pending, _pendingOperation)) {
        return;
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _sessionSubscription?.cancel();
    await _pendingOperation;
    await _states.close();
  }

  Future<void> _handleSessionEvent(AuthSessionEvent event) async {
    switch (event) {
      case AuthSessionEstablished(:final session):
        await _establishSession(session);
      case AuthSessionTerminated(:final reason):
        await _terminateSession(reason);
      case AuthSessionEventFailed(:final failure):
        await _handleProviderFailure(failure);
    }
  }

  Future<void> _applySessionResult(
    AuthSessionResult result, {
    required bool fromRefresh,
  }) async {
    switch (result) {
      case AuthSessionAvailable(:final session):
        await _establishSession(session);
      case AuthSessionAbsent():
        await _clearSession(
          target: const AuthUnauthenticated(),
          skipIfAlreadyClear: fromRefresh,
        );
      case AuthSessionFailed(:final failure):
        if (failure.kind == AuthFailureKind.temporarilyUnavailable ||
            failure.kind == AuthFailureKind.providerUnavailable ||
            failure.kind == AuthFailureKind.internal) {
          await _clearSession(
            target: AuthLocked(failure: failure),
            skipIfAlreadyClear: false,
          );
          return;
        }
        await _clearSession(
          target: AuthUnauthenticated(failure: failure),
          skipIfAlreadyClear: false,
        );
    }
  }

  Future<void> _establishSession(AuthSession session) async {
    final AuthUserId? previousUserId = _currentUserId;
    if (previousUserId != null && previousUserId != session.userId) {
      _emit(const AuthLocked());
      final bool purged = await _purgeLocalState();
      if (!purged) {
        return;
      }
    }

    _currentUserId = session.userId;
    await _resolveActiveHousehold(session);
  }

  Future<void> _resolveActiveHousehold(AuthSession session) async {
    _emit(AuthResolvingHousehold(session));
    final LoadActiveHouseholdResult result = await _loadHouseholdSafely();
    switch (result) {
      case ActiveHouseholdLoaded(:final household):
        _emit(AuthAuthenticatedActiveHousehold(session, household));
      case NoActiveHousehold():
        _emit(AuthAuthenticatedNoHousehold(session));
      case LoadActiveHouseholdFailed(:final failure):
        _emit(AuthHouseholdResolutionFailed(session, failure));
    }
  }

  Future<void> _terminateSession(AuthSessionTerminationReason reason) async {
    final AuthFailure? failure = switch (reason) {
      AuthSessionTerminationReason.signedOut => null,
      AuthSessionTerminationReason.expired => const AuthFailure(
        AuthFailureKind.sessionExpired,
      ),
      AuthSessionTerminationReason.revoked => const AuthFailure(
        AuthFailureKind.sessionRevoked,
      ),
    };

    if (_currentUserId == null && _state is AuthUnauthenticated) {
      if (failure != null) {
        _emit(AuthUnauthenticated(failure: failure));
      }
      return;
    }
    await _clearSession(
      target: AuthUnauthenticated(failure: failure),
      skipIfAlreadyClear: false,
    );
  }

  Future<void> _handleProviderFailure(AuthFailure failure) async {
    await _clearSession(
      target: AuthLocked(failure: failure),
      skipIfAlreadyClear: false,
    );
  }

  Future<void> _clearSession({
    required AuthLifecycleState target,
    required bool skipIfAlreadyClear,
  }) async {
    if (skipIfAlreadyClear && _currentUserId == null) {
      _emit(target);
      return;
    }

    _emit(AuthLocked(failure: target.failure));
    final bool purged = await _purgeLocalState();
    if (!purged) {
      return;
    }
    _currentUserId = null;
    _emit(target);
  }

  Future<bool> _purgeLocalState() async {
    final SensitiveLocalStatePurgeResult result;
    try {
      result = await _localStatePurger.purge();
    } on Object {
      _emit(
        const AuthLocked(
          failure: AuthFailure(AuthFailureKind.localPurgeFailed),
        ),
      );
      return false;
    }

    if (result is SensitiveLocalStatePurgeFailed) {
      _emit(
        const AuthLocked(
          failure: AuthFailure(AuthFailureKind.localPurgeFailed),
        ),
      );
      return false;
    }
    return true;
  }

  Future<AuthSessionResult> _restoreSafely() async {
    try {
      return await _repository.restoreSession();
    } on Object {
      return const AuthSessionFailed(AuthFailure(AuthFailureKind.internal));
    }
  }

  Future<AuthSessionResult> _refreshSafely() async {
    try {
      return await _repository.refreshSession();
    } on Object {
      return const AuthSessionFailed(AuthFailure(AuthFailureKind.internal));
    }
  }

  Future<LoadActiveHouseholdResult> _loadHouseholdSafely() async {
    try {
      return await _householdRepository.loadActiveHousehold();
    } on Object {
      return const LoadActiveHouseholdFailed(
        HouseholdFailure(HouseholdFailureKind.internal),
      );
    }
  }

  Future<AuthSignOutResult> _signOutSafely() async {
    try {
      return await _repository.signOut();
    } on Object {
      return const AuthSignOutFailed(AuthFailure(AuthFailureKind.internal));
    }
  }

  Future<AuthSignInRequestResult> _requestSignInSafely() async {
    try {
      return await _signInLauncher.requestSignIn();
    } on Object {
      return const AuthSignInRequestFailed(
        AuthFailure(AuthFailureKind.internal),
      );
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> next = _pendingOperation.then((_) async {
      if (_disposed) {
        return;
      }
      try {
        await operation();
      } on Object {
        _emit(const AuthLocked(failure: AuthFailure(AuthFailureKind.internal)));
      }
    });
    _pendingOperation = next;
    return next;
  }

  void _emit(AuthLifecycleState nextState) {
    if (_disposed) {
      return;
    }
    _state = nextState;
    _states.add(nextState);
  }
}
