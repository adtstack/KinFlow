import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/domain/failures/analytics_preference_failure.dart';
import 'package:kinflow_app/features/analytics/domain/repositories/analytics_preference_repository.dart';
import 'package:kinflow_app/infrastructure/secure_storage/secure_string_store.dart';

final class SecureAnalyticsPreferenceRepository
    implements AnalyticsPreferenceRepository {
  SecureAnalyticsPreferenceRepository(this._store);

  static const String policyVersion = 'analytics-usage-v1';
  static const String storageKey = 'analytics_usage_preference_v1';
  static const String grantedValue = '$policyVersion|granted';
  static const String withdrawnValue = '$policyVersion|withdrawn';

  final SecureStringStore _store;
  Future<void>? _initialization;
  bool _initialized = false;

  @override
  Future<AnalyticsPreferenceResult> load() async {
    try {
      await _ensureInitialized();
      final String? stored = await _store.read(storageKey);
      return AnalyticsPreferenceSucceeded(
        stored == grantedValue
            ? AnalyticsUsagePreference.granted
            : AnalyticsUsagePreference.withdrawn,
      );
    } on Object {
      return _unavailable;
    }
  }

  @override
  Future<AnalyticsPreferenceResult> save(
    AnalyticsUsagePreference preference,
  ) async {
    try {
      await _ensureInitialized();
      await _store.write(storageKey, switch (preference) {
        AnalyticsUsagePreference.granted => grantedValue,
        AnalyticsUsagePreference.withdrawn => withdrawnValue,
      });
      return AnalyticsPreferenceSucceeded(preference);
    } on Object {
      return _unavailable;
    }
  }

  Future<void> _ensureInitialized() {
    if (_initialized) return Future<void>.value();
    final Future<void>? pending = _initialization;
    if (pending != null) return pending;
    final Future<void> next = _initialize();
    _initialization = next;
    return next;
  }

  Future<void> _initialize() async {
    try {
      await _store.initialize();
      _initialized = true;
    } finally {
      _initialization = null;
    }
  }

  static const AnalyticsPreferenceResult _unavailable =
      AnalyticsPreferenceFailed(
        AnalyticsPreferenceFailure(
          AnalyticsPreferenceFailureKind.temporarilyUnavailable,
        ),
      );
}
