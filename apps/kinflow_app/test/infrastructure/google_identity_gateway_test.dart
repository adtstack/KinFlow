import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';

void main() {
  const String clientId = '1234567890-kinflowdev.apps.googleusercontent.com';

  group('Google identity gateway contract', () {
    test('requires both ephemeral provider tokens', () {
      for (final (String?, String?) values in <(String?, String?)>[
        (null, 'access'),
        ('', 'access'),
        ('id', null),
        ('id', '  '),
      ]) {
        final GoogleIdentityAuthenticationResult result =
            googleIdentityAuthenticationFromTokens(
              idToken: values.$1,
              accessToken: values.$2,
            );

        expect(result, isA<GoogleIdentityAuthenticationFailed>());
        expect(
          (result as GoogleIdentityAuthenticationFailed).kind,
          GoogleIdentityFailureKind.invalidResponse,
        );
      }
    });

    test('redacts token container string output', () {
      const String idToken = 'ephemeral-id-token';
      const String accessToken = 'ephemeral-access-token';
      final GoogleIdentityAuthenticationResult result =
          googleIdentityAuthenticationFromTokens(
            idToken: idToken,
            accessToken: accessToken,
          );

      expect(result, isA<GoogleIdentityAuthenticated>());
      final GoogleIdentityTokens tokens =
          (result as GoogleIdentityAuthenticated).tokens;
      expect(tokens.toString(), isNot(contains(idToken)));
      expect(tokens.toString(), isNot(contains(accessToken)));
      expect(tokens.toString(), contains('redacted'));
    });

    test('maps plugin codes without reading exception descriptions', () {
      const Map<GoogleSignInExceptionCode, GoogleIdentityFailureKind>
      expectations = <GoogleSignInExceptionCode, GoogleIdentityFailureKind>{
        GoogleSignInExceptionCode.interrupted:
            GoogleIdentityFailureKind.temporarilyUnavailable,
        GoogleSignInExceptionCode.clientConfigurationError:
            GoogleIdentityFailureKind.providerUnavailable,
        GoogleSignInExceptionCode.providerConfigurationError:
            GoogleIdentityFailureKind.providerUnavailable,
        GoogleSignInExceptionCode.uiUnavailable:
            GoogleIdentityFailureKind.providerUnavailable,
        GoogleSignInExceptionCode.userMismatch:
            GoogleIdentityFailureKind.invalidResponse,
        GoogleSignInExceptionCode.canceled: GoogleIdentityFailureKind.unknown,
        GoogleSignInExceptionCode.unknownError:
            GoogleIdentityFailureKind.unknown,
      };

      for (final MapEntry<GoogleSignInExceptionCode, GoogleIdentityFailureKind>
          entry
          in expectations.entries) {
        expect(
          googleIdentityFailureKindForExceptionCode(entry.key),
          entry.value,
        );
      }
    });

    test('initializes the SDK exactly once before authentication', () async {
      final _FakeGoogleIdentitySdkDriver driver = _FakeGoogleIdentitySdkDriver(
        result: const GoogleIdentityAuthenticationCancelled(),
      );
      final GoogleSignInIdentityGateway gateway =
          GoogleSignInIdentityGateway.withDriver(driver);

      await gateway.authenticate(serverClientId: clientId);
      await gateway.authenticate(serverClientId: clientId);

      expect(driver.initializeClientIds, <String>[clientId]);
      expect(driver.authenticateCount, 2);
    });

    test('maps cancellation and supported-platform failures safely', () async {
      final _FakeGoogleIdentitySdkDriver cancellingDriver =
          _FakeGoogleIdentitySdkDriver(
            exception: const GoogleSignInException(
              code: GoogleSignInExceptionCode.canceled,
              description: 'provider detail must not escape',
            ),
          );
      final GoogleIdentityAuthenticationResult cancelled =
          await GoogleSignInIdentityGateway.withDriver(
            cancellingDriver,
          ).authenticate(serverClientId: clientId);
      expect(cancelled, isA<GoogleIdentityAuthenticationCancelled>());

      final _FakeGoogleIdentitySdkDriver unsupportedDriver =
          _FakeGoogleIdentitySdkDriver(
            supportsAuthentication: false,
            result: const GoogleIdentityAuthenticationCancelled(),
          );
      final GoogleIdentityAuthenticationResult unsupported =
          await GoogleSignInIdentityGateway.withDriver(
            unsupportedDriver,
          ).authenticate(serverClientId: clientId);
      expect(
        (unsupported as GoogleIdentityAuthenticationFailed).kind,
        GoogleIdentityFailureKind.providerUnavailable,
      );
      expect(unsupportedDriver.authenticateCount, 0);
    });

    test('sign-out shares initialization and rejects client drift', () async {
      final _FakeGoogleIdentitySdkDriver driver = _FakeGoogleIdentitySdkDriver(
        result: const GoogleIdentityAuthenticationCancelled(),
      );
      final GoogleSignInIdentityGateway gateway =
          GoogleSignInIdentityGateway.withDriver(driver);

      await gateway.signOut(serverClientId: clientId);
      await gateway.signOut(serverClientId: clientId);

      expect(driver.initializeClientIds, <String>[clientId]);
      expect(driver.signOutCount, 2);
      await expectLater(
        gateway.signOut(
          serverClientId: '9999999999-other.apps.googleusercontent.com',
        ),
        throwsStateError,
      );
    });
  });
}

final class _FakeGoogleIdentitySdkDriver implements GoogleIdentitySdkDriver {
  _FakeGoogleIdentitySdkDriver({
    this.result,
    this.exception,
    this.supportsAuthentication = true,
  });

  final GoogleIdentityAuthenticationResult? result;
  final GoogleSignInException? exception;
  final bool supportsAuthentication;
  final List<String> initializeClientIds = <String>[];
  var authenticateCount = 0;
  var signOutCount = 0;

  @override
  Future<GoogleIdentityAuthenticationResult> authenticate() async {
    authenticateCount += 1;
    final GoogleSignInException? failure = exception;
    if (failure != null) {
      throw failure;
    }
    return result!;
  }

  @override
  Future<void> initialize({required String serverClientId}) async {
    initializeClientIds.add(serverClientId);
  }

  @override
  Future<void> signOut() async {
    signOutCount += 1;
  }

  @override
  bool supportsAuthenticate() => supportsAuthentication;
}
