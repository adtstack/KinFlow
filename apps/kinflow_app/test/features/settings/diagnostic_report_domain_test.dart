import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/settings/data/services/secure_diagnostic_incident_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';

import '../../support/fakes/fake_diagnostic_dependencies.dart';

void main() {
  test('serializes the exact ordered PII-safe schema', () {
    final DiagnosticReport report = diagnosticReportFixture();

    final Map<String, Object> safeJson = report.toSafeJson();

    expect(safeJson.keys.toList(), <String>[
      'schemaVersion',
      'applicationId',
      'appVersion',
      'buildNumber',
      'environment',
      'contractVersion',
      'devicePlatform',
      'incidentId',
      'generatedAtUtc',
    ]);
    expect(safeJson, <String, Object>{
      'schemaVersion': 1,
      'applicationId': 'me.newlines.kinflow.dev',
      'appVersion': '0.1.0-dev',
      'buildNumber': '1',
      'environment': 'dev',
      'contractVersion': '2026-08-08',
      'devicePlatform': 'android',
      'incidentId': '123e4567-e89b-42d3-a456-426614174000',
      'generatedAtUtc': '2026-08-08T02:03:04.000Z',
    });
    expect(
      jsonDecode(report.toClipboardText()),
      equals(<String, Object?>{...safeJson}),
    );
  });

  test('safe payload contains no identity, content, or device detail keys', () {
    final DiagnosticReport report = diagnosticReportFixture();
    final Set<String> keys = report.toSafeJson().keys.toSet();

    expect(
      keys.intersection(<String>{
        'userId',
        'accountId',
        'householdId',
        'memberId',
        'email',
        'name',
        'chore',
        'calendar',
        'notification',
        'billing',
        'token',
        'ipAddress',
        'locale',
        'timezone',
        'deviceModel',
        'deviceSerial',
        'advertisingId',
        'buildSignature',
        'installerStore',
      }),
      isEmpty,
    );
    final String payload = report.toClipboardText();
    expect(payload, isNot(contains('adult@example.com')));
    expect(payload, isNot(contains('household-secret')));
    expect(payload, isNot(contains('device-model-secret')));
  });

  test('rejects unsafe or ambiguous installed app metadata', () {
    expect(
      DiagnosticAppBuild.tryCreate(
        applicationId: 'me.newlines.kinflow.dev',
        version: '0.1.0-dev',
        buildNumber: '1',
      )?.configuredVersion,
      '0.1.0-dev+1',
    );
    for (final (String applicationId, String version, String buildNumber)
        in <(String, String, String)>[
          ('me.newlines.kinflow dev', '0.1.0-dev', '1'),
          ('me.newlines.kinflow.dev', '0.1.0-dev+1', '1'),
          ('me.newlines.kinflow.dev', 'latest', '1'),
          ('me.newlines.kinflow.dev', '0.1.0-dev', '0'),
          ('me.newlines.kinflow.dev', '0.1.0-dev', '1.2'),
        ]) {
      expect(
        DiagnosticAppBuild.tryCreate(
          applicationId: applicationId,
          version: version,
          buildNumber: buildNumber,
        ),
        isNull,
      );
    }
  });

  test('requires lowercase UUID v4, real contract date, and UTC timestamp', () {
    expect(
      DiagnosticIncidentId.tryParse('123e4567-e89b-42d3-a456-426614174000'),
      isNotNull,
    );
    expect(
      DiagnosticIncidentId.tryParse('123e4567-e89b-12d3-a456-426614174000'),
      isNull,
    );
    expect(
      DiagnosticIncidentId.tryParse('123E4567-E89B-42D3-A456-426614174000'),
      isNull,
    );

    final DiagnosticAppBuild build = DiagnosticAppBuild.tryCreate(
      applicationId: 'me.newlines.kinflow.dev',
      version: '0.1.0-dev',
      buildNumber: '1',
    )!;
    final DiagnosticIncidentId incident = DiagnosticIncidentId.tryParse(
      '123e4567-e89b-42d3-a456-426614174000',
    )!;
    expect(
      DiagnosticReport.tryCreate(
        appBuild: build,
        environment: DiagnosticEnvironment.dev,
        contractVersion: '2026-02-30',
        devicePlatform: DiagnosticDevicePlatform.android,
        incidentId: incident,
        generatedAt: DateTime.utc(2026, 8, 8),
      ),
      isNull,
    );
    expect(
      DiagnosticReport.tryCreate(
        appBuild: build,
        environment: DiagnosticEnvironment.dev,
        contractVersion: '2026-08-08',
        devicePlatform: DiagnosticDevicePlatform.android,
        incidentId: incident,
        generatedAt: DateTime(2026, 8, 8),
      ),
      isNull,
    );
  });

  test('secure generator creates unique UUID v4 values', () {
    final SecureDiagnosticIncidentIdGenerator generator =
        SecureDiagnosticIncidentIdGenerator(random: Random(7));
    final Set<String> values = <String>{};

    for (var index = 0; index < 100; index += 1) {
      final String value = generator.generate().value;
      expect(DiagnosticIncidentId.tryParse(value), isNotNull);
      values.add(value);
    }

    expect(values, hasLength(100));
  });
}
