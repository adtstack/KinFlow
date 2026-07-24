abstract final class AppTelemetryFields {
  static const Set<String> allowedAttributes = <String>{
    'capability',
    'duration_ms',
    'error_code',
    'feature',
    'operation',
    'provider',
    'provider_status',
    'reason',
    'request_id',
    'result',
    'retry_count',
    'screen',
  };

  static const Set<String> numericAttributes = <String>{
    'duration_ms',
    'retry_count',
  };

  static const Set<String> forbiddenKeyFragments = <String>{
    'address',
    'authorization',
    'body',
    'child',
    'cookie',
    'email',
    'household_id',
    'invite',
    'name',
    'password',
    'phone',
    'receipt',
    'secret',
    'title',
    'token',
    'url',
    'user_id',
  };
}

final class AppTelemetrySanitizer {
  const AppTelemetrySanitizer();

  static const String redacted = '[REDACTED]';

  Map<String, Object> sanitizeAttributes(Map<String, Object?> attributes) {
    final Map<String, Object> safe = <String, Object>{};
    for (final MapEntry<String, Object?> entry in attributes.entries) {
      final String key = entry.key.toLowerCase().trim();
      if (!_isAllowedKey(key)) {
        continue;
      }

      final Object? value = entry.value;
      if (value is bool) {
        safe[key] = value;
      } else if (value is num && value.isFinite) {
        safe[key] = value;
      } else if (value is String) {
        safe[key] = _sanitizeAttributeString(key, value);
      }
    }
    return Map<String, Object>.unmodifiable(safe);
  }

  String sanitizeStableMessage(String? value, {String fallback = redacted}) {
    if (value == null) {
      return fallback;
    }
    final String normalized = value.trim().toLowerCase();
    if (_containsSensitivePattern(normalized) ||
        !_stableTokenPattern.hasMatch(normalized)) {
      return fallback;
    }
    return normalized;
  }

  String sanitizeCodeIdentifier(String? value) {
    if (value == null || value.isEmpty) {
      return redacted;
    }
    final String normalized = value.replaceAll('\\', '/');
    final String candidate = normalized.contains('/')
        ? normalized.substring(normalized.lastIndexOf('/') + 1)
        : normalized;
    if (_codeIdentifierPattern.hasMatch(candidate) &&
        !_containsSensitivePattern(candidate)) {
      return candidate;
    }
    return redacted;
  }

  bool _containsSensitivePattern(String value) {
    return _emailPattern.hasMatch(value) ||
        _bearerPattern.hasMatch(value) ||
        _jwtPattern.hasMatch(value) ||
        _credentialAssignmentPattern.hasMatch(value) ||
        value.contains('?') ||
        value.contains('#');
  }

  bool _isAllowedKey(String key) {
    if (!AppTelemetryFields.allowedAttributes.contains(key)) {
      return false;
    }
    return !AppTelemetryFields.forbiddenKeyFragments.any(key.contains);
  }

  String _sanitizeAttributeString(String key, String value) {
    final String normalized = value.trim().toLowerCase();
    if (_containsSensitivePattern(normalized)) {
      return redacted;
    }
    if (key == 'request_id') {
      return _requestIdPattern.hasMatch(value.trim()) ? value.trim() : redacted;
    }
    if (AppTelemetryFields.numericAttributes.contains(key)) {
      return redacted;
    }
    return _stableTokenPattern.hasMatch(normalized) ? normalized : redacted;
  }

  static final RegExp _bearerPattern = RegExp(
    r'\bbearer\s+[a-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _codeIdentifierPattern = RegExp(
    r'^[A-Za-z_][A-Za-z0-9_.<>-]{0,127}$',
  );
  static final RegExp _credentialAssignmentPattern = RegExp(
    r'\b(?:api[_-]?key|password|secret|token)\s*[:=]',
    caseSensitive: false,
  );
  static final RegExp _emailPattern = RegExp(
    r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
    caseSensitive: false,
  );
  static final RegExp _jwtPattern = RegExp(
    r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b',
  );
  static final RegExp _requestIdPattern = RegExp(r'^[A-Za-z0-9_-]{8,128}$');
  static final RegExp _stableTokenPattern = RegExp(
    r'^[a-z][a-z0-9_.-]{0,127}$',
  );
}
