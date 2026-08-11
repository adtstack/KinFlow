import 'dart:async';

import 'package:kinflow_app/features/household/domain/entities/active_household.dart';
import 'package:kinflow_app/features/notifications/application/notification_endpoint_lifecycle.dart';
import 'package:kinflow_app/features/notifications/application/ports/notification_push_gateway.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_endpoint_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_endpoint_repository.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';

abstract interface class NotificationPushCoordinatorService {
  NotificationPushState get state;

  Stream<NotificationPushState> get states;

  Stream<NotificationPushNavigationIntent> get navigationIntents;

  Future<void> start();

  Future<void> synchronize({
    required ActiveHousehold? activeHousehold,
    required String? locale,
  });

  void updatePresentationContent(NotificationPushPresentationContent content);

  Future<void> requestPermission();

  Future<void> refreshPermission();

  Future<bool> openSystemSettings();

  Future<void> dispose();
}

final class NotificationPushCoordinator
    implements NotificationPushCoordinatorService {
  NotificationPushCoordinator({
    required NotificationPushGateway gateway,
    required this._localPresenter,
    required this._notificationRepository,
    required this._endpointLifecycle,
    required this._appVersion,
    this.runtimeVersion = 'Flutter 3.44.7',
  }) : _gateway = gateway,
       _state = NotificationPushState(
         permission: gateway.isAvailable
             ? NotificationPushPermission.notDetermined
             : NotificationPushPermission.unavailable,
         busy: false,
         permissionRequestAttempted: false,
         endpointRegistered: false,
         failure: null,
       );

  static const int _dedupeCapacity = 64;

  final NotificationPushGateway _gateway;
  final NotificationLocalPresenter _localPresenter;
  final NotificationRepository _notificationRepository;
  final NotificationEndpointLifecycleService _endpointLifecycle;
  final String _appVersion;
  final String runtimeVersion;
  final StreamController<NotificationPushState> _states =
      StreamController<NotificationPushState>.broadcast(sync: true);
  final StreamController<NotificationPushNavigationIntent> _navigation =
      StreamController<NotificationPushNavigationIntent>.broadcast(sync: true);
  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];
  final Set<String> _presentedDeliveryIds = <String>{};
  final Set<String> _handledDeliveryIds = <String>{};
  final List<String> _presentedOrder = <String>[];
  final List<String> _handledOrder = <String>[];

  NotificationPushState _state;
  Future<void> _operationTail = Future<void>.value();
  ActiveHousehold? _activeHousehold;
  String? _locale;
  String? _lastProviderToken;
  String? _lastBindingHouseholdId;
  String? _lastBindingTimezone;
  ActiveHousehold? _lastDeniedPurgeBinding;
  NotificationPushEnvelope? _pendingOpen;
  NotificationPushPresentationContent? _presentationContent;
  bool _started = false;
  bool _disposed = false;

  @override
  NotificationPushState get state => _state;

  @override
  Stream<NotificationPushState> get states => _states.stream;

  @override
  Stream<NotificationPushNavigationIntent> get navigationIntents =>
      _navigation.stream;

  @override
  Future<void> start() {
    return _enqueue(() async {
      if (_started || _disposed) return;
      _started = true;
      if (!_gateway.isAvailable) {
        _emit(
          permission: NotificationPushPermission.unavailable,
          busy: false,
          endpointRegistered: false,
          failure: null,
        );
        return;
      }
      _subscriptions
        ..add(
          _gateway.tokenChanges.listen(
            (String token) => unawaited(_enqueue(() => _bind(token: token))),
          ),
        )
        ..add(
          _gateway.foregroundMessages.listen(
            (NotificationPushEnvelope envelope) =>
                unawaited(_enqueue(() => _present(envelope))),
          ),
        )
        ..add(
          _gateway.notificationOpens.listen(
            (NotificationPushEnvelope envelope) =>
                unawaited(_enqueue(() => _queueOpen(envelope))),
          ),
        )
        ..add(
          _localPresenter.notificationOpens.listen(
            (NotificationPushEnvelope envelope) =>
                unawaited(_enqueue(() => _queueOpen(envelope))),
          ),
        );
      await _refreshPermission(bindWhenAuthorized: false);
      NotificationPushEnvelope? remoteInitial;
      try {
        remoteInitial = await _gateway.takeInitialNotification();
      } on Object {
        _emit(
          failure: NotificationPushFailureKind.targetAuthorizationUnavailable,
        );
      }
      if (remoteInitial != null) await _queueOpen(remoteInitial);
      NotificationPushEnvelope? localInitial;
      try {
        localInitial = await _localPresenter.takeInitialNotification();
      } on Object {
        _emit(failure: NotificationPushFailureKind.presentationUnavailable);
      }
      if (localInitial != null) await _queueOpen(localInitial);
      await _bind();
    });
  }

  @override
  Future<void> synchronize({
    required ActiveHousehold? activeHousehold,
    required String? locale,
  }) {
    return _enqueue(() async {
      final ActiveHousehold? previousBinding = _activeHousehold;
      _activeHousehold = activeHousehold;
      _locale = _normalizedLocale(locale);
      if (previousBinding != activeHousehold) {
        _clearBindingMemory();
        _emit(endpointRegistered: false, failure: null);
      }
      if (activeHousehold != null &&
          _state.permission == NotificationPushPermission.denied &&
          _lastDeniedPurgeBinding != activeHousehold) {
        await _deactivateEndpoint();
      }
      await _bind();
      await _resolvePendingOpen();
    });
  }

  @override
  void updatePresentationContent(NotificationPushPresentationContent content) {
    _presentationContent = content;
  }

  @override
  Future<void> requestPermission() {
    return _enqueue(() async {
      if (!_gateway.isAvailable || _disposed) return;
      _emit(busy: true, permissionRequestAttempted: true, failure: null);
      try {
        final NotificationPushPermission permission = await _gateway
            .requestPermission();
        await _applyPermission(permission);
        if (permission == NotificationPushPermission.authorized) {
          await _bind();
        }
      } on Object {
        _emit(
          busy: false,
          failure: NotificationPushFailureKind.permissionUnavailable,
        );
      }
    });
  }

  @override
  Future<void> refreshPermission() {
    return _enqueue(() => _refreshPermission(bindWhenAuthorized: true));
  }

  @override
  Future<bool> openSystemSettings() async {
    if (!_gateway.isAvailable || _disposed) return false;
    try {
      return await _gateway.openSystemSettings();
    } on Object {
      _emit(failure: NotificationPushFailureKind.permissionUnavailable);
      return false;
    }
  }

  Future<void> _refreshPermission({required bool bindWhenAuthorized}) async {
    if (!_gateway.isAvailable || _disposed) return;
    try {
      final NotificationPushPermission permission = await _gateway
          .currentPermission();
      await _applyPermission(permission);
      if (bindWhenAuthorized &&
          permission == NotificationPushPermission.authorized) {
        await _bind();
      }
    } on Object {
      _emit(
        busy: false,
        failure: NotificationPushFailureKind.permissionUnavailable,
      );
    }
  }

  Future<void> _applyPermission(NotificationPushPermission permission) async {
    if (permission != NotificationPushPermission.denied) {
      _lastDeniedPurgeBinding = null;
    }
    final bool alreadyPurgedForBinding =
        _activeHousehold != null && _lastDeniedPurgeBinding == _activeHousehold;
    final bool mustDeactivate =
        permission == NotificationPushPermission.denied &&
        !alreadyPurgedForBinding &&
        (_activeHousehold != null ||
            _state.endpointRegistered ||
            _state.permission == NotificationPushPermission.authorized);
    if (mustDeactivate) {
      final bool deactivated = await _deactivateEndpoint(
        permission: permission,
      );
      if (!deactivated) return;
    }
    _emit(
      permission: permission,
      busy: false,
      endpointRegistered: permission == NotificationPushPermission.authorized
          ? _state.endpointRegistered
          : false,
      failure: null,
    );
  }

  Future<bool> _deactivateEndpoint({
    NotificationPushPermission? permission,
  }) async {
    try {
      await _endpointLifecycle.purgeSensitiveLocalState();
      _clearBindingMemory();
      if ((permission ?? _state.permission) ==
          NotificationPushPermission.denied) {
        _lastDeniedPurgeBinding = _activeHousehold;
      }
      _emit(
        permission: permission,
        busy: false,
        endpointRegistered: false,
        failure: null,
      );
      return true;
    } on Object {
      _clearBindingMemory();
      _emit(
        permission: permission,
        busy: false,
        endpointRegistered: false,
        failure: NotificationPushFailureKind.registrationUnavailable,
      );
      return false;
    }
  }

  Future<void> _bind({String? token}) async {
    try {
      await _bindUnchecked(token: token);
    } on Object {
      _emit(
        busy: false,
        endpointRegistered: false,
        failure: NotificationPushFailureKind.registrationUnavailable,
      );
    }
  }

  Future<void> _bindUnchecked({String? token}) async {
    final ActiveHousehold? activeHousehold = _activeHousehold;
    if (!_started ||
        _disposed ||
        _state.permission != NotificationPushPermission.authorized ||
        activeHousehold == null) {
      return;
    }
    _emit(busy: true, failure: null);
    final NotificationResult<NotificationSnapshot> snapshotResult =
        await _notificationRepository.loadSnapshot(activeHousehold.householdId);
    if (snapshotResult is! NotificationSucceeded<NotificationSnapshot>) {
      _emit(
        busy: false,
        endpointRegistered: false,
        failure: NotificationPushFailureKind.registrationUnavailable,
      );
      return;
    }
    final Set<String> timezones = snapshotResult.value.preferences
        .map((NotificationPreference preference) => preference.timezone)
        .toSet();
    if (timezones.length != 1) {
      _emit(
        busy: false,
        endpointRegistered: false,
        failure: NotificationPushFailureKind.invalidConfiguration,
      );
      return;
    }
    final String? providerToken = token ?? await _gateway.currentToken();
    if (providerToken == null) {
      _emit(
        busy: false,
        endpointRegistered: false,
        failure: NotificationPushFailureKind.tokenUnavailable,
      );
      return;
    }
    final String timezone = timezones.single;
    if (_state.endpointRegistered &&
        _lastProviderToken == providerToken &&
        _lastBindingHouseholdId == activeHousehold.householdId.value &&
        _lastBindingTimezone == timezone) {
      _emit(busy: false, failure: null);
      return;
    }
    final NotificationEndpointRegistrationIntent? intent =
        NotificationEndpointRegistrationIntent.tryCreate(
          householdId: activeHousehold.householdId,
          platform: NotificationEndpointPlatform.android,
          providerToken: providerToken,
          locale: _locale,
          timezone: timezone,
          appVersion: _appVersion,
          runtimeVersion: runtimeVersion,
        );
    if (intent == null) {
      _emit(
        busy: false,
        endpointRegistered: false,
        failure: NotificationPushFailureKind.invalidConfiguration,
      );
      return;
    }
    final NotificationEndpointResult<NotificationEndpointMetadata> result =
        await _endpointLifecycle.register(intent);
    if (result is NotificationEndpointSucceeded<NotificationEndpointMetadata>) {
      _lastProviderToken = providerToken;
      _lastBindingHouseholdId = activeHousehold.householdId.value;
      _lastBindingTimezone = timezone;
      _emit(busy: false, endpointRegistered: true, failure: null);
      return;
    }
    _emit(
      busy: false,
      endpointRegistered: false,
      failure: NotificationPushFailureKind.registrationUnavailable,
    );
  }

  Future<void> _present(NotificationPushEnvelope envelope) async {
    if (!_remember(
      envelope.deliveryId,
      _presentedDeliveryIds,
      _presentedOrder,
    )) {
      return;
    }
    final NotificationPushPresentationContent? content = _presentationContent;
    if (content == null || !_localPresenter.isAvailable) return;
    try {
      await _localPresenter.show(envelope, content);
    } on Object {
      _emit(failure: NotificationPushFailureKind.presentationUnavailable);
    }
  }

  Future<void> _queueOpen(NotificationPushEnvelope envelope) async {
    if (_handledDeliveryIds.contains(envelope.deliveryId)) return;
    _pendingOpen = envelope;
    await _resolvePendingOpen();
  }

  Future<void> _resolvePendingOpen() async {
    final NotificationPushEnvelope? envelope = _pendingOpen;
    final ActiveHousehold? activeHousehold = _activeHousehold;
    if (envelope == null || activeHousehold == null || _disposed) return;
    _pendingOpen = null;
    if (envelope.householdId != activeHousehold.householdId) {
      _navigateFailClosed(envelope);
      return;
    }
    final NotificationResult<NotificationPushTarget?> result;
    try {
      result = await _notificationRepository.resolvePushTarget(envelope);
    } on Object {
      _emit(
        failure: NotificationPushFailureKind.targetAuthorizationUnavailable,
      );
      _navigateFailClosed(envelope);
      return;
    }
    if (result case NotificationSucceeded<NotificationPushTarget?>(
      :final value,
    )) {
      switch (value?.destination) {
        case NotificationPushSafeDestination.choreOccurrence:
          _navigate(
            envelope,
            NotificationPushNavigationDestination.choreOccurrence,
            subjectId: envelope.subjectId,
          );
        case NotificationPushSafeDestination.calendarEvent:
          _navigate(
            envelope,
            NotificationPushNavigationDestination.calendarEvent,
            subjectId: envelope.subjectId,
          );
        case null:
          _navigateFailClosed(envelope);
      }
      return;
    }
    _emit(failure: NotificationPushFailureKind.targetAuthorizationUnavailable);
    _navigateFailClosed(envelope);
  }

  void _navigateFailClosed(NotificationPushEnvelope envelope) {
    _navigate(
      envelope,
      NotificationPushNavigationDestination.notificationCenter,
    );
  }

  void _navigate(
    NotificationPushEnvelope envelope,
    NotificationPushNavigationDestination destination, {
    String? subjectId,
  }) {
    if (!_remember(envelope.deliveryId, _handledDeliveryIds, _handledOrder)) {
      return;
    }
    if (!_navigation.isClosed) {
      _navigation.add(
        NotificationPushNavigationIntent(
          destination: destination,
          deliveryId: envelope.deliveryId,
          subjectId: subjectId,
        ),
      );
    }
  }

  bool _remember(String id, Set<String> ids, List<String> order) {
    if (!ids.add(id)) return false;
    order.add(id);
    if (order.length > _dedupeCapacity) {
      ids.remove(order.removeAt(0));
    }
    return true;
  }

  void _clearBindingMemory() {
    _lastProviderToken = null;
    _lastBindingHouseholdId = null;
    _lastBindingTimezone = null;
  }

  String? _normalizedLocale(String? value) {
    if (value == null) return null;
    final String normalized = value.trim();
    return RegExp(
          r'^[A-Za-z]{2,3}(?:[-_][A-Za-z0-9]{2,8})*$',
        ).hasMatch(normalized)
        ? normalized
        : null;
  }

  void _emit({
    NotificationPushPermission? permission,
    bool? busy,
    bool? permissionRequestAttempted,
    bool? endpointRegistered,
    Object? failure = _preserveFailure,
  }) {
    if (_disposed) return;
    _state = NotificationPushState(
      permission: permission ?? _state.permission,
      busy: busy ?? _state.busy,
      permissionRequestAttempted:
          permissionRequestAttempted ?? _state.permissionRequestAttempted,
      endpointRegistered: endpointRegistered ?? _state.endpointRegistered,
      failure: identical(failure, _preserveFailure)
          ? _state.failure
          : failure as NotificationPushFailureKind?,
    );
    if (!_states.isClosed) _states.add(_state);
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final Completer<void> completer = Completer<void>();
    _operationTail = _operationTail.then((_) async {
      try {
        await operation();
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final StreamSubscription<Object?> subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _gateway.dispose();
    await _localPresenter.dispose();
    await _states.close();
    await _navigation.close();
    _clearBindingMemory();
  }
}

const Object _preserveFailure = Object();

final class UnavailableNotificationPushCoordinator
    implements NotificationPushCoordinatorService {
  const UnavailableNotificationPushCoordinator();

  static const NotificationPushState _state =
      NotificationPushState.unavailable();

  @override
  NotificationPushState get state => _state;

  @override
  Stream<NotificationPushState> get states =>
      const Stream<NotificationPushState>.empty();

  @override
  Stream<NotificationPushNavigationIntent> get navigationIntents =>
      const Stream<NotificationPushNavigationIntent>.empty();

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
  Future<void> requestPermission() async {}

  @override
  Future<void> refreshPermission() async {}

  @override
  Future<bool> openSystemSettings() async => false;

  @override
  Future<void> dispose() async {}
}
