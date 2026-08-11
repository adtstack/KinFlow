import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kinflow_app/app/app_environment.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/features/analytics/application/ports/analytics_sink.dart';
import 'package:kinflow_app/features/analytics/application/unavailable_analytics_dependencies.dart';
import 'package:kinflow_app/features/analytics/data/repositories/secure_analytics_preference_repository.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';
import 'package:kinflow_app/infrastructure/secure_storage/flutter_secure_string_store.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

final class AnalyticsDependencies {
  const AnalyticsDependencies({
    required this.preferenceRepository,
    required this.sink,
    required this.metadata,
  });

  final AnalyticsPreferenceRepository preferenceRepository;
  final AnalyticsSink sink;
  final AnalyticsDispatchMetadata metadata;
}

AnalyticsDependencies createAnalyticsDependencies(
  AppPublicConfiguration configuration,
) {
  final SecureStringStore store = FlutterSecureStringStore(
    FlutterSecureStorage(
      aOptions: AndroidOptions(
        resetOnError: true,
        migrateOnAlgorithmChange: true,
        migrateWithBackup: false,
        enforceBiometrics: false,
        keyCipherAlgorithm:
            KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
        storageNamespace:
            'kinflow_analytics_${configuration.environment.value}_v1',
      ),
      iOptions: IOSOptions(
        accountName: 'kinflow_analytics_${configuration.environment.value}_v1',
      ),
    ),
    SecureAnalyticsPreferenceRepository.storageKey,
  );
  return AnalyticsDependencies(
    preferenceRepository: SecureAnalyticsPreferenceRepository(store),
    sink: const UnavailableAnalyticsSink(),
    metadata: AnalyticsDispatchMetadata(
      appRelease: configuration.release,
      environment: _analyticsEnvironment(configuration.environment),
    ),
  );
}

AnalyticsDependencies createUnavailableAnalyticsDependencies() {
  return const AnalyticsDependencies(
    preferenceRepository: UnavailableAnalyticsPreferenceRepository(),
    sink: UnavailableAnalyticsSink(),
    metadata: AnalyticsDispatchMetadata(
      appRelease: 'unavailable',
      environment: AnalyticsEnvironment.dev,
    ),
  );
}

AnalyticsEnvironment _analyticsEnvironment(AppEnvironment environment) {
  return switch (environment) {
    AppEnvironment.dev => AnalyticsEnvironment.dev,
    AppEnvironment.prod => AnalyticsEnvironment.prod,
  };
}
