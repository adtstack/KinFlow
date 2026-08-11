import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';

const String notificationHouseholdUuid = '22222222-2222-4222-8222-222222222222';
const String notificationItemOneUuid = '81000000-0000-4000-8000-000000000001';
const String notificationItemTwoUuid = '81000000-0000-4000-8000-000000000002';

final class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({
    NotificationSnapshot? snapshot,
    List<NotificationResult<NotificationSnapshot>> loadResults =
        const <NotificationResult<NotificationSnapshot>>[],
    List<Future<NotificationResult<NotificationSnapshot>>> loadFutures =
        const <Future<NotificationResult<NotificationSnapshot>>>[],
    List<NotificationResult<NotificationInboxPage>> loadMoreResults =
        const <NotificationResult<NotificationInboxPage>>[],
    List<NotificationResult<NotificationPreference>> updateResults =
        const <NotificationResult<NotificationPreference>>[],
    List<NotificationResult<NotificationReadReceipt>> readResults =
        const <NotificationResult<NotificationReadReceipt>>[],
    List<NotificationResult<NotificationReadReceipt>> readAllResults =
        const <NotificationResult<NotificationReadReceipt>>[],
    List<Future<NotificationResult<NotificationReadReceipt>>> readAllFutures =
        const <Future<NotificationResult<NotificationReadReceipt>>>[],
    List<NotificationResult<NotificationSnoozeReceipt>> snoozeResults =
        const <NotificationResult<NotificationSnoozeReceipt>>[],
    List<NotificationResult<NotificationPushTarget?>> targetResults =
        const <NotificationResult<NotificationPushTarget?>>[],
  }) : defaultSnapshot = snapshot ?? notificationSnapshotFixture(),
       _loadResults = List<NotificationResult<NotificationSnapshot>>.of(
         loadResults,
       ),
       _loadFutures = List<Future<NotificationResult<NotificationSnapshot>>>.of(
         loadFutures,
       ),
       _loadMoreResults = List<NotificationResult<NotificationInboxPage>>.of(
         loadMoreResults,
       ),
       _updateResults = List<NotificationResult<NotificationPreference>>.of(
         updateResults,
       ),
       _readResults = List<NotificationResult<NotificationReadReceipt>>.of(
         readResults,
       ),
       _readAllResults = List<NotificationResult<NotificationReadReceipt>>.of(
         readAllResults,
       ),
       _readAllFutures =
           List<Future<NotificationResult<NotificationReadReceipt>>>.of(
             readAllFutures,
           ),
       _snoozeResults = List<NotificationResult<NotificationSnoozeReceipt>>.of(
         snoozeResults,
       ),
       _targetResults = List<NotificationResult<NotificationPushTarget?>>.of(
         targetResults,
       );

  NotificationSnapshot defaultSnapshot;
  final List<NotificationResult<NotificationSnapshot>> _loadResults;
  final List<Future<NotificationResult<NotificationSnapshot>>> _loadFutures;
  final List<NotificationResult<NotificationInboxPage>> _loadMoreResults;
  final List<NotificationResult<NotificationPreference>> _updateResults;
  final List<NotificationResult<NotificationReadReceipt>> _readResults;
  final List<NotificationResult<NotificationReadReceipt>> _readAllResults;
  final List<Future<NotificationResult<NotificationReadReceipt>>>
  _readAllFutures;
  final List<NotificationResult<NotificationSnoozeReceipt>> _snoozeResults;
  final List<NotificationResult<NotificationPushTarget?>> _targetResults;
  final List<HouseholdId> loadedHouseholds = <HouseholdId>[];
  final List<NotificationInboxCursor> cursors = <NotificationInboxCursor>[];
  final List<NotificationPreference> updatedPreferences =
      <NotificationPreference>[];
  final List<List<NotificationInboxItemId>> readItemIds =
      <List<NotificationInboxItemId>>[];
  var markAllCount = 0;
  final List<
    ({
      HouseholdId householdId,
      NotificationInboxItemId inboxItemId,
      int snoozeMinutes,
      NotificationSnoozeCommandId commandId,
      int expectedItemVersion,
    })
  >
  snoozeCalls =
      <
        ({
          HouseholdId householdId,
          NotificationInboxItemId inboxItemId,
          int snoozeMinutes,
          NotificationSnoozeCommandId commandId,
          int expectedItemVersion,
        })
      >[];
  final List<NotificationPushEnvelope> resolvedPushEnvelopes =
      <NotificationPushEnvelope>[];

  @override
  Future<NotificationResult<NotificationSnapshot>> loadSnapshot(
    HouseholdId householdId,
  ) async {
    loadedHouseholds.add(householdId);
    if (_loadFutures.isNotEmpty) {
      return _loadFutures.removeAt(0);
    }
    return _loadResults.isEmpty
        ? NotificationSucceeded<NotificationSnapshot>(defaultSnapshot)
        : _loadResults.removeAt(0);
  }

  @override
  Future<NotificationResult<NotificationInboxPage>> loadMore({
    required HouseholdId householdId,
    required NotificationInboxCursor cursor,
  }) async {
    cursors.add(cursor);
    return _loadMoreResults.isEmpty
        ? NotificationSucceeded<NotificationInboxPage>(
            NotificationInboxPage(
              items: const <NotificationInboxItem>[],
              hasMore: false,
              nextCursor: null,
            ),
          )
        : _loadMoreResults.removeAt(0);
  }

  @override
  Future<NotificationResult<NotificationReadReceipt>> markAllRead(
    HouseholdId householdId,
  ) async {
    markAllCount += 1;
    if (_readAllFutures.isNotEmpty) {
      return _readAllFutures.removeAt(0);
    }
    return _readAllResults.isEmpty
        ? NotificationSucceeded<NotificationReadReceipt>(
            NotificationReadReceipt(
              markedCount: defaultSnapshot.unreadCount,
              unreadCount: 0,
              markedAt: DateTime.utc(2026, 8, 8, 3),
            ),
          )
        : _readAllResults.removeAt(0);
  }

  @override
  Future<NotificationResult<NotificationReadReceipt>> markRead({
    required HouseholdId householdId,
    required List<NotificationInboxItemId> itemIds,
  }) async {
    readItemIds.add(List<NotificationInboxItemId>.of(itemIds));
    return _readResults.isEmpty
        ? NotificationSucceeded<NotificationReadReceipt>(
            NotificationReadReceipt(
              markedCount: 1,
              unreadCount: (defaultSnapshot.unreadCount - 1).clamp(0, 999),
              markedAt: DateTime.utc(2026, 8, 8, 3),
            ),
          )
        : _readResults.removeAt(0);
  }

  @override
  Future<NotificationResult<NotificationPreference>> updatePreference(
    NotificationPreference preference,
  ) async {
    updatedPreferences.add(preference);
    if (_updateResults.isNotEmpty) {
      return _updateResults.removeAt(0);
    }
    return NotificationSucceeded<NotificationPreference>(
      NotificationPreference.tryCreate(
        householdId: preference.householdId,
        category: preference.category,
        nativePush: preference.nativePush,
        webPush: preference.webPush,
        email: preference.email,
        inApp: preference.inApp,
        quietStart: preference.quietStart,
        quietEnd: preference.quietEnd,
        timezone: preference.timezone,
        reminderLeadMinutes: preference.reminderLeadMinutes,
        additionalReminderLeadMinutes: preference.additionalReminderLeadMinutes,
        updatedAt: DateTime.utc(2026, 8, 8, 3),
        version: preference.version + 1,
        isDefault: false,
      )!,
    );
  }

  @override
  Future<NotificationResult<NotificationSnoozeReceipt>> snoozeCalendar({
    required HouseholdId householdId,
    required NotificationInboxItemId inboxItemId,
    required int snoozeMinutes,
    required NotificationSnoozeCommandId commandId,
    required int expectedItemVersion,
  }) async {
    snoozeCalls.add((
      householdId: householdId,
      inboxItemId: inboxItemId,
      snoozeMinutes: snoozeMinutes,
      commandId: commandId,
      expectedItemVersion: expectedItemVersion,
    ));
    if (_snoozeResults.isNotEmpty) {
      return _snoozeResults.removeAt(0);
    }
    final DateTime recordedAt = DateTime.utc(2026, 8, 8, 3);
    return NotificationSucceeded<NotificationSnoozeReceipt>(
      NotificationSnoozeReceipt.tryCreate(
        commandId: commandId,
        sourceEventId: '84000000-0000-4000-8000-000000000001',
        inboxItemId: inboxItemId,
        itemVersion: expectedItemVersion + 1,
        snoozedUntil: recordedAt.add(Duration(minutes: snoozeMinutes)),
        snoozeMinutes: snoozeMinutes,
        snoozeCount: 1,
        unreadCount: (defaultSnapshot.unreadCount - 1).clamp(0, 999),
        recordedAt: recordedAt,
      )!,
    );
  }

  @override
  Future<NotificationResult<NotificationPushTarget?>> resolvePushTarget(
    NotificationPushEnvelope envelope,
  ) async {
    resolvedPushEnvelopes.add(envelope);
    if (_targetResults.isNotEmpty) return _targetResults.removeAt(0);
    return const NotificationSucceeded<NotificationPushTarget?>(null);
  }
}

