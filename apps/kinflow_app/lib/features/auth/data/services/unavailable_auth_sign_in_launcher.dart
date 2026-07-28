import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';

final class UnavailableAuthSignInLauncher implements AuthSignInLauncher {
  const UnavailableAuthSignInLauncher();

  @override
  bool get isAvailable => false;

  @override
  Future<AuthSignInRequestResult> requestSignIn() async {
    return const AuthSignInRequestFailed(
      AuthFailure(AuthFailureKind.providerUnavailable),
    );
  }
}
