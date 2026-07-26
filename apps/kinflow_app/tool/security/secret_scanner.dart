import 'dart:convert';
import 'dart:io';

final class SecretFinding {
  const SecretFinding({
    required this.line,
    required this.path,
    required this.rule,
  });

  final int line;
  final String path;
  final String rule;
}

final class SecretScanner {
  const SecretScanner();

  List<SecretFinding> scanDirectory(Directory root) {
    final List<SecretFinding> findings = <SecretFinding>[];
    _walk(root, root, findings);
    findings.sort((SecretFinding left, SecretFinding right) {
      final int pathOrder = left.path.compareTo(right.path);
      return pathOrder != 0 ? pathOrder : left.line.compareTo(right.line);
    });
    return findings;
  }

  List<SecretFinding> scanText({required String path, required String text}) {
    final List<SecretFinding> findings = <SecretFinding>[];
    final List<String> lines = const LineSplitter().convert(text);
    for (var index = 0; index < lines.length; index += 1) {
      final String line = lines[index];
      for (final _SecretRule rule in _rules) {
        if (rule.pattern.hasMatch(line) && !rule.isSafeFixture(line)) {
          findings.add(
            SecretFinding(path: path, line: index + 1, rule: rule.name),
          );
        }
      }
    }
    return findings;
  }

  void _walk(Directory root, Directory current, List<SecretFinding> findings) {
    for (final FileSystemEntity entity in current.listSync(
      followLinks: false,
    )) {
      final String name = entity.uri.pathSegments
          .where((String segment) => segment.isNotEmpty)
          .last;
      if (entity is Directory) {
        if (!_ignoredDirectories.contains(name)) {
          _walk(root, entity, findings);
        }
        continue;
      }
      if (entity is! File ||
          _ignoredFiles.contains(name) ||
          _binaryExtensions.any(name.toLowerCase().endsWith)) {
        continue;
      }
      final int size = entity.lengthSync();
      if (size > _maximumTextFileBytes) {
        continue;
      }
      try {
        final String relativePath = entity.path
            .substring(root.path.length)
            .replaceAll('\\', '/')
            .replaceFirst(RegExp(r'^/'), '');
        findings.addAll(
          scanText(
            path: relativePath,
            text: entity.readAsStringSync(encoding: utf8),
          ),
        );
      } on FileSystemException {
        // Unreadable files are outside this deterministic source scan surface.
      } on FormatException {
        // Files that are not UTF-8 text are treated as binary and skipped.
      }
    }
  }

  static const int _maximumTextFileBytes = 2 * 1024 * 1024;
  static const Set<String> _ignoredDirectories = <String>{
    '.dart_tool',
    '.git',
    '.gradle',
    '.idea',
    'build',
    'coverage',
    'ci-reports',
    'node_modules',
  };
  static const Set<String> _ignoredFiles = <String>{'.DS_Store'};
  static const List<String> _binaryExtensions = <String>[
    '.aab',
    '.apk',
    '.gif',
    '.ico',
    '.jar',
    '.jpeg',
    '.jpg',
    '.keystore',
    '.pdf',
    '.png',
    '.so',
    '.webp',
    '.zip',
  ];

  static final List<_SecretRule> _rules = <_SecretRule>[
    _SecretRule('private-key', RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----')),
    _SecretRule('aws-access-key', RegExp(r'\bAKIA[0-9A-Z]{16}\b')),
    _SecretRule('google-api-key', RegExp(r'\bAIza[0-9A-Za-z_-]{35}\b')),
    _SecretRule('github-token', RegExp(r'\bgh[pousr]_[A-Za-z0-9]{36,255}\b')),
    _SecretRule('slack-token', RegExp(r'\bxox[baprs]-[A-Za-z0-9-]{20,255}\b')),
    _SecretRule(
      'jwt',
      RegExp(r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b'),
    ),
    _SecretRule(
      'server-secret-assignment',
      RegExp(
        r'''\b(?:APPLE_APP_STORE_API_PRIVATE_KEY|DATA_EXPORT_SIGNING_KEY|FCM_SERVER_CREDENTIAL|GOOGLE_CLIENT_SECRET|GOOGLE_PLAY_SERVICE_ACCOUNT_JSON|INTERNAL_JOB_AUTH_SECRET|INVITE_TOKEN_HMAC_KEY|REVENUECAT_SECRET_API_KEY|REVENUECAT_WEBHOOK_SECRET|SENTRY_AUTH_TOKEN|SIGNING_KEYSTORE_PASSWORD|SUPABASE_DB_PASSWORD|SUPABASE_DB_URL|SUPABASE_JWT_SECRET|SUPABASE_SERVICE_ROLE_KEY)\s*[:=]\s*["']?[^\s"']+''',
        caseSensitive: false,
      ),
      allowSafeFixture: true,
    ),
  ];
}

final class _SecretRule {
  const _SecretRule(this.name, this.pattern, {this.allowSafeFixture = false});

  final bool allowSafeFixture;
  final String name;
  final RegExp pattern;

  bool isSafeFixture(String line) {
    if (!allowSafeFixture) {
      return false;
    }
    final String normalized = line.toLowerCase();
    return normalized.contains('env(') ||
        normalized.contains('replace-with-') ||
        normalized.contains('<') ||
        normalized.trimRight().endsWith('=') ||
        normalized.trimRight().endsWith(':');
  }
}
