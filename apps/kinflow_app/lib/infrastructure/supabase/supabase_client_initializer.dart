import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class SupabaseClientInitializer {
  Future<SupabaseClient> initialize({
    required Uri uri,
    required String publishableKey,
    required LocalStorage localStorage,
    required GotrueAsyncStorage pkceStorage,
    required Map<String, String> headers,
  });
}

final class SupabaseFlutterClientInitializer
    implements SupabaseClientInitializer {
  const SupabaseFlutterClientInitializer();

  @override
  Future<SupabaseClient> initialize({
    required Uri uri,
    required String publishableKey,
    required LocalStorage localStorage,
    required GotrueAsyncStorage pkceStorage,
    required Map<String, String> headers,
  }) async {
    try {
      final Supabase instance = await Supabase.initialize(
        url: uri.toString(),
        publishableKey: publishableKey,
        headers: headers,
        authOptions: secureSupabaseAuthClientOptions(
          localStorage: localStorage,
          pkceStorage: pkceStorage,
        ),
        debug: false,
      );
      return instance.client;
    } on Object {
      await _disposePartiallyInitializedInstance();
      rethrow;
    }
  }

  Future<void> _disposePartiallyInitializedInstance() async {
    try {
      await Supabase.instance.dispose();
    } on Object {
      // Cleanup is best-effort; the original initialization failure is kept.
    }
  }
}

FlutterAuthClientOptions secureSupabaseAuthClientOptions({
  required LocalStorage localStorage,
  required GotrueAsyncStorage pkceStorage,
}) {
  return FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    autoRefreshToken: true,
    localStorage: localStorage,
    pkceAsyncStorage: pkceStorage,
    detectSessionInUri: false,
  );
}
