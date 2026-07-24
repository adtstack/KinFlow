import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_health_client.dart';

void main() {
  group('SupabaseHealthClient', () {
    test('accepts the exact local health contract', () async {
      const SupabaseHealthClient client = SupabaseHealthClient(
        _FakeInvoker(
          response: SupabaseFunctionResponse(
            status: 200,
            data: <String, Object?>{
              'status': 'ok',
              'service': 'kinflow-edge',
              'contractVersion': '2026-07-24',
              'environment': 'local',
              'requestId': 'test-request-1',
            },
          ),
        ),
      );

      final SupabaseHealthResult result = await client.check();

      expect(result, isA<SupabaseHealthAvailable>());
      expect((result as SupabaseHealthAvailable).contractVersion, '2026-07-24');
    });

    test('rejects payload drift without exposing response data', () async {
      const SupabaseHealthClient client = SupabaseHealthClient(
        _FakeInvoker(
          response: SupabaseFunctionResponse(
            status: 200,
            data: <String, Object?>{
              'status': 'future-status',
              'service': 'kinflow-edge',
              'contractVersion': '2026-07-24',
              'environment': 'local',
              'requestId': 'test-request-2',
            },
          ),
        ),
      );

      final SupabaseHealthResult result = await client.check();

      expect(result, isA<SupabaseHealthUnavailable>());
      expect(
        (result as SupabaseHealthUnavailable).code,
        'supabase.health.invalid_payload',
      );
    });

    test('maps SDK exceptions to a stable failure code', () async {
      const SupabaseHealthClient client = SupabaseHealthClient(
        _FakeInvoker(exception: FormatException('sensitive upstream detail')),
      );

      final SupabaseHealthResult result = await client.check();

      expect(result, isA<SupabaseHealthUnavailable>());
      expect(
        (result as SupabaseHealthUnavailable).code,
        'supabase.health.unavailable',
      );
    });
  });
}

final class _FakeInvoker implements SupabaseFunctionInvoker {
  const _FakeInvoker({this.response, this.exception});

  final SupabaseFunctionResponse? response;
  final Exception? exception;

  @override
  Future<SupabaseFunctionResponse> invokeHealth() async {
    final Exception? failure = exception;
    if (failure != null) {
      throw failure;
    }
    return response!;
  }
}
