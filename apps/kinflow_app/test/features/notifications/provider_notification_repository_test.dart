import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/data/datasources/notification_data_source.dart';
import 'package:kinflow_app/features/notifications/data/repositories/provider_notification_repository.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';

import '../../support/fakes/fake_notification_dependencies.dart';

void main() {
  final HouseholdId householdId = HouseholdId.tryParse(
    notificationHouseholdUuid,
  )!;

  test('snapshot maps strict preferences, inbox cursor, and badge', () async {
    final _FakeNotificationDataSource dataSource =
        _FakeNotificationDataSource();
    final ProviderNotificationRepository repository =
        ProviderNotificationRepository(dataSource);

    final NotificationResult<NotificationSnapshot> result = await repository
        .loadSnapshot(householdId);

    expect(result, isA<NotificationSucceeded<NotificationSnapshot>>());
    final NotificationSnapshot snapshot =
        (result as NotificationSucceeded<NotificationSnapshot>).value;
    expect(snapshot.preferences, hasLength(3));
    expect(snapshot.preference(NotificationCategory.calendarEvent), isNotNull);
    expect(snapshot.inbox.items, hasLength(2));
    expect(snapshot.inbox.hasMore, isTrue);
    expect(snapshot.inbox.nextCursor?.id.value, notificationItemOneUuid);
    expect(snapshot.unreadCount, 1);
    expect(dataSource.inboxLimits.single, 30);
  });

  test('visible unread rows cannot exceed authoritative badge count', () async {
    final _FakeNotificationDataSource dataSource = _FakeNotificationDataSource(
      unreadCount: 0,
    );
    final ProviderNotificationRepository repository =
        ProviderNotificationRepository(dataSource);

    final NotificationResult<NotificationSnapshot> result = await repository
        .loadSnapshot(householdId);

    expect(result, isA<NotificationFailed<NotificationSnapshot>>());
    expect(
      (result as NotificationFailed<NotificationSnapshot>).failure.kind,
      NotificationFailureKind.invalidPayload,
    );
  });

  test(
    'default preference update preserves expected version and channel values',
    () async {
      final _FakeNotificationDataSource dataSource =
          _FakeNotificationDataSource();
      final ProviderNotificationRepository repository =
          ProviderNotificationRepository(dataSource);
      final NotificationPreference preference = notificationSnapshotFixture()
          .preferences
          .first
          .changed(inApp: false, quietHoursEnabled: true)!;

      final NotificationResult<NotificationPreference> result = await repository
          .updatePreference(preference);

      expect(result, isA<NotificationSucceeded<NotificationPreference>>());
      expect(dataSource.updatedExpectedVersion, 0);
      expect(dataSource.updatedInApp, isFalse);
      expect(dataSource.updatedQuietStart, '22:00');
      expect(dataSource.updatedReminderLeadMinutes, 0);
      expect(dataSource.updatedAdditionalReminderLeadMinutes, isEmpty);
    },
  );

  test('multiple Calendar reminders cross the data boundary exactly', () async {
    final _FakeNotificationDataSource dataSource =
        _FakeNotificationDataSource();
    final ProviderNotificationRepository repository =
        ProviderNotificationRepository(dataSource);
    final NotificationPreference calendar = notificationSnapshotFixture()
        .preference(NotificationCategory.calendarEvent)!;
    final NotificationPreference changed = calendar.changed(
      quietHoursEnabled: false,
      reminderLeadMinutes: 15,
      additionalReminderLeadMinutes: const <int>[30, 60],
    )!;

    final NotificationResult<NotificationPreference> result = await repository
        .updatePreference(changed);

    expect(result, isA<NotificationSucceeded<NotificationPreference>>());
    expect(dataSource.updatedReminderLeadMinutes, 15);
    expect(dataSource.updatedAdditionalReminderLeadMinutes, const <int>[
      30,
      60,
    ]);
    final NotificationPreference saved =
        (result as NotificationSucceeded<NotificationPreference>).value;
    expect(saved.additionalReminderLeadMinutes, const <int>[30, 60]);
  });

  test(
    'push target is accepted only when every routing field echoes',
    () async {
      final NotificationPushEnvelope envelope =
          NotificationPushEnvelope.tryParse(<String, Object?>{
            'category': 'chore_due',
            'contractVersion': notificationPushContractVersion,
            'deliveryId': '84000000-0000-4000-8000-000000000001',
            'householdId': notificationHouseholdUuid,
            'inboxItemId': notificationItemOneUuid,
            'sourceEventId': '84010000-0000-4000-8000-000000000001',
            'subjectId': '83000000-0000-4000-8000-000000000001',
            'subjectType': 'chore_occurrence',
          })!;
      final _FakeNotificationDataSource dataSource =
          _FakeNotificationDataSource(
            pushTarget: NotificationPushTargetDataRecord(
              deliveryId: envelope.deliveryId,
              householdId: envelope.householdId.value,
              category: envelope.category.wireValue,
              subjectType: 'chore_occurrence',
              subjectId: envelope.subjectId,
              inboxItemId: envelope.inboxItemId?.value,
              safeDestination: 'chore_occurrence',
            ),
          );
      final ProviderNotificationRepository repository =
          ProviderNotificationRepository(dataSource);

      final NotificationResult<NotificationPushTarget?> allowed =
          await repository.resolvePushTarget(envelope);

      expect(allowed, isA<NotificationSucceeded<NotificationPushTarget?>>());
      expect(dataSource.targetDeliveryId, envelope.deliveryId);

      dataSource.pushTarget = NotificationPushTargetDataRecord(
        deliveryId: envelope.deliveryId,
        householdId: envelope.householdId.value,
        category: envelope.category.wireValue,
        subjectType: 'chore_occurrence',
        subjectId: '83000000-0000-4000-8000-000000000002',
        inboxItemId: envelope.inboxItemId?.value,
        safeDestination: 'chore_occurrence',
      );
      final NotificationResult<NotificationPushTarget?> mismatched =
          await repository.resolvePushTarget(envelope);
      expect(mismatched, isA<NotificationFailed<NotificationPushTarget?>>());
    },
  );

  test('Calendar snooze maps an exact echoed receipt', () async {
    final _FakeNotificationDataSource dataSource =
        _FakeNotificationDataSource();
    final ProviderNotificationRepository repository =
        ProviderNotificationRepository(dataSource);
    final NotificationSnoozeCommandId commandId =
        NotificationSnoozeCommandId.tryParse(
          '85000000-0000-4000-8000-000000000001',
        )!;
    final NotificationInboxItemId itemId = NotificationInboxItemId.tryParse(
      notificationItemOneUuid,
    )!;

    final NotificationResult<NotificationSnoozeReceipt> result =
        await repository.snoozeCalendar(
          householdId: householdId,
          inboxItemId: itemId,
          snoozeMinutes: 10,
          commandId: commandId,
          expectedItemVersion: 1,
        );

    expect(result, isA<NotificationSucceeded<NotificationSnoozeReceipt>>());
    final NotificationSnoozeReceipt receipt =
        (result as NotificationSucceeded<NotificationSnoozeReceipt>).value;
    expect(receipt.commandId, commandId);
    expect(receipt.inboxItemId, itemId);
    expect(receipt.itemVersion, 2);
    expect(receipt.snoozeMinutes, 10);
  });
}

