import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/notifications/application/notification_endpoint_lifecycle.dart';
import 'package:kinflow_app/features/notifications/application/notification_push_coordinator.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_push_gateway.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';

import '../../support/fakes/fake_household_dependencies.dart';
import '../../support/fakes/fake_notification_dependencies.dart';

const String _deliveryOne = '84000000-0000-4000-8000-000000000001';
const String _deliveryTwo = '84000000-0000-4000-8000-000000000002';
const String _sourceEvent = '84010000-0000-4000-8000-000000000001';
const String _inboxItem = '84020000-0000-4000-8000-000000000001';
const String _subject = '84030000-0000-4000-8000-000000000001';
const String _tokenOne = 'fcm:provider-token-value-0123456789';
const String _tokenTwo = 'fcm:rotated-token-value-9876543210';

void main() {
  test('startup reads permission but never prompts or registers', () async {
    final _FakePushGateway gateway = _FakePushGateway(
      permission: NotificationPushPermission.notDetermined,
    );
    final _FakeLocalPresenter presenter = _FakeLocalPresenter();
    final _FakeEndpointLifecycle lifecycle = _FakeEndpointLifecycle();
    final NotificationPushCoordinator coordinator = _coordinator(
      gateway: gateway,
      presenter: presenter,
      lifecycle: lifecycle,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    await coordinator.synchronize(
      activeHousehold: activeHouseholdFixture(),
      locale: 'ko-KR',
    );

    expect(gateway.currentPermissionCount, 1);
    expect(gateway.requestPermissionCount, 0);
    expect(gateway.currentTokenCount, 0);
    expect(lifecycle.intents, isEmpty);
    expect(
      coordinator.state.permission,
      NotificationPushPermission.notDetermined,
    );
  });

  test(
    'explicit refresh never prompts and reconciles grant then revocation',
    () async {
      final _FakePushGateway gateway = _FakePushGateway(
        permission: NotificationPushPermission.notDetermined,
        token: _tokenOne,
      );
      final _FakeEndpointLifecycle lifecycle = _FakeEndpointLifecycle();
      final NotificationPushCoordinator coordinator = _coordinator(
        gateway: gateway,
        presenter: _FakeLocalPresenter(),
        lifecycle: lifecycle,
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();
      await coordinator.synchronize(
        activeHousehold: activeHouseholdFixture(),
        locale: 'ko-KR',
      );

      gateway.permission = NotificationPushPermission.authorized;
      await coordinator.refreshPermission();

      expect(gateway.currentPermissionCount, 2);
      expect(gateway.requestPermissionCount, 0);
      expect(gateway.openSettingsCount, 0);
      expect(lifecycle.intents, hasLength(1));
      expect(coordinator.state.endpointRegistered, isTrue);

      gateway.permission = NotificationPushPermission.denied;
      await coordinator.refreshPermission();

      expect(gateway.currentPermissionCount, 3);
      expect(gateway.requestPermissionCount, 0);
      expect(gateway.openSettingsCount, 0);
      expect(lifecycle.purgeCount, 1);
      expect(coordinator.state.permission, NotificationPushPermission.denied);
      expect(coordinator.state.endpointRegistered, isFalse);
    },
  );

  test(
    'explicit grant binds token and rotation re-registers exactly',
    () async {
      final _FakePushGateway gateway = _FakePushGateway(
        permission: NotificationPushPermission.notDetermined,
        requestedPermission: NotificationPushPermission.authorized,
        token: _tokenOne,
      );
      final _FakeEndpointLifecycle lifecycle = _FakeEndpointLifecycle();
      final NotificationPushCoordinator coordinator = _coordinator(
        gateway: gateway,
        presenter: _FakeLocalPresenter(),
        lifecycle: lifecycle,
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();
      await coordinator.synchronize(
        activeHousehold: activeHouseholdFixture(),
        locale: 'ko-KR',
      );

      await coordinator.requestPermission();
      expect(gateway.requestPermissionCount, 1);
      expect(lifecycle.intents, hasLength(1));
      expect(lifecycle.intents.single.providerToken.value, _tokenOne);
      expect(lifecycle.intents.single.locale, 'ko-KR');
      expect(lifecycle.intents.single.timezone, 'Asia/Seoul');
      expect(lifecycle.intents.single.runtimeVersion, 'Flutter 3.44.7');
      expect(coordinator.state.endpointRegistered, isTrue);

      gateway.emitToken(_tokenTwo);
      await _drain();
      expect(lifecycle.intents, hasLength(2));
      expect(lifecycle.intents.last.providerToken.value, _tokenTwo);

      gateway.emitToken(_tokenTwo);
      await _drain();
      expect(lifecycle.intents, hasLength(2));
    },
  );

  test('member switch in the same household rebinds the endpoint', () async {
    final _FakePushGateway gateway = _FakePushGateway(
      permission: NotificationPushPermission.authorized,
      token: _tokenOne,
    );
    final _FakeEndpointLifecycle lifecycle = _FakeEndpointLifecycle();
    final NotificationPushCoordinator coordinator = _coordinator(
      gateway: gateway,
      presenter: _FakeLocalPresenter(),
      lifecycle: lifecycle,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    final active = activeHouseholdFixture();
    await coordinator.synchronize(activeHousehold: active, locale: 'ko-KR');
    await coordinator.synchronize(
      activeHousehold: activeHouseholdFixture(
        householdId: active.householdId.value,
        memberId: '33333333-3333-4333-8333-333333333334',
      ),
      locale: 'ko-KR',
    );

    expect(lifecycle.intents, hasLength(2));
  });

  test('foreground delivery is generic and deduplicated by delivery', () async {
    final _FakePushGateway gateway = _FakePushGateway(
      permission: NotificationPushPermission.notDetermined,
    );
    final _FakeLocalPresenter presenter = _FakeLocalPresenter();
    final NotificationPushCoordinator coordinator = _coordinator(
      gateway: gateway,
      presenter: presenter,
      lifecycle: _FakeEndpointLifecycle(),
    );
    addTearDown(coordinator.dispose);
    coordinator.updatePresentationContent(_content());
    await coordinator.start();
    final NotificationPushEnvelope envelope = _envelope(_deliveryOne);

    gateway.emitForeground(envelope);
    gateway.emitForeground(envelope);
    await _drain();

    expect(presenter.shown, <NotificationPushEnvelope>[envelope]);
    expect(presenter.contents.single.title, 'KinFlow reminder');
  });

  test(
    'terminated tap waits for auth then preserves the authorized Chore target',
    () async {
      final NotificationPushEnvelope envelope = _envelope(_deliveryOne);
      final NotificationPushTarget target = _target(envelope);
      final FakeNotificationRepository repository = FakeNotificationRepository(
        targetResults: <NotificationResult<NotificationPushTarget?>>[
          NotificationSucceeded<NotificationPushTarget?>(target),
        ],
      );
      final _FakePushGateway gateway = _FakePushGateway(
        permission: NotificationPushPermission.notDetermined,
        initial: envelope,
      );
      final NotificationPushCoordinator coordinator = _coordinator(
        gateway: gateway,
        presenter: _FakeLocalPresenter(),
        lifecycle: _FakeEndpointLifecycle(),
        repository: repository,
      );
      final List<NotificationPushNavigationIntent> navigation =
          <NotificationPushNavigationIntent>[];
      final StreamSubscription<NotificationPushNavigationIntent> subscription =
          coordinator.navigationIntents.listen(navigation.add);
      addTearDown(subscription.cancel);
      addTearDown(coordinator.dispose);

      await coordinator.start();
      expect(navigation, isEmpty);

      await coordinator.synchronize(
        activeHousehold: activeHouseholdFixture(),
        locale: 'en-US',
      );
      expect(repository.resolvedPushEnvelopes, <NotificationPushEnvelope>[
        envelope,
      ]);
      expect(
        navigation.single.destination,
        NotificationPushNavigationDestination.choreOccurrence,
      );
      expect(navigation.single.subjectId, _subject);

      gateway.emitOpen(envelope);
      await _drain();
      expect(navigation, hasLength(1));
    },
  );

  test('different household or failed authorization routes to inbox', () async {
    final NotificationPushEnvelope differentHousehold = _envelope(
      _deliveryTwo,
      householdId: '22222222-2222-4222-8222-222222222223',
    );
    final FakeNotificationRepository repository = FakeNotificationRepository();
    final _FakePushGateway gateway = _FakePushGateway(
      permission: NotificationPushPermission.notDetermined,
    );
    final NotificationPushCoordinator coordinator = _coordinator(
      gateway: gateway,
      presenter: _FakeLocalPresenter(),
      lifecycle: _FakeEndpointLifecycle(),
      repository: repository,
    );
    final List<NotificationPushNavigationIntent> navigation =
        <NotificationPushNavigationIntent>[];
    final StreamSubscription<NotificationPushNavigationIntent> subscription =
        coordinator.navigationIntents.listen(navigation.add);
    addTearDown(subscription.cancel);
    addTearDown(coordinator.dispose);
    await coordinator.start();
    await coordinator.synchronize(
      activeHousehold: activeHouseholdFixture(),
      locale: 'ko-KR',
    );

    gateway.emitOpen(differentHousehold);
    await _drain();

    expect(repository.resolvedPushEnvelopes, isEmpty);
    expect(
      navigation.single.destination,
      NotificationPushNavigationDestination.notificationCenter,
    );
  });

  test(
    'authorized Calendar tap preserves the Calendar occurrence target',
    () async {
      final NotificationPushEnvelope envelope = _envelope(
        _deliveryTwo,
        calendar: true,
      );
      final FakeNotificationRepository repository = FakeNotificationRepository(
        targetResults: <NotificationResult<NotificationPushTarget?>>[
          NotificationSucceeded<NotificationPushTarget?>(_target(envelope)),
        ],
      );
      final _FakePushGateway gateway = _FakePushGateway(
        permission: NotificationPushPermission.notDetermined,
      );
      final NotificationPushCoordinator coordinator = _coordinator(
        gateway: gateway,
        presenter: _FakeLocalPresenter(),
        lifecycle: _FakeEndpointLifecycle(),
        repository: repository,
      );
      final List<NotificationPushNavigationIntent> navigation =
          <NotificationPushNavigationIntent>[];
      final StreamSubscription<NotificationPushNavigationIntent> subscription =
          coordinator.navigationIntents.listen(navigation.add);
      addTearDown(subscription.cancel);
      addTearDown(coordinator.dispose);
      await coordinator.start();
      await coordinator.synchronize(
        activeHousehold: activeHouseholdFixture(),
        locale: 'en-US',
      );

      gateway.emitOpen(envelope);
      await _drain();

      expect(
        navigation.single.destination,
        NotificationPushNavigationDestination.calendarEvent,
      );
      expect(navigation.single.subjectId, _subject);
    },
  );

  test(
    'denial exposes settings and revocation purges a bound endpoint',
    () async {
      final _FakePushGateway gateway = _FakePushGateway(
        permission: NotificationPushPermission.authorized,
        requestedPermission: NotificationPushPermission.denied,
        token: _tokenOne,
      );
      final _FakeEndpointLifecycle lifecycle = _FakeEndpointLifecycle();
      final NotificationPushCoordinator coordinator = _coordinator(
        gateway: gateway,
        presenter: _FakeLocalPresenter(),
        lifecycle: lifecycle,
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();
      await coordinator.synchronize(
        activeHousehold: activeHouseholdFixture(),
        locale: 'ko-KR',
      );
      expect(coordinator.state.endpointRegistered, isTrue);

      await coordinator.requestPermission();
      expect(coordinator.state.permission, NotificationPushPermission.denied);
      expect(coordinator.state.permissionRequestAttempted, isTrue);
      expect(coordinator.state.endpointRegistered, isFalse);
      expect(lifecycle.purgeCount, 1);

      expect(await coordinator.openSystemSettings(), isTrue);
      expect(gateway.openSettingsCount, 1);
    },
  );

  test(
    'provider token failure remains a safe state instead of escaping',
    () async {
      final _FakePushGateway gateway = _FakePushGateway(
        permission: NotificationPushPermission.authorized,
        tokenFailure: true,
      );
      final NotificationPushCoordinator coordinator = _coordinator(
        gateway: gateway,
        presenter: _FakeLocalPresenter(),
        lifecycle: _FakeEndpointLifecycle(),
      );
      addTearDown(coordinator.dispose);

      await coordinator.start();
      await coordinator.synchronize(
        activeHousehold: activeHouseholdFixture(),
        locale: 'ko-KR',
      );

      expect(
        coordinator.state.failure,
        NotificationPushFailureKind.registrationUnavailable,
      );
      expect(coordinator.state.endpointRegistered, isFalse);
    },
  );

  test('startup denial removes a stored binding after auth resolves', () async {
    final _FakePushGateway gateway = _FakePushGateway(
      permission: NotificationPushPermission.denied,
    );
    final _FakeEndpointLifecycle lifecycle = _FakeEndpointLifecycle();
    final NotificationPushCoordinator coordinator = _coordinator(
      gateway: gateway,
      presenter: _FakeLocalPresenter(),
      lifecycle: lifecycle,
    );
    addTearDown(coordinator.dispose);

    await coordinator.start();
    expect(lifecycle.purgeCount, 0);
    await coordinator.synchronize(
      activeHousehold: activeHouseholdFixture(),
      locale: 'ko-KR',
    );
    await coordinator.synchronize(
      activeHousehold: activeHouseholdFixture(),
      locale: 'ko-KR',
    );

    expect(lifecycle.purgeCount, 1);
    expect(coordinator.state.endpointRegistered, isFalse);
  });
}

NotificationPushCoordinator _coordinator({
  required _FakePushGateway gateway,
  required _FakeLocalPresenter presenter,
  required _FakeEndpointLifecycle lifecycle,
  FakeNotificationRepository? repository,
}) {
  return NotificationPushCoordinator(
    gateway: gateway,
    localPresenter: presenter,
    notificationRepository: repository ?? FakeNotificationRepository(),
    endpointLifecycle: lifecycle,
    appVersion: '0.1.0-dev+1',
  );
}

NotificationPushEnvelope _envelope(
  String deliveryId, {
  String householdId = notificationHouseholdUuid,
  bool calendar = false,
}) {
  return NotificationPushEnvelope.tryParse(<String, Object?>{
    'category': calendar ? 'calendar_event' : 'chore_due',
    'contractVersion': notificationPushContractVersion,
    'deliveryId': deliveryId,
    'householdId': householdId,
    'inboxItemId': _inboxItem,
    'sourceEventId': _sourceEvent,
    'subjectId': _subject,
    'subjectType': calendar ? 'calendar_occurrence' : 'chore_occurrence',
  })!;
}

NotificationPushTarget _target(NotificationPushEnvelope envelope) {
  return NotificationPushTarget.tryCreate(
    envelope: envelope,
    deliveryId: envelope.deliveryId,
    householdId: envelope.householdId.value,
    category: envelope.category.wireValue,
    subjectType: envelope.category.subjectType,
    subjectId: envelope.subjectId,
    inboxItemId: envelope.inboxItemId?.value,
    safeDestination: envelope.category.subjectType == 'chore_occurrence'
        ? 'chore_occurrence'
        : 'calendar_event',
  )!;
}

NotificationPushPresentationContent _content() {
  return NotificationPushPresentationContent.tryCreate(
    title: 'KinFlow reminder',
    body: 'Open KinFlow to view the latest household update.',
    channelName: 'Household reminders',
    channelDescription: 'Generic reminders without private details',
  )!;
}

Future<void> _drain() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final class _FakePushGateway implements NotificationPushGateway {
  _FakePushGateway({
    required this.permission,
    this.requestedPermission,
    this.token,
    this.initial,
    this.tokenFailure = false,
  });

  NotificationPushPermission permission;
  final NotificationPushPermission? requestedPermission;
  final String? token;
  final NotificationPushEnvelope? initial;
  final bool tokenFailure;
  final StreamController<String> _tokens = StreamController<String>.broadcast(
    sync: true,
  );
  final StreamController<NotificationPushEnvelope> _foreground =
      StreamController<NotificationPushEnvelope>.broadcast(sync: true);
  final StreamController<NotificationPushEnvelope> _opens =
      StreamController<NotificationPushEnvelope>.broadcast(sync: true);
  var currentPermissionCount = 0;
  var requestPermissionCount = 0;
  var currentTokenCount = 0;
  var openSettingsCount = 0;
  var initialConsumed = false;

  @override
  bool get isAvailable => true;

  @override
  Stream<String> get tokenChanges => _tokens.stream;

  @override
  Stream<NotificationPushEnvelope> get foregroundMessages => _foreground.stream;

  @override
  Stream<NotificationPushEnvelope> get notificationOpens => _opens.stream;

  @override
  Future<NotificationPushPermission> currentPermission() async {
    currentPermissionCount += 1;
    return permission;
  }

  @override
  Future<NotificationPushPermission> requestPermission() async {
    requestPermissionCount += 1;
    permission = requestedPermission ?? permission;
    return permission;
  }

  @override
  Future<String?> currentToken() async {
    currentTokenCount += 1;
    if (tokenFailure) throw StateError('private provider failure');
    return token;
  }

  @override
  Future<NotificationPushEnvelope?> takeInitialNotification() async {
    if (initialConsumed) return null;
    initialConsumed = true;
    return initial;
  }

  @override
  Future<bool> openSystemSettings() async {
    openSettingsCount += 1;
    return true;
  }

  void emitToken(String value) => _tokens.add(value);

  void emitForeground(NotificationPushEnvelope envelope) =>
      _foreground.add(envelope);

  void emitOpen(NotificationPushEnvelope envelope) => _opens.add(envelope);

  @override
  Future<void> dispose() async {
    await _tokens.close();
    await _foreground.close();
    await _opens.close();
  }
}

final class _FakeLocalPresenter implements NotificationLocalPresenter {
  final StreamController<NotificationPushEnvelope> _opens =
      StreamController<NotificationPushEnvelope>.broadcast(sync: true);
  final List<NotificationPushEnvelope> shown = <NotificationPushEnvelope>[];
  final List<NotificationPushPresentationContent> contents =
      <NotificationPushPresentationContent>[];

  @override
  bool get isAvailable => true;

  @override
  Stream<NotificationPushEnvelope> get notificationOpens => _opens.stream;

  @override
  Future<NotificationPushEnvelope?> takeInitialNotification() async => null;

  @override
  Future<void> show(
    NotificationPushEnvelope envelope,
    NotificationPushPresentationContent content,
  ) async {
    shown.add(envelope);
    contents.add(content);
  }

  @override
  Future<void> dispose() => _opens.close();
}

final class _FakeEndpointLifecycle
    implements NotificationEndpointLifecycleService {
  final List<NotificationEndpointRegistrationIntent> intents =
      <NotificationEndpointRegistrationIntent>[];
  var purgeCount = 0;

  @override
  Future<NotificationEndpointResult<NotificationEndpointMetadata>> register(
    NotificationEndpointRegistrationIntent intent,
  ) async {
    intents.add(intent);
    return NotificationEndpointSucceeded<NotificationEndpointMetadata>(
      NotificationEndpointMetadata.tryCreate(
        endpointId: '85000000-0000-4000-8000-000000000001',
        householdId: intent.householdId.value,
        memberId: '33333333-3333-4333-8333-333333333333',
        installationId: '85010000-0000-4000-8000-000000000001',
        channel: 'native_push',
        platform: 'android',
        permissionState: 'granted',
        locale: intent.locale,
        timezone: intent.timezone,
        appVersion: intent.appVersion,
        runtimeVersion: intent.runtimeVersion,
        registrationId: '85020000-0000-4000-8000-000000000001',
        lastSeenAt: '2026-08-08T05:00:00Z',
        revokedAt: null,
        revocationReason: null,
        version: intents.length,
      )!,
    );
  }

  @override
  Future<void> purgeSensitiveLocalState() async {
    purgeCount += 1;
  }
}
