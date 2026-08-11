enum AnalyticsEventName {
  applicationSessionStarted,
  householdActivationProgressed,
  inviteAcceptSucceeded,
  choreCompleteSucceeded,
  calendarOccurrenceOpened,
  billingPurchasePendingServerConfirmation,
}

extension AnalyticsEventNameWireValue on AnalyticsEventName {
  String get wireValue => switch (this) {
    AnalyticsEventName.applicationSessionStarted =>
      'application.session.started',
    AnalyticsEventName.householdActivationProgressed =>
      'household.activation.progressed',
    AnalyticsEventName.inviteAcceptSucceeded => 'invite.accept.succeeded',
    AnalyticsEventName.choreCompleteSucceeded => 'chore.complete.succeeded',
    AnalyticsEventName.calendarOccurrenceOpened => 'calendar.occurrence.opened',
    AnalyticsEventName.billingPurchasePendingServerConfirmation =>
      'billing.purchase.pending_server_confirmation',
  };
}

enum AnalyticsUsagePreference { granted, withdrawn }

enum AnalyticsActorMode { adult, managedChild }

enum AnalyticsPlatform { android }

extension AnalyticsPlatformWireValue on AnalyticsPlatform {
  String get wireValue => switch (this) {
    AnalyticsPlatform.android => 'android',
  };
}

enum AnalyticsEnvironment { dev, prod }

extension AnalyticsEnvironmentWireValue on AnalyticsEnvironment {
  String get wireValue => switch (this) {
    AnalyticsEnvironment.dev => 'dev',
    AnalyticsEnvironment.prod => 'prod',
  };
}

enum AnalyticsSinkAvailability { available, unavailable }

final class AnalyticsDispatchMetadata {
  const AnalyticsDispatchMetadata({
    required this.appRelease,
    required this.environment,
    this.platform = AnalyticsPlatform.android,
  });

  final String appRelease;
  final AnalyticsEnvironment environment;
  final AnalyticsPlatform platform;
}

final class AnalyticsEnvelope {
  const AnalyticsEnvelope({required this.event, required this.metadata});

  static const int eventVersion = 1;

  final AnalyticsEventName event;
  final AnalyticsDispatchMetadata metadata;

  Map<String, Object> toSafeJson() {
    return Map<String, Object>.unmodifiable(<String, Object>{
      'event_name': event.wireValue,
      'event_version': eventVersion,
      'platform': metadata.platform.wireValue,
      'app_release': metadata.appRelease,
      'environment': metadata.environment.wireValue,
    });
  }
}

enum AnalyticsRuntimeDependencyPurpose {
  framework,
  applicationInfrastructure,
  localization,
  serialization,
  authentication,
  notifications,
  billing,
  operationalErrors,
  localStorage,
  platformUtility,
}

final class AnalyticsRuntimeDependencyInventoryEntry {
  const AnalyticsRuntimeDependencyInventoryEntry(
    this.packageName,
    this.purpose,
  );

  final String packageName;
  final AnalyticsRuntimeDependencyPurpose purpose;
}

abstract final class AnalyticsSdkInventory {
  static const List<AnalyticsRuntimeDependencyInventoryEntry>
  directRuntimeDependencies = <AnalyticsRuntimeDependencyInventoryEntry>[
    AnalyticsRuntimeDependencyInventoryEntry(
      'firebase_core',
      AnalyticsRuntimeDependencyPurpose.notifications,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'firebase_messaging',
      AnalyticsRuntimeDependencyPurpose.notifications,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'flutter',
      AnalyticsRuntimeDependencyPurpose.framework,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'flutter_local_notifications',
      AnalyticsRuntimeDependencyPurpose.notifications,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'flutter_localizations',
      AnalyticsRuntimeDependencyPurpose.localization,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'flutter_web_plugins',
      AnalyticsRuntimeDependencyPurpose.framework,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'flutter_riverpod',
      AnalyticsRuntimeDependencyPurpose.applicationInfrastructure,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'flutter_secure_storage',
      AnalyticsRuntimeDependencyPurpose.localStorage,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'freezed_annotation',
      AnalyticsRuntimeDependencyPurpose.serialization,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'go_router',
      AnalyticsRuntimeDependencyPurpose.applicationInfrastructure,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'google_sign_in',
      AnalyticsRuntimeDependencyPurpose.authentication,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'intl',
      AnalyticsRuntimeDependencyPurpose.localization,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'json_annotation',
      AnalyticsRuntimeDependencyPurpose.serialization,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'package_info_plus',
      AnalyticsRuntimeDependencyPurpose.platformUtility,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'purchases_flutter',
      AnalyticsRuntimeDependencyPurpose.billing,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'sentry_flutter',
      AnalyticsRuntimeDependencyPurpose.operationalErrors,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'supabase_flutter',
      AnalyticsRuntimeDependencyPurpose.authentication,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'timezone',
      AnalyticsRuntimeDependencyPurpose.platformUtility,
    ),
    AnalyticsRuntimeDependencyInventoryEntry(
      'url_launcher',
      AnalyticsRuntimeDependencyPurpose.platformUtility,
    ),
  ];

  static const Set<String> forbiddenUnreviewedPackages = <String>{
    'firebase_analytics',
    'google_mobile_ads',
    'app_tracking_transparency',
    'appsflyer_sdk',
    'adjust_sdk',
    'amplitude_flutter',
    'mixpanel_flutter',
    'facebook_app_events',
  };
}
