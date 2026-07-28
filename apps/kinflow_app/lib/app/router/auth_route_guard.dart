import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';

final class AuthRouteGuard {
  AuthRouteGuard({
    required this.authLoadingPath,
    required this.householdOnboardingPath,
    required this.invitePath,
    required this.rootPath,
    required this.signInPath,
    required this.todayPath,
  });

  final String authLoadingPath;
  final String householdOnboardingPath;
  final String invitePath;
  final String rootPath;
  final String signInPath;
  final String todayPath;

  String? _intendedPath;

  String? redirect(AuthLifecycleState authState, Uri location) {
    final String currentPath = location.path;
    final bool isAuthLoading = currentPath == authLoadingPath;
    final bool isSignIn = currentPath == signInPath;
    final bool isHouseholdOnboarding = currentPath == householdOnboardingPath;
    final bool isInvite =
        currentPath == invitePath || currentPath.startsWith('$invitePath/');
    final bool isRoot = currentPath == rootPath;
    final bool isPublicAuthPath = isAuthLoading || isSignIn;

    if (isSignIn && location.queryParameters['continue'] == 'invite') {
      _intendedPath = invitePath;
    }

    if (authState is AuthBootstrapping ||
        authState is AuthResolvingHousehold ||
        authState is AuthHouseholdResolutionFailed) {
      if (isInvite) {
        return null;
      }
      if (!isPublicAuthPath && !isHouseholdOnboarding) {
        _rememberIntendedPath(location);
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
      if (!isPublicAuthPath && !isHouseholdOnboarding && !isRoot) {
        return null;
      }
      final String target = _intendedPath ?? todayPath;
      _intendedPath = null;
      return target == currentPath ? null : target;
    }

    final bool needsFirstHousehold =
        authState is AuthAuthenticatedNoHousehold ||
        authState is AuthRefreshing;
    if (needsFirstHousehold) {
      if (isInvite) {
        return null;
      }
      if (_intendedPath == invitePath) {
        _intendedPath = null;
        return invitePath;
      }
      _intendedPath = null;
      return isHouseholdOnboarding ? null : householdOnboardingPath;
    }

    if (isInvite) {
      return null;
    }
    if (!isPublicAuthPath && !isHouseholdOnboarding) {
      _rememberIntendedPath(location);
      return signInPath;
    }
    if (isAuthLoading) {
      return signInPath;
    }
    return null;
  }

  void _rememberIntendedPath(Uri location) {
    final String path = location.path;
    if (path.isEmpty ||
        !path.startsWith('/') ||
        path.startsWith('//') ||
        path.contains(r'\') ||
        path.length > 512 ||
        path == authLoadingPath ||
        path == signInPath ||
        path == householdOnboardingPath ||
        path == invitePath ||
        path.startsWith('$invitePath/') ||
        path == rootPath) {
      _intendedPath = todayPath;
      return;
    }
    _intendedPath = path;
  }
}
