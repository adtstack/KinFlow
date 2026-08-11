import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/notifications/application/notification_push_coordinator.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_registry.dart';
import 'package:kinflow_app/features/platform_capabilities/presentation/providers/platform_capability_providers.dart';
import 'package:kinflow_app/features/platform_capabilities/presentation/screens/platform_capabilities_screen.dart';
import 'package:kinflow_app/features/settings/presentation/providers/household_privacy_providers.dart';
import 'package:kinflow_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

void main() {
  testWidgets('shows the exact capability set and provider-safe local copy', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, snapshot: _availableSnapshot());

    for (final PlatformCapabilityId id in PlatformCapabilityId.values) {
      expect(
        find.byKey(Key('platformCapabilities.${id.wireValue}')),
        findsOneWidget,
      );
    }
    expect(find.text('Supported', findRichText: true), findsNWidgets(4));
    expect(find.text('Limited by design', findRichText: true), findsOneWidget);
    expect(find.text('Firebase Messaging for Android'), findsOneWidget);
    expect(find.text('RevenueCat with Google Play'), findsOneWidget);
    expect(find.text('Android Keystore-backed storage'), findsOneWidget);
    expect(find.textContaining('server connectivity'), findsOneWidget);
    expect(find.textContaining('apiKey'), findsNothing);
    expect(find.textContaining('provider_exception'), findsNothing);
    expect(find.textContaining('household-id'), findsNothing);
  });

  testWidgets('denied notification state explains fallback and opens inbox', (
    WidgetTester tester,
  ) async {
    final PlatformCapabilitySnapshot snapshot =
        const PlatformCapabilityRegistry.android(
          notificationAdapterComposed: true,
          billingPortAvailable: true,
          secureLocalStorageComposed: true,
          externalUriLauncherComposed: true,
        ).resolve(
          notificationSignal: PlatformNotificationCapabilitySignal.denied,
        );
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.deviceCapabilities,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.deviceCapabilities,
          builder: (BuildContext context, GoRouterState state) =>
              const PlatformCapabilitiesScreen(),
        ),
        GoRoute(
          path: AppRoutes.notifications,
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox(key: Key('notifications.routeTarget')),
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox(key: Key('settings.routeTarget')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _pumpRouter(tester, router: router, snapshot: snapshot);

    expect(find.text('Action needed', findRichText: true), findsOneWidget);
    expect(find.textContaining('turned off'), findsOneWidget);
    expect(find.text('Durable in-app notification inbox'), findsOneWidget);

    final Finder action = find.byKey(
      const Key('platformCapabilities.action.notification_delivery'),
    );
    await tester.ensureVisible(action);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.notifications,
    );
    expect(find.byKey(const Key('notifications.routeTarget')), findsOneWidget);
  });

  testWidgets('unavailable build names every fallback in Korean', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      snapshot: _unavailableSnapshot(),
      locale: const Locale('ko'),
    );

    expect(find.text('대안 사용 중', findRichText: true), findsNWidgets(5));
    expect(find.text('이 앱 빌드에 구성되지 않음'), findsNWidgets(5));
    expect(find.text('내구성 있는 앱 내 알림함'), findsOneWidget);
    expect(find.text('서버 확인 이용 권한과 읽기 전용 구독 상태'), findsOneWidget);
    expect(find.text('진단 정보 열기'), findsNWidgets(4));
  });

  testWidgets('pseudo locale remains scrollable at 200 percent text', (
    WidgetTester tester,
  ) async {
    _configureView(tester, size: const Size(320, 568), textScaleFactor: 2);
    await _pumpScreen(
      tester,
      snapshot: _unavailableSnapshot(),
      locale: const Locale('en', 'XA'),
      configureDefaultView: false,
    );

    final Finder lastAction = find.byKey(
      const Key('platformCapabilities.action.background_delivery'),
    );
    await tester.ensureVisible(lastAction);
    await tester.pump();
    expect(tester.getSize(lastAction).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings tile opens the protected capability route', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoutes.settings,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.settings,
          builder: (BuildContext context, GoRouterState state) =>
              const SettingsScreen(),
        ),
        GoRoute(
          path: AppRoutes.deviceCapabilities,
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox(key: Key('capabilities.routeTarget')),
        ),
      ],
    );
    addTearDown(router.dispose);
    _configureView(tester, size: const Size(800, 1400), textScaleFactor: 1);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdPrivacyOwnerVisibilityProvider.overrideWith(
            (ref) async => false,
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder tile = find.byKey(const Key('settings.deviceCapabilities'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(
      router.routeInformationProvider.value.uri.path,
      AppRoutes.deviceCapabilities,
    );
    expect(find.byKey(const Key('capabilities.routeTarget')), findsOneWidget);
  });

  testWidgets('summarizes and orders non-ready recovery steps', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, snapshot: _mixedSnapshot());

    expect(find.text('1 ready'), findsOneWidget);
    expect(find.text('2 need attention'), findsOneWidget);
    expect(find.text('2 use a fallback or limitation'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(
          const Key('platformCapabilities.recovery.notification_delivery'),
        ),
        matching: find.text('Step 1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const Key('platformCapabilities.recovery.secure_local_storage'),
        ),
        matching: find.text('Step 2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const Key('platformCapabilities.recovery.store_billing'),
        ),
        matching: find.text('Step 3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(
          const Key('platformCapabilities.recovery.background_delivery'),
        ),
        matching: find.text('Step 4'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('self-check is single-flight and immediately recomputes plan', (
    WidgetTester tester,
  ) async {
    final Completer<void> gate = Completer<void>();
    final _FakeSelfCheckCoordinator coordinator = _FakeSelfCheckCoordinator(
      initialState: _pushState(NotificationPushPermission.denied),
      refreshedState: _pushState(NotificationPushPermission.authorized),
      refreshGate: gate,
    );
    await _pumpLiveCapabilityScreen(tester, coordinator: coordinator);

    expect(find.text('3 ready'), findsOneWidget);
    expect(find.text('1 need attention'), findsOneWidget);

    final Finder refresh = find.byKey(
      const Key('platformCapabilities.selfCheck.refresh'),
    );
    await tester.tap(refresh);
    await tester.tap(refresh);
    await tester.pump();

    expect(coordinator.refreshCount, 1);
    expect(tester.widget<FilledButton>(refresh).onPressed, isNull);
    expect(find.text('Checking notification setup…'), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();

    expect(find.text('4 ready'), findsOneWidget);
    expect(find.text('0 need attention'), findsOneWidget);
    expect(
      find.text(
        'Notification permission and device binding status were checked again.',
      ),
      findsOneWidget,
    );
    expect(coordinator.requestCount, 0);
    expect(coordinator.openSettingsCount, 0);
  });

  testWidgets('self-check failure stays stable and keeps fallbacks visible', (
    WidgetTester tester,
  ) async {
    final _FakeSelfCheckCoordinator coordinator = _FakeSelfCheckCoordinator(
      initialState: _pushState(NotificationPushPermission.denied),
      refreshFailure: Exception('provider-secret-detail'),
    );
    await _pumpLiveCapabilityScreen(tester, coordinator: coordinator);

    final Finder refresh = find.byKey(
      const Key('platformCapabilities.selfCheck.refresh'),
    );
    await tester.tap(refresh);
    await tester.pumpAndSettle();

    expect(coordinator.refreshCount, 1);
    expect(
      find.textContaining('could not be checked right now'),
      findsOneWidget,
    );
    expect(find.textContaining('provider-secret-detail'), findsNothing);
    expect(find.text('Durable in-app notification inbox'), findsOneWidget);
  });
}

PlatformCapabilitySnapshot _availableSnapshot() {
  return const PlatformCapabilityRegistry.android(
    notificationAdapterComposed: true,
    billingPortAvailable: true,
    secureLocalStorageComposed: true,
    externalUriLauncherComposed: true,
  ).resolve(
    notificationSignal: PlatformNotificationCapabilitySignal.authorized,
  );
}

PlatformCapabilitySnapshot _unavailableSnapshot() {
  return const PlatformCapabilityRegistry.unavailable().resolve(
    notificationSignal: PlatformNotificationCapabilitySignal.unavailable,
  );
}

PlatformCapabilitySnapshot _mixedSnapshot() {
  return PlatformCapabilitySnapshot.tryCreate(const <PlatformCapabilityStatus>[
    PlatformCapabilityStatus(
      id: PlatformCapabilityId.notificationDelivery,
      provider: PlatformCapabilityProvider.firebaseMessagingAndroid,
      fallback: PlatformCapabilityFallback.inAppInbox,
      state: PlatformCapabilitySupportState.temporaryIssue,
      reason: PlatformCapabilityReason.providerTemporarilyUnavailable,
      action: PlatformCapabilityAction.openNotificationCenter,
    ),
    PlatformCapabilityStatus(
      id: PlatformCapabilityId.storeBilling,
      provider: PlatformCapabilityProvider.unavailable,
      fallback: PlatformCapabilityFallback.serverEntitlementReadOnly,
      state: PlatformCapabilitySupportState.fallbackOnly,
      reason: PlatformCapabilityReason.providerNotConfigured,
      action: PlatformCapabilityAction.openSubscriptionSettings,
    ),
    PlatformCapabilityStatus(
      id: PlatformCapabilityId.secureLocalStorage,
      provider: PlatformCapabilityProvider.androidKeystore,
      fallback: PlatformCapabilityFallback.reauthenticateWithoutPersistentCache,
      state: PlatformCapabilitySupportState.actionRequired,
      reason: PlatformCapabilityReason.permissionDenied,
      action: PlatformCapabilityAction.openDiagnostics,
    ),
    PlatformCapabilityStatus(
      id: PlatformCapabilityId.externalLinks,
      provider: PlatformCapabilityProvider.androidSystemUriLauncher,
      fallback: PlatformCapabilityFallback.onScreenGuidanceAndDiagnostics,
      state: PlatformCapabilitySupportState.available,
      reason: PlatformCapabilityReason.providerReady,
      action: PlatformCapabilityAction.none,
    ),
    PlatformCapabilityStatus(
      id: PlatformCapabilityId.backgroundDelivery,
      provider: PlatformCapabilityProvider.firebaseBackgroundMessageHandler,
      fallback:
          PlatformCapabilityFallback.serverNotificationPipelineAndInAppInbox,
      state: PlatformCapabilitySupportState.limited,
      reason: PlatformCapabilityReason.serverAuthoritative,
      action: PlatformCapabilityAction.openNotificationCenter,
    ),
  ])!;
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required PlatformCapabilitySnapshot snapshot,
  Locale locale = const Locale('en'),
  bool configureDefaultView = true,
}) async {
  if (configureDefaultView) {
    _configureView(tester, size: const Size(800, 1400), textScaleFactor: 1);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformCapabilitySnapshotProvider.overrideWithValue(snapshot),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PlatformCapabilitiesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpRouter(
  WidgetTester tester, {
  required GoRouter router,
  required PlatformCapabilitySnapshot snapshot,
}) async {
  _configureView(tester, size: const Size(800, 1400), textScaleFactor: 1);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformCapabilitySnapshotProvider.overrideWithValue(snapshot),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLiveCapabilityScreen(
  WidgetTester tester, {
  required _FakeSelfCheckCoordinator coordinator,
}) async {
  _configureView(tester, size: const Size(800, 1400), textScaleFactor: 1);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformCapabilityRegistryProvider.overrideWithValue(
          const PlatformCapabilityRegistry.android(
            notificationAdapterComposed: true,
            billingPortAvailable: true,
            secureLocalStorageComposed: true,
            externalUriLauncherComposed: true,
          ),
        ),
        notificationPushCoordinatorProvider.overrideWithValue(coordinator),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PlatformCapabilitiesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _configureView(
  WidgetTester tester, {
  required Size size,
  required double textScaleFactor,
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

NotificationPushState _pushState(NotificationPushPermission permission) {
  return NotificationPushState(
    permission: permission,
    busy: false,
    permissionRequestAttempted:
        permission != NotificationPushPermission.notDetermined,
    endpointRegistered: permission == NotificationPushPermission.authorized,
    failure: null,
  );
}

final class _FakeSelfCheckCoordinator
    implements NotificationPushCoordinatorService {
  _FakeSelfCheckCoordinator({
    required NotificationPushState initialState,
    this.refreshedState,
    this.refreshGate,
    this.refreshFailure,
  }) : _state = initialState,
       assert(refreshFailure == null || refreshedState == null);

  final StreamController<NotificationPushState> _states =
      StreamController<NotificationPushState>.broadcast(sync: true);
  final StreamController<NotificationPushNavigationIntent> _navigation =
      StreamController<NotificationPushNavigationIntent>.broadcast(sync: true);
  final NotificationPushState? refreshedState;
  final Completer<void>? refreshGate;
  final Exception? refreshFailure;
  NotificationPushState _state;
  int refreshCount = 0;
  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  NotificationPushState get state => _state;

  @override
  Stream<NotificationPushState> get states => _states.stream;

  @override
  Stream<NotificationPushNavigationIntent> get navigationIntents =>
      _navigation.stream;

  @override
  Future<void> start() async {}

  @override
  Future<void> synchronize({
    required ActiveHousehold? activeHousehold,
    required String? locale,
  }) async {}

  @override
  void updatePresentationContent(NotificationPushPresentationContent content) {}

  @override
  Future<void> requestPermission() async {
    requestCount += 1;
  }

  @override
  Future<void> refreshPermission() async {
    refreshCount += 1;
    if (refreshGate case final gate?) await gate.future;
    if (refreshFailure case final failure?) throw failure;
    if (refreshedState case final state?) {
      _state = state;
      _states.add(state);
    }
  }

  @override
  Future<bool> openSystemSettings() async {
    openSettingsCount += 1;
    return true;
  }

  @override
  Future<void> dispose() async {
    await _states.close();
    await _navigation.close();
  }
}
