import 'package:kinflow_app/features/auth/data/datasources/auth_sign_in_data_source.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';

final class ProviderAuthSignInLauncher implements AuthSignInLauncher {
  const ProviderAuthSignInLauncher(this._dataSource);

  final AuthSignInDataSource _dataSource;

  @override
  bool get isAvailable => _dataSource.isAvailable;

  @override
  Future<AuthSignInRequestResult> requestSignIn() async {
    final AuthSignInDataResult result = await _dataSource.requestGoogleSignIn();
    return switch (result) {
      AuthSignInDataCompleted() => const AuthSignInRequestStarted(),
      AuthSignInDataCancelled() => const AuthSignInRequestCancelled(),
      AuthSignInDataFailed(:final kind) => AuthSignInRequestFailed(
        AuthFailure(_failureKind(kind)),
      ),
    };
  }

  AuthFailureKind _failureKind(AuthSignInDataFailureKind kind) {
    return switch (kind) {
      AuthSignInDataFailureKind.providerUnavailable =>
        AuthFailureKind.providerUnavailable,
      AuthSignInDataFailureKind.temporarilyUnavailable =>
        AuthFailureKind.temporarilyUnavailable,
      AuthSignInDataFailureKind.identityConflict =>
        AuthFailureKind.identityConflict,
      AuthSignInDataFailureKind.invalidPayload ||
      AuthSignInDataFailureKind.unknown => AuthFailureKind.internal,
    };
  }
}
