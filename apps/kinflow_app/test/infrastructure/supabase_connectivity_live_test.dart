import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_health_client.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_sdk_function_invoker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _supabaseUrl = String.fromEnvironment(
  'KINFLOW_LOCAL_SUPABASE_URL',
);
const String _supabasePublishableKey = String.fromEnvironment(
  'KINFLOW_LOCAL_SUPABASE_PUBLISHABLE_KEY',
);

void main() {
  test(
    'Flutter Supabase adapter reaches the local health function',
    () async {
      final SupabaseClient sdkClient = SupabaseClient(
        _supabaseUrl,
        _supabasePublishableKey,
      );
      addTearDown(sdkClient.dispose);
      final SupabaseHealthClient healthClient = SupabaseHealthClient(
        SupabaseSdkFunctionInvoker(sdkClient),
      );

      final SupabaseHealthResult result = await healthClient.check();

      expect(result, isA<SupabaseHealthAvailable>());
      expect((result as SupabaseHealthAvailable).contractVersion, '2026-07-24');
    },
    skip: _supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty
        ? 'Run with the local Supabase URL and publishable key dart-defines.'
        : false,
  );
}
