import 'package:kinflow_app/infrastructure/supabase/supabase_health_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseSdkFunctionInvoker implements SupabaseFunctionInvoker {
  const SupabaseSdkFunctionInvoker(this._client);

  final SupabaseClient _client;

  @override
  Future<SupabaseFunctionResponse> invokeHealth() async {
    final FunctionResponse response = await _client.functions.invoke(
      'health',
      method: HttpMethod.get,
    );

    return SupabaseFunctionResponse(
      status: response.status,
      data: response.data as Object?,
    );
  }
}
