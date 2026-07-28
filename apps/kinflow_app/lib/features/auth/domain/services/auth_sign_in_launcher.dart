import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';

abstract interface class AuthSignInLauncher {
  bool get isAvailable;

  Future<AuthSignInRequestResult> requestSignIn();
}

sealed class AuthSignInRequestResult {
  const AuthSignInRequestResult();
}

final class AuthSignInRequestStarted extends AuthSignInRequestResult {
  const AuthSignInRequestStarted();
}

final class AuthSignInRequestCancelled extends AuthSignInRequestResult {
  const AuthSignInRequestCancelled();
}

final class AuthSignInRequestFailed extends AuthSignInRequestResult {
  const AuthSignInRequestFailed(this.failure);

  final AuthFailure failure;
}