final class _FakeNotificationDataSource implements NotificationDataSource {
  _FakeNotificationDataSource({this.unreadCount = 1, this.pushTarget});

  final int unreadCount;
  NotificationPushTargetDataRecord? pushTarget;
  String? targetDeliveryId;
  final List<int> inboxLimits = <int>[];
  int? updatedExpectedVersion;
  bool? updatedInApp;
  String? updatedQuietStart;
  int? updatedReminderLeadMinutes;
  List<int>? updatedAdditionalReminderLeadMinutes;

  @override
  Future<NotificationDataResult<NotificationInboxPageDataRecord>> loadInbox({
    required String householdId,
    required int limit,
    required String? beforeCreatedAt,
    required String? beforeId,
  }) async {
    inboxLimits.add(limit);
    return NotificationDataSucceeded<NotificationInboxPageDataRecord>(
      NotificationInboxPageDataRecord(
        items: <NotificationInboxItemDataRecord>[
          _item(
            notificationItemTwoUuid,
            'chore_assignment',
            '2026-08-08T02:00:00Z',
            null,
          ),
          _item(
            notificationItemOneUuid,
            'chore_due',
            '2026-08-08T01:00:00Z',
            '2026-08-08T02:00:00Z',
          ),
        ],
        hasMore: true,
        nextBeforeCreatedAt: '2026-08-08T01:00:00Z',
        nextBeforeId: notificationItemOneUuid,
      ),
    );
  }

  @override
  Future<NotificationDataResult<List<NotificationPreferenceDataRecord>>>
  loadPreferences({required String householdId}) async {
    return NotificationDataSucceeded<List<NotificationPreferenceDataRecord>>(
      <NotificationPreferenceDataRecord>[
        _preference('chore_due', quiet: true),
        _preference('chore_assignment', quiet: false),
        _preference('calendar_event', quiet: false),
      ],
    );
  }

  @override
  Future<NotificationDataResult<int>> loadUnreadCount({
    required String householdId,
  }) async => NotificationDataSucceeded<int>(unreadCount);

  @override
  Future<NotificationDataResult<NotificationReadDataRecord>> markAllRead({
    required String householdId,
  }) async => const NotificationDataSucceeded<NotificationReadDataRecord>(
    NotificationReadDataRecord(
      markedCount: 1,
      unreadCount: 0,
      markedAt: '2026-08-08T03:00:00Z',
    ),
  );

