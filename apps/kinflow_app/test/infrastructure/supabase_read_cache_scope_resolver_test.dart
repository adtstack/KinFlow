import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:kinflow_app/infrastructure/supabase/supabase_read_cache_scope_resolver.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const String userId = 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA';
  const String normalizedUserId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const String sessionId = 'BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB';
  const String normalizedSessionId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  test(
    'derives an exact normalized scope from the current Supabase session',
    () async {
      final DateTime now = DateTime.now().toUtc();
      final int expiresAtSeconds =
          now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
      final SupabaseClient client = await _clientWithClaims(
        userId: userId,
        claims: <String, Object?>{
          'sub': userId,
          'session_id': sessionId,
          'exp': expiresAtSeconds,
        },
      );
      addTearDown(client.dispose);
      final SupabaseReadCacheScopeResolver resolver =
          SupabaseReadCacheScopeResolver(client, clock: () => now);

      final ReadCacheSessionScope? scope = resolver.currentScope();

      expect(scope?.userId, normalizedUserId);
      expect(scope?.sessionId, normalizedSessionId);
      expect(
        scope?.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(
          expiresAtSeconds * 1000,
          isUtc: true,
        ),
      );
    },
  );

  test(
    'rejects a token whose subject does not match the current user',
    () async {
      final DateTime now = DateTime.now().toUtc();
      final SupabaseClient client = await _clientWithClaims(
        userId: userId,
        claims: <String, Object?>{
          'sub': 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          'session_id': sessionId,
          'exp':
              now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000,
        },
      );
      addTearDown(client.dispose);

      expect(
        SupabaseReadCacheScopeResolver(client, clock: () => now).currentScope(),
        isNull,
      );
    },
  );

  test(
    'rejects missing, malformed, and locally expired session identity',
    () async {
      final DateTime now = DateTime.now().toUtc();
      final int expiresAtSeconds =
          now.add(const Duration(hours: 2)).millisecondsSinceEpoch ~/ 1000;
      for (final Object? sessionIdentity in <Object?>[null, 'not-a-uuid', 42]) {
        final SupabaseClient client = await _clientWithClaims(
          userId: userId,
          claims: <String, Object?>{
            'sub': userId,
            'session_id': ?sessionIdentity,
            'exp': expiresAtSeconds,
          },
        );
        expect(
          SupabaseReadCacheScopeResolver(
            client,
            clock: () => now,
          ).currentScope(),
          isNull,
        );
        await client.dispose();
      }

      final SupabaseClient expiredClient = await _clientWithClaims(
        userId: userId,
        claims: <String, Object?>{
          'sub': userId,
          'session_id': sessionId,
          'exp': expiresAtSeconds,
        },
      );
      addTearDown(expiredClient.dispose);
      expect(
        SupabaseReadCacheScopeResolver(
          expiredClient,
          clock: () => DateTime.fromMillisecondsSinceEpoch(
            expiresAtSeconds * 1000,
            isUtc: true,
          ),
        ).currentScope(),
        isNull,
      );
    },
  );
}

Future<SupabaseClient> _clientWithClaims({
  required String userId,
  required Map<String, Object?> claims,
}) async {
  final SupabaseClient client = SupabaseClient(
    'https://example.supabase.co',
    'public-anon-key',
  );
  final String accessToken =
      '${_segment(<String, Object?>{'alg': 'none', 'typ': 'JWT'})}.${_segment(claims)}.signature';
  await client.auth.recoverSession(
    jsonEncode(<String, Object?>{
      'access_token': accessToken,
      'expires_in': 7200,
      'refresh_token': null,
      'token_type': 'bearer',
      'user': <String, Object?>{
        'id': userId,
        'app_metadata': const <String, Object?>{},
        'user_metadata': const <String, Object?>{},
        'aud': 'authenticated',
        'created_at': '2026-08-08T00:00:00.000Z',
      },
    }),
  );
  return client;
}

String _segment(Object value) {
  return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
}
