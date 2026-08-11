import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';

typedef AuthRouteIntentResolver = AuthRouteIntent? Function(Uri location);
typedef AuthRouteContinuationResolver =
    AuthRouteIntent? Function(String continuationMarker);

final class AuthRouteIntent {
  const AuthRouteIntent({
    required this.location,
    required this.continuationMarker,
    this.canonicalizeWhenAuthenticated = true,
  });

  final Uri location;
  final String continuationMarker;
  final bool canonicalizeWhenAuthenticated;
}

final class AuthRouteGuard {
  AuthRouteGuard({
    required this.authLoadingPath,
    required this.guidedChoreSetupPath,
    required this.householdOnboardingPath,
    required this.invitePath,
    required this.rootPath,
    required this.settingsPath,
    required this.signInPath,
    required this.todayPath,
    required this.intentResolver,
    required this.continuationResolver,
  });

  final String authLoadingPath;
  final String guidedChoreSetupPath;
  final String householdOnboardingPath;
  final String invitePath;
  final String rootPath;
  final String settingsPath;
  final String signInPath;
  final String todayPath;
  final AuthRouteIntentResolver intentResolver;
  final AuthRouteContinuationResolver continuationResolver;

  AuthRouteIntent? _intendedRoute;
  AuthUserId? _recoverableUserId;
  bool _requiresSafeRoutingBoundary = false;

  /// Invalidates route state when authentication identity or household scope
  /// changes. Session expiry/revocation is the only transition that may retain
  /// the current protected destination for a same-user re-authentication.
  void handleAuthStateTransition(
    AuthLifecycleState? previous,
    AuthLifecycleState next,
  ) {
    if (previous == null) {
      return;
    }
    if (_isRecoverableSessionLoss(previous, next)) {
      _recoverableUserId = previous.session?.userId;
      return;
    }

    final bool leftProtectedSession =
        previous.permitsProtectedRoutes && !next.permitsProtectedRoutes;
    final bool lostAuthenticatedIdentity =
        previous.session != null && next.session == null;
    final bool userChanged =
        previous.session != null &&
        next.session != null &&
        previous.session!.userId != next.session!.userId;
    final bool recoveryUserChanged =
        _recoverableUserId != null &&
        next.session != null &&
        _recoverableUserId != next.session!.userId;
    final bool householdChanged =
        previous.activeHousehold != null &&
        next.activeHousehold != null &&
        previous.activeHousehold!.householdId !=
            next.activeHousehold!.householdId;

    if (leftProtectedSession ||
        lostAuthenticatedIdentity ||
        userChanged ||
        recoveryUserChanged ||
        householdChanged) {
      _intendedRoute = null;
      _recoverableUserId = null;
      _requiresSafeRoutingBoundary = true;
      return;
    }
    if (_recoverableUserId == next.session?.userId) {
      _recoverableUserId = null;
    }
  }

