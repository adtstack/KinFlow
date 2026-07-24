enum AppLogLevel { debug, info, warning, error }

final class AppLogRecord {
  const AppLogRecord({
    required this.attributes,
    required this.contractVersion,
    required this.environment,
    required this.event,
    required this.level,
    required this.platform,
    required this.release,
    required this.timestamp,
  });

  final Map<String, Object> attributes;
  final String contractVersion;
  final String environment;
  final String event;
  final AppLogLevel level;
  final String platform;
  final String release;
  final DateTime timestamp;

  Map<String, Object> toJson() {
    return <String, Object>{
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level.name,
      'event': event,
      'environment': environment,
      'release': release,
      'contract_version': contractVersion,
      'platform': platform,
      if (attributes.isNotEmpty) 'attributes': attributes,
    };
  }
}