  @override
  Future<NotificationDataResult<NotificationReadDataRecord>> markRead({
    required String householdId,
    required List<String> itemIds,
  }) async => const NotificationDataSucceeded<NotificationReadDataRecord>(
    NotificationReadDataRecord(
      markedCount: 1,
      unreadCount: 0,
      markedAt: '2026-08-08T03:00:00Z',
    ),
  );

  @override
  Future<NotificationDataResult<NotificationPreferenceDataRecord>>
  updatePreference({
    required String householdId,
    required String category,
    required bool nativePush,
    required bool webPush,
    required bool email,
    required bool inApp,
    required String? quietStart,
    required String? quietEnd,
    required String timezone,
    required int reminderLeadMinutes,
    required List<int> additionalReminderLeadMinutes,
    required int expectedVersion,
  }) async {
    updatedExpectedVersion = expectedVersion;
    updatedInApp = inApp;
    updatedQuietStart = quietStart;
    updatedReminderLeadMinutes = reminderLeadMinutes;
    updatedAdditionalReminderLeadMinutes = List<int>.of(
      additionalReminderLeadMinutes,
    );
    return NotificationDataSucceeded<NotificationPreferenceDataRecord>(
      NotificationPreferenceDataRecord(
        householdId: householdId,
        category: category,
        nativePush: nativePush,
        webPush: webPush,
        email: email,
        inApp: inApp,
        quietStart: quietStart == null ? null : '$quietStart:00',
        quietEnd: quietEnd == null ? null : '$quietEnd:00',
        timezone: timezone,
        reminderLeadMinutes: reminderLeadMinutes,
        additionalReminderLeadMinutes: additionalReminderLeadMinutes,
        updatedAt: '2026-08-08T03:00:00Z',
        version: expectedVersion + 1,
        isDefault: false,
      ),
    );
  }

  @override
  Future<NotificationDataResult<NotificationPushTargetDataRecord?>>
  resolvePushTarget({
    required String deliveryId,
    required String householdId,
    required String subjectId,
  }) async {
    targetDeliveryId = deliveryId;
    return NotificationDataSucceeded<NotificationPushTargetDataRecord?>(
      pushTarget,
    );
  }

  @override
  Future<NotificationDataResult<NotificationSnoozeDataRecord>> snoozeCalendar({
    required String householdId,
    required String inboxItemId,
    required int snoozeMinutes,
    required String commandId,
    required int expectedItemVersion,
  }) async {
    return NotificationDataSucceeded<NotificationSnoozeDataRecord>(
      NotificationSnoozeDataRecord(
        commandId: commandId,
        sourceEventId: '84000000-0000-4000-8000-000000000010',
        inboxItemId: inboxItemId,
        itemVersion: expectedItemVersion + 1,
        snoozedUntil: '2026-08-08T03:10:00Z',
        snoozeMinutes: snoozeMinutes,
        snoozeCount: 1,
        unreadCount: 0,
        recordedAt: '2026-08-08T03:00:00Z',
      ),
    );
  }

  NotificationPreferenceDataRecord _preference(
    String category, {
    required bool quiet,
  }) {
    return NotificationPreferenceDataRecord(
      householdId: notificationHouseholdUuid,
      category: category,
      nativePush: true,
      webPush: false,
      email: false,
      inApp: true,
      quietStart: quiet ? '22:00:00' : null,
      quietEnd: quiet ? '07:00:00' : null,
      timezone: 'Asia/Seoul',
      reminderLeadMinutes: 0,
      additionalReminderLeadMinutes: const <int>[],
      updatedAt: null,
      version: 0,
      isDefault: true,
    );
  }

  NotificationInboxItemDataRecord _item(
    String id,
    String category,
    String createdAt,
    String? readAt,
  ) {
    final String sourceId = category == 'chore_due'
        ? '82000000-0000-4000-8000-000000000001'
        : '82000000-0000-4000-8000-000000000002';
    final String subjectId = category == 'chore_due'
        ? '83000000-0000-4000-8000-000000000001'
        : '83000000-0000-4000-8000-000000000002';
    return NotificationInboxItemDataRecord(
      inboxItemId: id,
      itemVersion: readAt == null ? 1 : 2,
      sourceEventId: sourceId,
      householdId: notificationHouseholdUuid,
      category: category,
      subjectType: 'chore_occurrence',
      subjectId: subjectId,
      scheduledAt: '2026-08-09T00:00:00Z',
      createdAt: createdAt,
      readAt: readAt,
      snoozeCount: 0,
      snoozeMaxMinutes: 0,
      payload: <String, Object?>{
        'householdId': notificationHouseholdUuid,
        'occurrenceId': subjectId,
      },
    );
  }
}
