import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';

final class AuthRouteGuard {
  AuthRouteGuard({
    required this.authLoadingPath,
    required this.homePath,
    required this.signInPath,
  });

  final String authLoadingPath;
  final String homePath;
  final String signInPath;

  String? _intendedPath;

  String? redirect(AuthLifecycleState authState, Uri location) {
    final String currentPath = location.path;
    final bool isAuthLoading = currentPath == authLoadingPath;
    final bool isSignIn = currentPath == signInPath;
    final bool isPublicAuthPath = isAuthLoading || isSignIn;

    if (authState is AuthBootstrapping) {
      if (!isPublicAuthPath) {
        _rememberIntendedPath(location);
      }
      return isAuthLoading ? null : authLoadingPath;
    }

    if (authState.permitsProtectedRoutes) {
      if (!isPublicAuthPath) {
        return null;
      }
      final String target = _intendedPath ?? homePath;
      _intendedPath = null;
      return target == currentPath ? null : target;
    }

    if (!isPublicAuthPath) {
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
        path == signInPath) {
      _intendedPath = homePath;
      return;
    }
    _intendedPath = path;
  }
}
