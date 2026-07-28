import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/auth/data/repositories/unavailable_auth_session_repository.dart';
import 'package:kinflow_app/features/auth/data/services/unavailable_auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/repositories/auth_session_repository.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';

AuthSessionRepository createAuthSessionRepository() {
  return const UnavailableAuthSessionRepository();
}

AuthSignInLauncher createAuthSignInLauncher() {
  return const UnavailableAuthSignInLauncher();
}

SensitiveLocalStatePurger createSensitiveLocalStatePurger() {
  return CompositeSensitiveLocalStatePurger(
    const <SensitiveLocalStatePurgeParticipant>[],
  );
}
