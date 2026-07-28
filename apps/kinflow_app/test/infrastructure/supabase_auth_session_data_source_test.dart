import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/auth/data/datasources/auth_session_data_source.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_auth_session_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseAuthSessionDataSource', () {
    late SupabaseClient client;
    late SupabaseAuthSessionDataSource dataSource;

    setUp(() {
      client = SupabaseClient('http://127.0.0.1:54321', 'public-test-key');
      dataSource = SupabaseAuthSessionDataSource(client);
    });

    tearDown(() async {
      await client.dispose();
    });

    test('restores an absent session without contacting the network', () async {
      final AuthSessionDataResult result = await dataSource.restoreSession();

      expect(result, isA<AuthSessionDataAbsent>());
    });

    test('maps a missing refresh session to an expired result', () async {
      final AuthSessionDataResult result = await dataSource.refreshSession();

      expect(result, isA<AuthSessionDataFailed>());
      expect(
        (result as AuthSessionDataFailed).kind,
        AuthSessionDataFailureKind.sessionExpired,
      );
    });

    test(
      'maps the SDK signed-out event without exposing provider state',
      () async {
        final Future<AuthSessionDataEvent> event =
            dataSource.sessionEvents.first;

        await client.auth.signOut();

        expect(
          await event.timeout(const Duration(seconds: 1)),
          isA<AuthSessionDataTerminated>(),
        );
      },
    );
  });
}