NotificationSnapshot notificationSnapshotFixture({
  int unreadCount = 1,
  bool hasMore = false,
}) {
  final HouseholdId householdId = HouseholdId.tryParse(
    notificationHouseholdUuid,
  )!;
  final List<NotificationInboxItem> items = <NotificationInboxItem>[
    notificationInboxItemFixture(
      id: notificationItemTwoUuid,
      category: NotificationCategory.choreAssignment,
      createdAt: DateTime.utc(2026, 8, 8, 2),
      readAt: unreadCount > 0 ? null : DateTime.utc(2026, 8, 8, 3),
    ),
    notificationInboxItemFixture(
      id: notificationItemOneUuid,
      category: NotificationCategory.choreDue,
      createdAt: DateTime.utc(2026, 8, 8, 1),
      readAt: DateTime.utc(2026, 8, 8, 2),
    ),
  ];
  return NotificationSnapshot(
    householdId: householdId,
    preferences: NotificationCategory.values
        .map(
          (category) => NotificationPreference.tryCreate(
            householdId: householdId,
            category: category,
            nativePush: true,
            webPush: false,
            email: false,
            inApp: true,
            quietStart: category == NotificationCategory.choreDue
                ? '22:00'
                : null,
            quietEnd: category == NotificationCategory.choreDue
                ? '07:00'
                : null,
            timezone: 'Asia/Seoul',
            reminderLeadMinutes: 0,
            additionalReminderLeadMinutes: const <int>[],
            updatedAt: null,
            version: 0,
            isDefault: true,
          )!,
        )
        .toList(growable: false),
    inbox: NotificationInboxPage(
      items: items,
      hasMore: hasMore,
      nextCursor: hasMore
          ? NotificationInboxCursor(
              createdAt: items.last.createdAt,
              id: items.last.id,
            )
          : null,
    ),
    unreadCount: unreadCount,
  );
}