  String? redirect(AuthLifecycleState authState, Uri location) {
    final String currentPath = location.path;
    final bool isAuthLoading = currentPath == authLoadingPath;
    final bool isGuidedChoreSetup = currentPath == guidedChoreSetupPath;
    final bool isSignIn = currentPath == signInPath;
    final bool isHouseholdOnboarding = currentPath == householdOnboardingPath;
    final bool isInvite =
        currentPath == invitePath || currentPath.startsWith('$invitePath/');
    final bool isRoot = currentPath == rootPath;
    final bool isSettings = _isSettingsPath(currentPath);
    final bool isPublicAuthPath = isAuthLoading || isSignIn;

    if (isSignIn) {
      // Keep the boundary armed while an explicit logout/account transition
      // is still locked. GoRouter may evaluate a redirect chain before the
      // browser location commits; clearing it here would let the old route be
      // captured by the following unauthenticated state.
      if (authState is AuthUnauthenticated) {
        _requiresSafeRoutingBoundary = false;
        if (!location.queryParametersAll.containsKey('continue')) {
          _intendedRoute = null;
          _recoverableUserId = null;
        }
      }
      _restoreContinuation(location);
    }

    if (authState is AuthBootstrapping ||
        authState is AuthResolvingHousehold ||
        authState is AuthHouseholdResolutionFailed) {
      if (isInvite) {
        return null;
      }
      if (!isPublicAuthPath && !isHouseholdOnboarding) {
        _rememberIntendedRoute(location);
      }
      return isAuthLoading ? null : authLoadingPath;
    }

    final bool hasActiveHousehold =
        authState is AuthAuthenticatedActiveHousehold ||
        authState is AuthRefreshing && authState.activeHousehold != null;
    if (hasActiveHousehold) {
      if (isInvite) {
        return null;
      }
      if (_requiresSafeRoutingBoundary) {
        _requiresSafeRoutingBoundary = false;
        _intendedRoute = null;
        return currentPath == todayPath ? null : todayPath;
      }
      if (!isPublicAuthPath && !isHouseholdOnboarding && !isRoot) {
        final AuthRouteIntent? canonical = _validated(intentResolver(location));
        if (canonical != null &&
            canonical.canonicalizeWhenAuthenticated &&
            canonical.location.toString() != location.toString()) {
          return canonical.location.toString();
        }
      }
      if (isGuidedChoreSetup) {
        return null;
      }
      if (!isPublicAuthPath && !isHouseholdOnboarding && !isRoot) {
        return null;
      }
      final String target = _intendedRoute?.location.toString() ?? todayPath;
      _intendedRoute = null;
      return target == location.toString() ? null : target;
    }

    final bool needsFirstHousehold =
        authState is AuthAuthenticatedNoHousehold ||
        authState is AuthRefreshing;
    if (needsFirstHousehold) {
      if (isInvite) {
        return null;
      }
      _requiresSafeRoutingBoundary = false;
      if (isSettings) {
        _intendedRoute = null;
        return null;
      }
      if (_intendedRoute?.location.path == invitePath) {
        _intendedRoute = null;
        return invitePath;
      }
      if (_intendedRoute case final AuthRouteIntent intended
          when _isSettingsPath(intended.location.path)) {
        _intendedRoute = null;
        return intended.location.toString();
      }
      _intendedRoute = null;
      return isHouseholdOnboarding ? null : householdOnboardingPath;
    }

    if (isInvite) {
      return null;
    }
    if (isHouseholdOnboarding) {
      return signInPath;
    }
    if (!isPublicAuthPath) {
      _rememberIntendedRoute(location);
      return _signInLocation();
    }
    if (isAuthLoading) {
      return _signInLocation();
    }
    return null;
  }

  void _rememberIntendedRoute(Uri location) {
    if (_requiresSafeRoutingBoundary) {
      return;
    }
    _intendedRoute = _validated(intentResolver(location));
  }

  void _restoreContinuation(Uri location) {
    final List<String>? values = location.queryParametersAll['continue'];
    if (values == null) {
      return;
    }
    if (values.length != 1) {
      _intendedRoute = null;
      return;
    }

    final String marker = values.single;
    if (marker == 'invite') {
      _intendedRoute = AuthRouteIntent(
        location: Uri(path: invitePath),
        continuationMarker: marker,
      );
      return;
    }

    final AuthRouteIntent? restored = _validated(continuationResolver(marker));
    if (restored == null) {
      _intendedRoute = null;
      return;
    }
    if (_intendedRoute?.continuationMarker != marker) {
      _intendedRoute = restored;
    }
  }

  AuthRouteIntent? _validated(AuthRouteIntent? intent) {
    if (intent == null) {
      return null;
    }
    final Uri location = intent.location;
    final String path = location.path;
    final String marker = intent.continuationMarker;
    if (location.hasScheme ||
        location.hasAuthority ||
        location.hasFragment ||
        path.isEmpty ||
        !path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains(r'\') ||
        location.toString().length > 768 ||
        !_continuationMarkerPattern.hasMatch(marker)) {
      return null;
    }
    return intent;
  }

  String _signInLocation() {
    final String? marker = _intendedRoute?.continuationMarker;
    return marker == null
        ? signInPath
        : Uri(
            path: signInPath,
            queryParameters: <String, String>{'continue': marker},
          ).toString();
  }

  bool _isRecoverableSessionLoss(
    AuthLifecycleState previous,
    AuthLifecycleState next,
  ) {
    if (!previous.permitsProtectedRoutes) {
      return false;
    }
    return switch (next.failure?.kind) {
      AuthFailureKind.sessionExpired || AuthFailureKind.sessionRevoked => true,
      _ => false,
    };
  }

  bool _isSettingsPath(String path) {
    return path == settingsPath || path.startsWith('$settingsPath/');
  }

  static final RegExp _continuationMarkerPattern = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]{0,30}[a-z0-9])?$',
  );
}
