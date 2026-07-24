import 'dart:io';

import 'security/secret_scanner.dart';

void main() {
  final Directory repositoryRoot = Directory.current.parent.parent;
  final List<SecretFinding> findings = const SecretScanner().scanDirectory(
    repositoryRoot,
  );
  if (findings.isEmpty) {
    stdout.writeln('No high-confidence secrets found.');
    return;
  }

  stderr.writeln(
    'High-confidence secret scan failed with ${findings.length} finding(s).',
  );
  for (final SecretFinding finding in findings) {
    stderr.writeln('${finding.path}:${finding.line} [${finding.rule}]');
  }
  exitCode = 1;
}
