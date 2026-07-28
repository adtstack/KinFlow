import 'package:google_sign_in/google_sign_in.dart';

enum GoogleIdentityFailureKind {
  providerUnavailable,
  temporarilyUnavailable,
  invalidResponse,
  unknown,
}

final class GoogleIdentityTokens {
  const GoogleIdentityTokens({
    required this.idToken,
    required this.accessToken,
  });

  final String idToken;
  final String accessToken;

  @override
  String toString() => 'GoogleIdentityTokens(redacted)';
}

sealed class GoogleIdentityAuthenticationResult {
  const GoogleIdentityAuthenticationResult();
}

final class GoogleIdentityAuthenticated
    extends GoogleIdentityAuthenticationResult {
  const GoogleIdentityAuthenticated(this.tokens);

  final GoogleIdentityTokens tokens;
}

final class GoogleIdentityAuthenticationCancelled
    extends GoogleIdentityAuthenticationResult {
  const GoogleIdentityAuthenticationCancelled();
}

final class GoogleIdentityAuthenticationFailed
    extends GoogleIdentityAuthenticationResult {
  const GoogleIdentityAuthenticationFailed(this.kind);

  final GoogleIdentityFailureKind kind;
}

abstract interface class GoogleIdentityGateway {
  Future<GoogleIdentityAuthenticationResult> authenticate({
    required String serverClientId,
  });

  Future<void> signOut({required String serverClientId});
}

abstract interface class GoogleIdentitySdkDriver {
  Future<void> initialize({required String serverClientId});

  bool supportsAuthenticate();

  Future<GoogleIdentityAuthenticationResult> authenticate();

  Future<void> signOut();
}

/// Owns the process-wide Google Sign-In singleton. The plugin requires
/// initialization exactly once, so one gateway instance is shared by runtime
/// composition and enforces a single server client ID for the process.
final class GoogleSignInIdentityGateway implements GoogleIdentityGateway {
  GoogleSignInIdentityGateway._(this._driver);

  GoogleSignInIdentityGateway.withDriver(this._driver);

  static final GoogleSignInIdentityGateway instance =
      GoogleSignInIdentityGateway._(
        _GoogleSignInSdkDriver(GoogleSignIn.instance),
      );

  final GoogleIdentitySdkDriver _driver;
  String? _serverClientId;
  Future<void>? _initialization;

  @override
  Future<GoogleIdentityAuthenticationResult> authenticate({
    required String serverClientId,
  }) async {
    try {
      await _ensureInitialized(serverClientId);
      if (!_driver.supportsAuthenticate()) {
        return const GoogleIdentityAuthenticationFailed(
          GoogleIdentityFailureKind.providerUnavailable,
        );
      }
      return await _driver.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return const GoogleIdentityAuthenticationCancelled();
      }
      return GoogleIdentityAuthenticationFailed(
        googleIdentityFailureKindForExceptionCode(error.code),
      );
    } on UnsupportedError {
      return const GoogleIdentityAuthenticationFailed(
        GoogleIdentityFailureKind.providerUnavailable,
      );
    } on Object {
      return const GoogleIdentityAuthenticationFailed(
        GoogleIdentityFailureKind.unknown,
      );
    }
  }

  @override
  Future<void> signOut({required String serverClientId}) async {
    await _ensureInitialized(serverClientId);
    await _driver.signOut();
  }

  Future<void> _ensureInitialized(String serverClientId) {
    final String? configuredClientId = _serverClientId;
    if (configuredClientId != null && configuredClientId != serverClientId) {
      return Future<void>.error(
        StateError('Google identity already initialized for this process.'),
      );
    }
    _serverClientId ??= serverClientId;
    return _initialization ??= _driver.initialize(
      serverClientId: serverClientId,
    );
  }
}

final class _GoogleSignInSdkDriver implements GoogleIdentitySdkDriver {
  const _GoogleSignInSdkDriver(this._signIn);

  final GoogleSignIn _signIn;

  @override
  Future<void> initialize({required String serverClientId}) {
    return _signIn.initialize(serverClientId: serverClientId);
  }

  @override
  bool supportsAuthenticate() => _signIn.supportsAuthenticate();

  @override
  Future<GoogleIdentityAuthenticationResult> authenticate() async {
    final GoogleSignInAccount account = await _signIn.authenticate();
    final GoogleSignInAuthentication authentication = account.authentication;
    final GoogleSignInClientAuthorization? authorization = await account
        .authorizationClient
        .authorizationForScopes(const <String>[]);
    return googleIdentityAuthenticationFromTokens(
      idToken: authentication.idToken,
      accessToken: authorization?.accessToken,
    );
  }

  @override
  Future<void> signOut() => _signIn.signOut();
}

GoogleIdentityAuthenticationResult googleIdentityAuthenticationFromTokens({
  required String? idToken,
  required String? accessToken,
}) {
  if (idToken == null ||
      idToken.trim().isEmpty ||
      accessToken == null ||
      accessToken.trim().isEmpty) {
    return const GoogleIdentityAuthenticationFailed(
      GoogleIdentityFailureKind.invalidResponse,
    );
  }
  return GoogleIdentityAuthenticated(
    GoogleIdentityTokens(idToken: idToken, accessToken: accessToken),
  );
}

GoogleIdentityFailureKind googleIdentityFailureKindForExceptionCode(
  GoogleSignInExceptionCode code,
) {
  return switch (code) {
    GoogleSignInExceptionCode.interrupted =>
      GoogleIdentityFailureKind.temporarilyUnavailable,
    GoogleSignInExceptionCode.clientConfigurationError ||
    GoogleSignInExceptionCode.providerConfigurationError ||
    GoogleSignInExceptionCode.uiUnavailable =>
      GoogleIdentityFailureKind.providerUnavailable,
    GoogleSignInExceptionCode.userMismatch =>
      GoogleIdentityFailureKind.invalidResponse,
    GoogleSignInExceptionCode.canceled ||
    GoogleSignInExceptionCode.unknownError => GoogleIdentityFailureKind.unknown,
  };
}
