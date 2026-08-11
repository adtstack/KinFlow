import 'dart:async';

import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_state.dart';
import 'package:kinflow_app/features/notifications/application/notification_sync_session.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_sync_repository.dart';

typedef NotificationSnoozeIdFactory = NotificationSnoozeCommandId Function();

final class NotificationCenterController {
  factory NotificationCenterController(
    NotificationRepository repository, {
    required NotificationSnoozeIdFactory snoozeIdFactory,
    AuthUserId? authUserId,
    NotificationSyncRepository? syncRepository,
  }) => NotificationCenterController._(
    repository,
    snoozeIdFactory,
    authUserId,
    syncRepository,
  );

  NotificationCenterController._(
    this._repository,
    this.snoozeIdFactory,
    this._authUserId,
    NotificationSyncRepository? syncRepository,
  ) {
    _syncSession = NotificationSyncSession(
      syncRepository,
      _synchronize,
      _setSyncStatus,
    );
  }

  final NotificationRepository _repository;
  final AuthUserId? _authUserId;
  final NotificationSnoozeIdFactory snoozeIdFactory;
  late final NotificationSyncSession _syncSession;
  final StreamController<NotificationCenterState> _states =
      StreamController<NotificationCenterState>.broadcast(sync: true);
  NotificationCenterState _state = const NotificationCenterInitial();
  Future<void> _pending = Future<void>.value();
  var _busy = false;
  var _disposed = false;
  NotificationSnoozeCommandId? _snoozeRetryId;
  NotificationInboxItemId? _snoozeRetryItemId;
  int? _snoozeRetryMinutes;
  var _contextEpoch = 0;
  HouseholdId? _currentHouseholdId;
  HouseholdId? _syncedHouseholdId;
  NotificationSyncConnectionStatus _syncStatus =
      NotificationSyncConnectionStatus.disabled;

  NotificationCenterState get state => _state;

  Stream<NotificationCenterState> get states => _states.stream;

  Future<void> ensureLoaded(HouseholdId householdId) async {
    if (_disposed) {
      return;
    }
    final int requestEpoch = _contextEpoch;
    if (_currentHouseholdId == householdId) {
      if (_busy) {
        await _pending;
      }
      if (_disposed ||
          requestEpoch != _contextEpoch ||
          _currentHouseholdId != householdId) {
        return;
      }
      if (_state is NotificationCenterReady ||
          _state is NotificationCenterLoadFailed) {
        return;
      }
    } else if (_busy) {
      await _pending;
    }
    if (_disposed ||
        requestEpoch != _contextEpoch ||
        _readyFor(householdId) != null) {
      return;
    }
    await load(householdId);
  }

  Future<void> deactivate() async {
    if (_disposed) {
      return;
    }
    _contextEpoch += 1;
    _currentHouseholdId = null;
    _syncedHouseholdId = null;
    _clearSnoozeRetry();
    _emit(const NotificationCenterInitial());
    await _syncSession.stop();
    if (_busy) {
      await _pending;
    }
  }

