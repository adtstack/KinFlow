abstract interface class SupabaseFunctionInvoker {
  Future<SupabaseFunctionResponse> invokeHealth();
}

final class SupabaseFunctionResponse {
  const SupabaseFunctionResponse({required this.status, required this.data});

  final int status;
  final Object? data;
}

sealed class SupabaseHealthResult {
  const SupabaseHealthResult();
}

final class SupabaseHealthAvailable extends SupabaseHealthResult {
  const SupabaseHealthAvailable({required this.contractVersion});

  final String contractVersion;
}

final class SupabaseHealthUnavailable extends SupabaseHealthResult {
  const SupabaseHealthUnavailable({required this.code});

  final String code;
}

final class SupabaseHealthClient {
  const SupabaseHealthClient(this._invoker);

  final SupabaseFunctionInvoker _invoker;

  Future<SupabaseHealthResult> check() async {
    try {
      final SupabaseFunctionResponse response = await _invoker.invokeHealth();
      if (response.status != 200) {
        return const SupabaseHealthUnavailable(
          code: 'supabase.health.http_error',
        );
      }

      final Object? data = response.data;
      if (data is! Map<String, Object?> || !_isValidPayload(data)) {
        return const SupabaseHealthUnavailable(
          code: 'supabase.health.invalid_payload',
        );
      }

      return SupabaseHealthAvailable(
        contractVersion: data['contractVersion']! as String,
      );
    } on Exception {
      return const SupabaseHealthUnavailable(
        code: 'supabase.health.unavailable',
      );
    }
  }

  bool _isValidPayload(Map<String, Object?> data) {
    return data.length == 5 &&
        data['status'] == 'ok' &&
        data['service'] == 'kinflow-edge' &&
        data['contractVersion'] == '2026-07-24' &&
        data['environment'] == 'local' &&
        data['requestId'] is String &&
        (data['requestId']! as String).isNotEmpty;
  }
}
