import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/data/datasources/auth_sign_in_data_source.dart';
import 'package:kinflow_app/features/auth/data/services/provider_auth_sign_in_launcher.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/domain/services/auth_sign_in_launcher.dart';

void main() {
  group('ProviderAuthSignInLauncher', () {
    test(
      'forwards availability and maps a completed provider request',
      () async {
        final _FakeAuthSignInDataSource dataSource = _FakeAuthSignInDataSource(
          isAvailable: true,
          result: const AuthSignInDataCompleted(),
        );
        final ProviderAuthSignInLauncher launcher = ProviderAuthSignInLauncher(
          dataSource,
        );

        expect(launcher.isAvailable, isTrue);
        expect(await launcher.requestSignIn(), isA<AuthSignInRequestStarted>());
        expect(dataSource.requestCount, 1);
      },
    );

    test(
      'maps provider cancellation without manufacturing a failure',
      () async {
        final ProviderAuthSignInLauncher launcher = ProviderAuthSignInLauncher(
          _FakeAuthSignInDataSource(
            isAvailable: true,
            result: const AuthSignInDataCancelled(),
          ),
        );

        expect(
          await launcher.requestSignIn(),
          isA<AuthSignInRequestCancelled>(),
        );
      },
    );

    test('maps only stable failure kinds into the domain', () async {
      const Map<AuthSignInDataFailureKind, AuthFailureKind> expectations =
          <AuthSignInDataFailureKind, AuthFailureKind>{
            AuthSignInDataFailureKind.providerUnavailable:
                AuthFailureKind.providerUnavailable,
            AuthSignInDataFailureKind.temporarilyUnavailable:
                AuthFailureKind.temporarilyUnavailable,
            AuthSignInDataFailureKind.invalidPayload: AuthFailureKind.internal,
            AuthSignInDataFailureKind.unknown: AuthFailureKind.internal,
          };

      for (final MapEntry<AuthSignInDataFailureKind, AuthFailureKind> entry
          in expectations.entries) {
        final ProviderAuthSignInLauncher launcher = ProviderAuthSignInLauncher(
          _FakeAuthSignInDataSource(
            isAvailable: true,
            result: AuthSignInDataFailed(entry.key),
          ),
        );

        final AuthSignInRequestResult result = await launcher.requestSignIn();
        expect(result, isA<AuthSignInRequestFailed>());
        expect((result as AuthSignInRequestFailed).failure.kind, entry.value);
      }
    });
  });
}

final class _FakeAuthSignInDataSource implements AuthSignInDataSource {
  _FakeAuthSignInDataSource({required this.isAvailable, required this.result});

  @override
  final bool isAvailable;

  final AuthSignInDataResult result;
  var requestCount = 0;

  @override
  Future<AuthSignInDataResult> requestGoogleSignIn() async {
    requestCount += 1;
    return result;
  }
}
