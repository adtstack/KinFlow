import 'dart:convert';

const int diagnosticReportSchemaVersion = 1;

enum DiagnosticEnvironment {
  dev('dev'),
  prod('prod');

  const DiagnosticEnvironment(this.wireValue);

  final String wireValue;
}

enum DiagnosticDevicePlatform {
  android('android'),
  ios('ios'),
  web('web'),
  macos('macos'),
  windows('windows'),
  linux('linux'),
  fuchsia('fuchsia'),
  unknown('unknown');

  const DiagnosticDevicePlatform(this.wireValue);

  final String wireValue;
}

final class DiagnosticAppBuild {
  const DiagnosticAppBuild._({
    required this.applicationId,
    required this.version,
    required this.buildNumber,
  });

  final String applicationId;
  final String version;
  final String buildNumber;

  String get configuredVersion => '$version+$buildNumber';

  static DiagnosticAppBuild? tryCreate({
    required String applicationId,
    required String version,
    required String buildNumber,
  }) {
    if (!_applicationIdPattern.hasMatch(applicationId) ||
        applicationId.length > 255 ||
        !_versionPattern.hasMatch(version) ||
        version.length > 64 ||
        !_buildNumberPattern.hasMatch(buildNumber) ||
        buildNumber.length > 32) {
      return null;
    }
    return DiagnosticAppBuild._(
      applicationId: applicationId,
      version: version,
      buildNumber: buildNumber,
    );
  }

  static final RegExp _applicationIdPattern = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*$',
  );
  static final RegExp _versionPattern = RegExp(
    r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$',
  );
  static final RegExp _buildNumberPattern = RegExp(r'^[1-9]\d*$');
}

final class DiagnosticIncidentId {
  const DiagnosticIncidentId._(this.value);

  final String value;

  static DiagnosticIncidentId? tryParse(String value) {
    return _uuidV4Pattern.hasMatch(value)
        ? DiagnosticIncidentId._(value)
        : null;
  }

  static final RegExp _uuidV4Pattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );
}

final class DiagnosticReport {
  const DiagnosticReport._({
    required this.appBuild,
    required this.environment,
    required this.contractVersion,
    required this.devicePlatform,
    required this.incidentId,
    required this.generatedAt,
  });

  final DiagnosticAppBuild appBuild;
  final DiagnosticEnvironment environment;
  final String contractVersion;
  final DiagnosticDevicePlatform devicePlatform;
  final DiagnosticIncidentId incidentId;
  final DateTime generatedAt;

  static DiagnosticReport? tryCreate({
    required DiagnosticAppBuild appBuild,
    required DiagnosticEnvironment environment,
    required String contractVersion,
    required DiagnosticDevicePlatform devicePlatform,
    required DiagnosticIncidentId incidentId,
    required DateTime generatedAt,
  }) {
    if (!_validContractVersion(contractVersion) || !generatedAt.isUtc) {
      return null;
    }
    return DiagnosticReport._(
      appBuild: appBuild,
      environment: environment,
      contractVersion: contractVersion,
      devicePlatform: devicePlatform,
      incidentId: incidentId,
      generatedAt: generatedAt,
    );
  }

  Map<String, Object> toSafeJson() {
    return <String, Object>{
      'schemaVersion': diagnosticReportSchemaVersion,
      'applicationId': appBuild.applicationId,
      'appVersion': appBuild.version,
      'buildNumber': appBuild.buildNumber,
      'environment': environment.wireValue,
      'contractVersion': contractVersion,
      'devicePlatform': devicePlatform.wireValue,
      'incidentId': incidentId.value,
      'generatedAtUtc': generatedAt.toIso8601String(),
    };
  }

  String toClipboardText() {
    return const JsonEncoder.withIndent('  ').convert(toSafeJson());
  }

  static bool _validContractVersion(String value) {
    if (!_contractVersionPattern.hasMatch(value)) return false;
    final DateTime? parsed = DateTime.tryParse('${value}T00:00:00Z');
    return parsed != null && parsed.toIso8601String().startsWith(value);
  }

  static final RegExp _contractVersionPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
}