  Future<void> load(HouseholdId householdId, {bool preserveContent = false}) {
    if (_busy || _disposed) {
      return _pending;
    }
    _busy = true;
    final NotificationCenterReady? ready = _readyFor(householdId);
    final bool householdChanged =
        _currentHouseholdId != null && _currentHouseholdId != householdId;
    if (_currentHouseholdId != householdId) {
      _contextEpoch += 1;
    }
    _currentHouseholdId = householdId;
    final int contextEpoch = _contextEpoch;
    if (preserveContent && ready != null && !householdChanged) {
      _emit(
        NotificationCenterReady(
          ready.snapshot,
          refreshing: true,
          syncStatus: _syncStatus,
        ),
      );
    } else {
      _emit(const NotificationCenterLoading());
    }
    _pending =
        (householdChanged
                ? _stopSyncAndLoad(householdId, contextEpoch)
                : _load(
                    householdId,
                    previous: preserveContent ? ready : null,
                    contextEpoch: contextEpoch,
                  ))
            .whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> refresh() {
    final NotificationCenterReady? ready = _state is NotificationCenterReady
        ? _state as NotificationCenterReady
        : null;
    return ready == null
        ? Future<void>.value()
        : load(ready.snapshot.householdId, preserveContent: true);
  }

  Future<void> resume() => _syncSession.resume();

  Future<void> reconnect() => _syncSession.reconnect();

  Future<void> loadMore() {
    final NotificationCenterReady? ready = _state is NotificationCenterReady
        ? _state as NotificationCenterReady
        : null;
    final NotificationInboxCursor? cursor = ready?.snapshot.inbox.nextCursor;
    if (_busy ||
        _disposed ||
        ready == null ||
        !ready.snapshot.inbox.hasMore ||
        cursor == null) {
      return _pending;
    }
    _busy = true;
    _emit(
      NotificationCenterReady(
        ready.snapshot,
        loadingMore: true,
        syncStatus: _syncStatus,
      ),
    );
    _pending = _loadMore(
      ready,
      cursor,
      _contextEpoch,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> updatePreference(NotificationPreference preference) {
    final NotificationCenterReady? ready = _readyFor(preference.householdId);
    if (_busy || _disposed || ready == null) {
      return _pending;
    }
    _busy = true;
    _emit(
      NotificationCenterReady(
        ready.snapshot,
        actionPending: true,
        syncStatus: _syncStatus,
      ),
    );
    _pending = _updatePreference(
      ready,
      preference,
      _contextEpoch,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> markRead(NotificationInboxItemId itemId) {
    final NotificationCenterReady? ready = _state is NotificationCenterReady
        ? _state as NotificationCenterReady
        : null;
    final NotificationInboxItem? item = ready == null
        ? null
        : _findItem(ready.snapshot.inbox.items, itemId);
    if (_busy || _disposed || ready == null || item == null || item.isRead) {
      return _pending;
    }
    _busy = true;
    _emit(
      NotificationCenterReady(
        ready.snapshot,
        actionPending: true,
        syncStatus: _syncStatus,
      ),
    );
    _pending = _markRead(
      ready,
      itemId,
      _contextEpoch,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<void> markAllRead() {
    final NotificationCenterReady? ready = _state is NotificationCenterReady
        ? _state as NotificationCenterReady
        : null;
    if (_busy ||
        _disposed ||
        ready == null ||
        ready.snapshot.unreadCount == 0) {
      return _pending;
    }
    _busy = true;
    _emit(
      NotificationCenterReady(
        ready.snapshot,
        actionPending: true,
        syncStatus: _syncStatus,
      ),
    );
    _pending = _markAllRead(
      ready,
      _contextEpoch,
    ).whenComplete(() => _busy = false);
    return _pending;
  }

  Future<bool> snoozeCalendar(
    NotificationInboxItemId itemId,
    int snoozeMinutes,
  ) {
    final NotificationCenterReady? ready = _state is NotificationCenterReady
        ? _state as NotificationCenterReady
        : null;
    final NotificationInboxItem? item = ready == null
        ? null
        : _findItem(ready.snapshot.inbox.items, itemId);
    if (_busy ||
        _disposed ||
        ready == null ||
        item == null ||
        !item.availableSnoozeMinutes.contains(snoozeMinutes)) {
      return Future<bool>.value(false);
    }
    _busy = true;
    _emit(
      NotificationCenterReady(
        ready.snapshot,
        actionPending: true,
        syncStatus: _syncStatus,
      ),
    );
    final bool reuse =
        _snoozeRetryItemId == itemId &&
        _snoozeRetryMinutes == snoozeMinutes &&
        _snoozeRetryId != null;
    final NotificationSnoozeCommandId commandId = reuse
        ? _snoozeRetryId!
        : snoozeIdFactory();
    _snoozeRetryId = commandId;
    _snoozeRetryItemId = itemId;
    _snoozeRetryMinutes = snoozeMinutes;
    final Future<bool> result = _snoozeCalendar(
      ready,
      item,
      snoozeMinutes,
      commandId,
      _contextEpoch,
    ).whenComplete(() => _busy = false);
    _pending = result.then<void>((_) {});
    return result;
  }

  Future<void> _load(
    HouseholdId householdId, {
    required NotificationCenterReady? previous,
    required int contextEpoch,
  }) async {
    final NotificationResult<NotificationSnapshot> result = await _repository
        .loadSnapshot(householdId);
    if (!_isCurrent(householdId, contextEpoch)) {
      return;
    }
    switch (result) {
      case NotificationSucceeded<NotificationSnapshot>(:final value):
        _emit(NotificationCenterReady(value, syncStatus: _syncStatus));
        await _ensureSync(householdId, contextEpoch);
      case NotificationFailed<NotificationSnapshot>(:final failure):
        if (_authorizationFailure(failure)) {
          _emit(NotificationCenterLoadFailed(failure));
          await _stopSyncAfterAuthorizationFailure(householdId, contextEpoch);
        } else if (previous != null) {
          _emit(
            NotificationCenterReady(
              previous.snapshot,
              actionFailure: failure,
              syncStatus: _syncStatus,
            ),
          );
        } else {
          _emit(NotificationCenterLoadFailed(failure));
        }
    }
  }

  Future<void> _loadMore(
    NotificationCenterReady ready,
    NotificationInboxCursor cursor,
    int contextEpoch,
  ) async {
    final NotificationResult<NotificationInboxPage> result = await _repository
        .loadMore(householdId: ready.snapshot.householdId, cursor: cursor);
    if (!_isCurrent(ready.snapshot.householdId, contextEpoch)) {
      return;
    }
    switch (result) {
      case NotificationSucceeded<NotificationInboxPage>(:final value):
        final Set<NotificationInboxItemId> seen = ready.snapshot.inbox.items
            .map((item) => item.id)
            .toSet();
        final List<NotificationInboxItem> items = <NotificationInboxItem>[
          ...ready.snapshot.inbox.items,
          ...value.items.where((item) => seen.add(item.id)),
        ];
        _emit(
          NotificationCenterReady(
            NotificationSnapshot(
              householdId: ready.snapshot.householdId,
              preferences: ready.snapshot.preferences,
              inbox: NotificationInboxPage(
                items: items,
                hasMore: value.hasMore,
                nextCursor: value.nextCursor,
              ),
              unreadCount: ready.snapshot.unreadCount,
            ),
            syncStatus: _syncStatus,
          ),
        );
      case NotificationFailed<NotificationInboxPage>(:final failure):
        _emit(
          NotificationCenterReady(
            ready.snapshot,
            loadMoreFailure: failure,
            syncStatus: _syncStatus,
          ),
        );
    }
  }

  Future<void> _updatePreference(
    NotificationCenterReady ready,
    NotificationPreference preference,
    int contextEpoch,
  ) async {
    final NotificationResult<NotificationPreference> result = await _repository
        .updatePreference(preference);
    if (!_isCurrent(ready.snapshot.householdId, contextEpoch)) {
      return;
    }
    switch (result) {
      case NotificationSucceeded<NotificationPreference>(:final value):
        final List<NotificationPreference> preferences = ready
            .snapshot
            .preferences
            .map((item) => item.category == value.category ? value : item)
            .toList(growable: false);
        _emit(
          NotificationCenterReady(
            NotificationSnapshot(
              householdId: ready.snapshot.householdId,
              preferences: preferences,
              inbox: ready.snapshot.inbox,
              unreadCount: ready.snapshot.unreadCount,
            ),
            syncStatus: _syncStatus,
          ),
        );
      case NotificationFailed<NotificationPreference>(:final failure):
        await _emitActionFailure(ready, failure, contextEpoch);
    }
  }

  Future<void> _markRead(
    NotificationCenterReady ready,
    NotificationInboxItemId itemId,
    int contextEpoch,
  ) async {
    final NotificationResult<NotificationReadReceipt> result = await _repository
        .markRead(
          householdId: ready.snapshot.householdId,
          itemIds: <NotificationInboxItemId>[itemId],
        );
    if (!_isCurrent(ready.snapshot.householdId, contextEpoch)) {
      return;
    }
    switch (result) {
      case NotificationSucceeded<NotificationReadReceipt>(:final value):
        _emit(
          NotificationCenterReady(
            _withReadReceipt(
              ready.snapshot,
              value,
              (item) => item.id == itemId,
            ),
            syncStatus: _syncStatus,
          ),
        );
      case NotificationFailed<NotificationReadReceipt>(:final failure):
        await _emitActionFailure(ready, failure, contextEpoch);
    }
  }

  Future<void> _markAllRead(
    NotificationCenterReady ready,
    int contextEpoch,
  ) async {
    final NotificationResult<NotificationReadReceipt> result = await _repository
        .markAllRead(ready.snapshot.householdId);
    if (!_isCurrent(ready.snapshot.householdId, contextEpoch)) {
      return;
    }
    switch (result) {
      case NotificationSucceeded<NotificationReadReceipt>(:final value):
        _emit(
          NotificationCenterReady(
            _withReadReceipt(ready.snapshot, value, (item) => !item.isRead),
            syncStatus: _syncStatus,
          ),
        );
      case NotificationFailed<NotificationReadReceipt>(:final failure):
        await _emitActionFailure(ready, failure, contextEpoch);
    }
  }

  Future<bool> _snoozeCalendar(
    NotificationCenterReady ready,
    NotificationInboxItem item,
    int snoozeMinutes,
    NotificationSnoozeCommandId commandId,
    int contextEpoch,
  ) async {
    final NotificationResult<NotificationSnoozeReceipt> result =
        await _repository.snoozeCalendar(
          householdId: ready.snapshot.householdId,
          inboxItemId: item.id,
          snoozeMinutes: snoozeMinutes,
          commandId: commandId,
          expectedItemVersion: item.itemVersion,
        );
    if (!_isCurrent(ready.snapshot.householdId, contextEpoch)) {
      return false;
    }
    switch (result) {
      case NotificationSucceeded<NotificationSnoozeReceipt>(:final value):
        _clearSnoozeRetry();
        _emit(
          NotificationCenterReady(
            NotificationSnapshot(
              householdId: ready.snapshot.householdId,
              preferences: ready.snapshot.preferences,
              inbox: NotificationInboxPage(
                items: ready.snapshot.inbox.items
                    .where((candidate) => candidate.id != value.inboxItemId)
                    .toList(growable: false),
                hasMore: ready.snapshot.inbox.hasMore,
                nextCursor: ready.snapshot.inbox.nextCursor,
              ),
              unreadCount: value.unreadCount,
            ),
            syncStatus: _syncStatus,
          ),
        );
        return true;
      case NotificationFailed<NotificationSnoozeReceipt>(:final failure):
        if (!_retainSnoozeCommand(failure)) {
          _clearSnoozeRetry();
        }
        await _emitActionFailure(ready, failure, contextEpoch);
        return false;
    }
  }

  NotificationSnapshot _withReadReceipt(
    NotificationSnapshot snapshot,
    NotificationReadReceipt receipt,
    bool Function(NotificationInboxItem item) shouldMark,
  ) {
    return NotificationSnapshot(
      householdId: snapshot.householdId,
      preferences: snapshot.preferences,
      inbox: NotificationInboxPage(
        items: snapshot.inbox.items
            .map(
              (item) => !item.isRead && shouldMark(item)
                  ? item.markRead(receipt.markedAt)
                  : item,
            )
            .toList(growable: false),
        hasMore: snapshot.inbox.hasMore,
        nextCursor: snapshot.inbox.nextCursor,
      ),
      unreadCount: receipt.unreadCount,
    );
  }

  Future<void> _emitActionFailure(
    NotificationCenterReady ready,
    NotificationFailure failure,
    int contextEpoch,
  ) async {
    if (_authorizationFailure(failure)) {
      _emit(NotificationCenterLoadFailed(failure));
      await _stopSyncAfterAuthorizationFailure(
        ready.snapshot.householdId,
        contextEpoch,
      );
      return;
    }
    _emit(
      NotificationCenterReady(
        ready.snapshot,
        actionFailure: failure,
        syncStatus: _syncStatus,
      ),
    );
  }

  NotificationCenterReady? _readyFor(HouseholdId householdId) {
    final NotificationCenterState current = _state;
    return current is NotificationCenterReady &&
            current.snapshot.householdId == householdId
        ? current
        : null;
  }

  NotificationInboxItem? _findItem(
    List<NotificationInboxItem> items,
    NotificationInboxItemId id,
  ) {
    for (final NotificationInboxItem item in items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  bool _authorizationFailure(NotificationFailure failure) {
    return failure.kind == NotificationFailureKind.unauthenticated ||
        failure.kind == NotificationFailureKind.notFoundOrForbidden;
  }

  bool _retainSnoozeCommand(NotificationFailure failure) {
    return failure.kind == NotificationFailureKind.temporarilyUnavailable ||
        failure.kind == NotificationFailureKind.invalidPayload ||
        failure.kind == NotificationFailureKind.unknown;
  }

  bool _isCurrent(HouseholdId householdId, int contextEpoch) {
    return !_disposed &&
        _contextEpoch == contextEpoch &&
        _currentHouseholdId == householdId;
  }

  Future<void> _stopSyncAndLoad(
    HouseholdId householdId,
    int contextEpoch,
  ) async {
    _syncedHouseholdId = null;
    await _syncSession.stop();
    if (!_isCurrent(householdId, contextEpoch)) {
      return;
    }
    await _load(householdId, previous: null, contextEpoch: contextEpoch);
  }

  Future<void> _ensureSync(HouseholdId householdId, int contextEpoch) async {
    final AuthUserId? authUserId = _authUserId;
    if (!_isCurrent(householdId, contextEpoch) ||
        authUserId == null ||
        _state is! NotificationCenterReady ||
        (_state as NotificationCenterReady).snapshot.householdId !=
            householdId ||
        _syncedHouseholdId == householdId) {
      return;
    }
    _syncedHouseholdId = householdId;
    await _syncSession.start(authUserId);
  }

  Future<void> _stopSyncAfterAuthorizationFailure(
    HouseholdId householdId,
    int contextEpoch,
  ) async {
    if (!_isCurrent(householdId, contextEpoch)) {
      return;
    }
    _syncedHouseholdId = null;
    await _syncSession.stop();
  }

  Future<void> _synchronize() async {
    if (_busy) {
      await _pending;
    }
    final HouseholdId? householdId = _currentHouseholdId;
    if (_disposed || householdId == null) {
      return;
    }
    await load(householdId, preserveContent: true);
  }

  void _setSyncStatus(NotificationSyncConnectionStatus status) {
    if (_disposed || _syncStatus == status) {
      return;
    }
    _syncStatus = status;
    final NotificationCenterState current = _state;
    if (current case NotificationCenterReady(
      :final snapshot,
      :final actionPending,
      :final refreshing,
      :final loadingMore,
      :final actionFailure,
      :final loadMoreFailure,
    )) {
      _emit(
        NotificationCenterReady(
          snapshot,
          actionPending: actionPending,
          refreshing: refreshing,
          loadingMore: loadingMore,
          actionFailure: actionFailure,
          loadMoreFailure: loadMoreFailure,
          syncStatus: status,
        ),
      );
    }
  }

  void _clearSnoozeRetry() {
    _snoozeRetryId = null;
    _snoozeRetryItemId = null;
    _snoozeRetryMinutes = null;
  }

  void _emit(NotificationCenterState state) {
    if (_disposed) {
      return;
    }
    _state = state;
    _states.add(state);
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _syncSession.dispose();
    await _pending;
    await _states.close();
  }
}