NotificationInboxItem notificationInboxItemFixture({
  required String id,
  required NotificationCategory category,
  required DateTime createdAt,
  required DateTime? readAt,
  int? snoozeCount,
  int? snoozeMaxMinutes,
}) {
  final HouseholdId householdId = HouseholdId.tryParse(
    notificationHouseholdUuid,
  )!;
  final String sourceId = switch (category) {
    NotificationCategory.choreDue => '82000000-0000-4000-8000-000000000001',
    NotificationCategory.choreAssignment =>
      '82000000-0000-4000-8000-000000000002',
    NotificationCategory.calendarEvent =>
      '82000000-0000-4000-8000-000000000003',
  };
  final String subjectId = switch (category) {
    NotificationCategory.choreDue => '83000000-0000-4000-8000-000000000001',
    NotificationCategory.choreAssignment =>
      '83000000-0000-4000-8000-000000000002',
    NotificationCategory.calendarEvent =>
      '83000000-0000-4000-8000-000000000003',
  };
  return NotificationInboxItem.tryCreate(
    id: NotificationInboxItemId.tryParse(id)!,
    itemVersion: readAt == null ? 1 : 2,
    sourceEventId: sourceId,
    householdId: householdId,
    category: category,
    subjectType: category.subjectType,
    subjectId: subjectId,
    scheduledAt: DateTime.utc(2026, 8, 9),
    createdAt: createdAt,
    readAt: readAt,
    snoozeCount: snoozeCount ?? 0,
    snoozeMaxMinutes:
        snoozeMaxMinutes ??
        (category == NotificationCategory.calendarEvent ? 30 : 0),
    payload: <String, Object?>{
      'householdId': householdId.value,
      'occurrenceId': subjectId,
    },
  )!;
}
