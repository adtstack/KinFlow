import 'dart:convert';

import 'package:kinflow_app/features/offline/application/read_cache.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseReadCacheScopeResolver
    implements ReadCacheSessionScopeResolver {
  SupabaseReadCacheScopeResolver(this._client, {this._clock = DateTime.now});

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final SupabaseClient _client;
  final ReadCacheClock _clock;

  @override
  ReadCacheSessionScope? currentScope() {
    final Session? session = _client.auth.currentSession;
    final int? expiresAtSeconds = session?.expiresAt;
    if (session == null || expiresAtSeconds == null) {
      return null;
    }
    final String userId = session.user.id.trim().toLowerCase();
    final Map<String, Object?>? claims = _claims(session.accessToken);
    final Object? subject = claims?['sub'];
    final Object? sessionIdValue = claims?['session_id'];
    final String? sessionId = sessionIdValue is String
        ? sessionIdValue.trim().toLowerCase()
        : null;
    if (!_uuidPattern.hasMatch(userId) ||
        subject is! String ||
        subject.trim().toLowerCase() != userId ||
        sessionId == null ||
        !_uuidPattern.hasMatch(sessionId)) {
      return null;
    }
    final DateTime expiresAt = DateTime.fromMillisecondsSinceEpoch(
      expiresAtSeconds * 1000,
      isUtc: true,
    );
    if (!_clock().toUtc().isBefore(expiresAt)) {
      return null;
    }
    return ReadCacheSessionScope(
      userId: userId,
      sessionId: sessionId,
      expiresAt: expiresAt,
    );
  }

  Map<String, Object?>? _claims(String token) {
    if (token.length > 16384) {
      return null;
    }
    final List<String> segments = token.split('.');
    if (segments.length != 3 || segments[1].isEmpty) {
      return null;
    }
    try {
      final String normalized = base64Url.normalize(segments[1]);
      final Object? decoded = jsonDecode(
        utf8.decode(base64Url.decode(normalized), allowMalformed: false),
      );
      if (decoded is! Map ||
          decoded.keys.any((Object? key) => key is! String)) {
        return null;
      }
      return Map<String, Object?>.from(decoded);
    } on Object {
      return null;
    }
  }
}
