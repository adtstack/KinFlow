import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/data/datasources/notification_data_source.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';
import 'package:kinflow_app/features/notifications/domain/repositories/notification_repository.dart';

final class ProviderNotificationRepository implements NotificationRepository {
  const ProviderNotificationRepository(this._dataSource);

  static const int _pageSize = 30;
  final NotificationDataSource _dataSource;

  @override
  Future<NotificationResult<NotificationSnapshot>> loadSnapshot(
    HouseholdId householdId,
  ) async {
    final List<NotificationDataResult<Object>> results =
        await Future.wait(<Future<NotificationDataResult<Object>>>[
          _dataSource
              .loadPreferences(householdId: householdId.value)
              .then<NotificationDataResult<Object>>((value) => value),
          _dataSource
              .loadInbox(
                householdId: householdId.value,
                limit: _pageSize,
                beforeCreatedAt: null,
                beforeId: null,
              )
              .then<NotificationDataResult<Object>>((value) => value),
          _dataSource
              .loadUnreadCount(householdId: householdId.value)
              .then<NotificationDataResult<Object>>((value) => value),
        ]);
    for (final NotificationDataResult<Object> result in results) {
      if (result case NotificationDataFailed<Object>(:final kind)) {
        return NotificationFailed<NotificationSnapshot>(_mapFailure(kind));
      }
    }
    final preferences =
        (results[0] as NotificationDataSucceeded<Object>).value
            as List<NotificationPreferenceDataRecord>;
    final inboxRecord =
        (results[1] as NotificationDataSucceeded<Object>).value
            as NotificationInboxPageDataRecord;
    final unreadCount =
        (results[2] as NotificationDataSucceeded<Object>).value as int;
    final List<NotificationPreference>? mappedPreferences = _mapPreferences(
      preferences,
      householdId,
    );
    final NotificationInboxPage? inbox = _mapInbox(inboxRecord, householdId);
    if (mappedPreferences == null ||
        inbox == null ||
        unreadCount < 0 ||
        unreadCount < inbox.items.where((item) => !item.isRead).length) {
      return const NotificationFailed<NotificationSnapshot>(
        NotificationFailure(NotificationFailureKind.invalidPayload),
      );
    }
    return NotificationSucceeded<NotificationSnapshot>(
      NotificationSnapshot(
        householdId: householdId,
        preferences: mappedPreferences,
        inbox: inbox,
        unreadCount: unreadCount,
      ),
    );
  }

  @override
  Future<NotificationResult<NotificationInboxPage>> loadMore({
    required HouseholdId householdId,
    required NotificationInboxCursor cursor,
  }) async {
    final result = await _dataSource.loadInbox(
      householdId: householdId.value,
      limit: _pageSize,
      beforeCreatedAt: cursor.createdAt.toUtc().toIso8601String(),
      beforeId: cursor.id.value,
    );
    return switch (result) {
      NotificationDataSucceeded<NotificationInboxPageDataRecord>(
        :final value,
      ) =>
        _mappedInboxResult(value, householdId),
      NotificationDataFailed<NotificationInboxPageDataRecord>(:final kind) =>
        NotificationFailed<NotificationInboxPage>(_mapFailure(kind)),
    };
  }

  @override
  Future<NotificationResult<NotificationPreference>> updatePreference(
    NotificationPreference preference,
  ) async {
    final result = await _dataSource.updatePreference(
      householdId: preference.householdId.value,
      category: preference.category.wireValue,
      nativePush: preference.nativePush,
      webPush: preference.webPush,
      email: preference.email,
      inApp: preference.inApp,
      quietStart: preference.quietStart,
      quietEnd: preference.quietEnd,
      timezone: preference.timezone,
      reminderLeadMinutes: preference.reminderLeadMinutes,
      additionalReminderLeadMinutes: preference.additionalReminderLeadMinutes,
      expectedVersion: preference.version,
    );
    return switch (result) {
      NotificationDataSucceeded<NotificationPreferenceDataRecord>(
        :final value,
      ) =>
        _mappedPreferenceResult(value, preference.householdId),
      NotificationDataFailed<NotificationPreferenceDataRecord>(:final kind) =>
        NotificationFailed<NotificationPreference>(_mapFailure(kind)),
    };
  }

  @override
  Future<NotificationResult<NotificationReadReceipt>> markRead({
    required HouseholdId householdId,
    required List<NotificationInboxItemId> itemIds,
  }) async {
    if (itemIds.isEmpty || itemIds.length > 100) {
      return const NotificationFailed<NotificationReadReceipt>(
        NotificationFailure(NotificationFailureKind.invalidInput),
      );
    }
    return _mapReadResult(
      await _dataSource.markRead(
        householdId: householdId.value,
        itemIds: itemIds.map((item) => item.value).toList(growable: false),
      ),
    );
  }

  @override
  Future<NotificationResult<NotificationReadReceipt>> markAllRead(
    HouseholdId householdId,
  ) {
    return _dataSource
        .markAllRead(householdId: householdId.value)
        .then(_mapReadResult);
  }

  @override
  Future<NotificationResult<NotificationSnoozeReceipt>> snoozeCalendar({
    required HouseholdId householdId,
    required NotificationInboxItemId inboxItemId,
    required int snoozeMinutes,
    required NotificationSnoozeCommandId commandId,
    required int expectedItemVersion,
  }) async {
    if (!NotificationInboxItem.snoozeMinuteOptions.contains(snoozeMinutes) ||
        expectedItemVersion < 1) {
      return const NotificationFailed<NotificationSnoozeReceipt>(
        NotificationFailure(NotificationFailureKind.invalidInput),
      );
    }
    final NotificationDataResult<NotificationSnoozeDataRecord> result =
        await _dataSource.snoozeCalendar(
          householdId: householdId.value,
          inboxItemId: inboxItemId.value,
          snoozeMinutes: snoozeMinutes,
          commandId: commandId.value,
          expectedItemVersion: expectedItemVersion,
        );
    return switch (result) {
      NotificationDataSucceeded<NotificationSnoozeDataRecord>(:final value) =>
        _mappedSnoozeReceipt(
          value,
          expectedCommandId: commandId,
          expectedInboxItemId: inboxItemId,
          expectedItemVersion: expectedItemVersion,
          expectedSnoozeMinutes: snoozeMinutes,
        ),
      NotificationDataFailed<NotificationSnoozeDataRecord>(:final kind) =>
        NotificationFailed<NotificationSnoozeReceipt>(_mapFailure(kind)),
    };
  }

  @override
  Future<NotificationResult<NotificationPushTarget?>> resolvePushTarget(
    NotificationPushEnvelope envelope,
  ) async {
    final NotificationDataResult<NotificationPushTargetDataRecord?> result =
        await _dataSource.resolvePushTarget(
          deliveryId: envelope.deliveryId,
          householdId: envelope.householdId.value,
          subjectId: envelope.subjectId,
        );
    return switch (result) {
      NotificationDataSucceeded<NotificationPushTargetDataRecord?>(
        :final value,
      ) =>
        _mappedPushTarget(value, envelope),
      NotificationDataFailed<NotificationPushTargetDataRecord?>(:final kind) =>
        NotificationFailed<NotificationPushTarget?>(_mapFailure(kind)),
    };
  }

  NotificationResult<NotificationPushTarget?> _mappedPushTarget(
    NotificationPushTargetDataRecord? record,
    NotificationPushEnvelope envelope,
  ) {
    if (record == null) {
      return const NotificationSucceeded<NotificationPushTarget?>(null);
    }
    final NotificationPushTarget? target = NotificationPushTarget.tryCreate(
      envelope: envelope,
      deliveryId: record.deliveryId,
      householdId: record.householdId,
      category: record.category,
      subjectType: record.subjectType,
      subjectId: record.subjectId,
      inboxItemId: record.inboxItemId,
      safeDestination: record.safeDestination,
    );
    return target == null
        ? const NotificationFailed<NotificationPushTarget?>(
            NotificationFailure(NotificationFailureKind.invalidPayload),
          )
        : NotificationSucceeded<NotificationPushTarget?>(target);
  }

  NotificationResult<NotificationInboxPage> _mappedInboxResult(
    NotificationInboxPageDataRecord record,
    HouseholdId householdId,
  ) {
    final NotificationInboxPage? page = _mapInbox(record, householdId);
    return page == null
        ? const NotificationFailed<NotificationInboxPage>(
            NotificationFailure(NotificationFailureKind.invalidPayload),
          )
        : NotificationSucceeded<NotificationInboxPage>(page);
  }

  NotificationResult<NotificationPreference> _mappedPreferenceResult(
    NotificationPreferenceDataRecord record,
    HouseholdId householdId,
  ) {
    final NotificationPreference? preference = _mapPreference(
      record,
      householdId,
    );
    return preference == null
        ? const NotificationFailed<NotificationPreference>(
            NotificationFailure(NotificationFailureKind.invalidPayload),
          )
        : NotificationSucceeded<NotificationPreference>(preference);
  }

  NotificationResult<NotificationReadReceipt> _mapReadResult(
    NotificationDataResult<NotificationReadDataRecord> result,
  ) {
    return switch (result) {
      NotificationDataSucceeded<NotificationReadDataRecord>(:final value) =>
        _readReceipt(value),
      NotificationDataFailed<NotificationReadDataRecord>(:final kind) =>
        NotificationFailed<NotificationReadReceipt>(_mapFailure(kind)),
    };
  }

  NotificationResult<NotificationReadReceipt> _readReceipt(
    NotificationReadDataRecord record,
  ) {
    final DateTime? markedAt = DateTime.tryParse(record.markedAt)?.toUtc();
    if (markedAt == null || record.markedCount < 0 || record.unreadCount < 0) {
      return const NotificationFailed<NotificationReadReceipt>(
        NotificationFailure(NotificationFailureKind.invalidPayload),
      );
    }
    return NotificationSucceeded<NotificationReadReceipt>(
      NotificationReadReceipt(
        markedCount: record.markedCount,
        unreadCount: record.unreadCount,
        markedAt: markedAt,
      ),
    );
  }

  NotificationResult<NotificationSnoozeReceipt> _mappedSnoozeReceipt(
    NotificationSnoozeDataRecord record, {
    required NotificationSnoozeCommandId expectedCommandId,
    required NotificationInboxItemId expectedInboxItemId,
    required int expectedItemVersion,
    required int expectedSnoozeMinutes,
  }) {
    final NotificationSnoozeCommandId? commandId =
        NotificationSnoozeCommandId.tryParse(record.commandId);
    final NotificationInboxItemId? inboxItemId =
        NotificationInboxItemId.tryParse(record.inboxItemId);
    final DateTime? snoozedUntil = DateTime.tryParse(
      record.snoozedUntil,
    )?.toUtc();
    final DateTime? recordedAt = DateTime.tryParse(record.recordedAt)?.toUtc();
    if (commandId != expectedCommandId ||
        inboxItemId != expectedInboxItemId ||
        snoozedUntil == null ||
        recordedAt == null ||
        record.itemVersion != expectedItemVersion + 1 ||
        record.snoozeMinutes != expectedSnoozeMinutes) {
      return const NotificationFailed<NotificationSnoozeReceipt>(
        NotificationFailure(NotificationFailureKind.invalidPayload),
      );
    }
    final NotificationSnoozeReceipt? receipt =
        NotificationSnoozeReceipt.tryCreate(
          commandId: commandId!,
          sourceEventId: record.sourceEventId,
          inboxItemId: inboxItemId!,
          itemVersion: record.itemVersion,
          snoozedUntil: snoozedUntil,
          snoozeMinutes: record.snoozeMinutes,
          snoozeCount: record.snoozeCount,
          unreadCount: record.unreadCount,
          recordedAt: recordedAt,
        );
    return receipt == null
        ? const NotificationFailed<NotificationSnoozeReceipt>(
            NotificationFailure(NotificationFailureKind.invalidPayload),
          )
        : NotificationSucceeded<NotificationSnoozeReceipt>(receipt);
  }

  List<NotificationPreference>? _mapPreferences(
    List<NotificationPreferenceDataRecord> records,
    HouseholdId householdId,
  ) {
    if (records.length != NotificationCategory.values.length) {
      return null;
    }
    final List<NotificationPreference> preferences = <NotificationPreference>[];
    final Set<NotificationCategory> categories = <NotificationCategory>{};
    for (final NotificationPreferenceDataRecord record in records) {
      final NotificationPreference? preference = _mapPreference(
        record,
        householdId,
      );
      if (preference == null || !categories.add(preference.category)) {
        return null;
      }
      preferences.add(preference);
    }
    preferences.sort((a, b) => a.category.index.compareTo(b.category.index));
    return preferences;
  }

  NotificationPreference? _mapPreference(
    NotificationPreferenceDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final HouseholdId? householdId = HouseholdId.tryParse(record.householdId);
    final NotificationCategory? category = NotificationCategory.tryParse(
      record.category,
    );
    final String? quietStart = _normalizeTime(record.quietStart);
    final String? quietEnd = _normalizeTime(record.quietEnd);
    final DateTime? updatedAt = record.updatedAt == null
        ? null
        : DateTime.tryParse(record.updatedAt!)?.toUtc();
    if (householdId != expectedHouseholdId ||
        category == null ||
        (record.isDefault &&
            (record.reminderLeadMinutes != 0 ||
                record.additionalReminderLeadMinutes.isNotEmpty)) ||
        (record.quietStart != null && quietStart == null) ||
        (record.quietEnd != null && quietEnd == null) ||
        (record.updatedAt != null && updatedAt == null)) {
      return null;
    }
    return NotificationPreference.tryCreate(
      householdId: householdId!,
      category: category,
      nativePush: record.nativePush,
      webPush: record.webPush,
      email: record.email,
      inApp: record.inApp,
      quietStart: quietStart,
      quietEnd: quietEnd,
      timezone: record.timezone,
      reminderLeadMinutes: record.reminderLeadMinutes,
      additionalReminderLeadMinutes: record.additionalReminderLeadMinutes,
      updatedAt: updatedAt,
      version: record.version,
      isDefault: record.isDefault,
    );
  }

  NotificationInboxPage? _mapInbox(
    NotificationInboxPageDataRecord record,
    HouseholdId expectedHouseholdId,
  ) {
    final List<NotificationInboxItem> items = <NotificationInboxItem>[];
    final Set<NotificationInboxItemId> ids = <NotificationInboxItemId>{};
    DateTime? previousCreatedAt;
    NotificationInboxItemId? previousId;
    for (final NotificationInboxItemDataRecord itemRecord in record.items) {
      final HouseholdId? householdId = HouseholdId.tryParse(
        itemRecord.householdId,
      );
      final NotificationInboxItemId? id = NotificationInboxItemId.tryParse(
        itemRecord.inboxItemId,
      );
      final NotificationCategory? category = NotificationCategory.tryParse(
        itemRecord.category,
      );
      final DateTime? scheduledAt = DateTime.tryParse(
        itemRecord.scheduledAt,
      )?.toUtc();
      final DateTime? createdAt = DateTime.tryParse(
        itemRecord.createdAt,
      )?.toUtc();
      final DateTime? readAt = itemRecord.readAt == null
          ? null
          : DateTime.tryParse(itemRecord.readAt!)?.toUtc();
      if (householdId != expectedHouseholdId ||
          id == null ||
          !ids.add(id) ||
          category == null ||
          scheduledAt == null ||
          createdAt == null ||
          (itemRecord.readAt != null && readAt == null) ||
          previousCreatedAt != null &&
              (createdAt.isAfter(previousCreatedAt) ||
                  createdAt == previousCreatedAt &&
                      id.value.compareTo(previousId!.value) >= 0)) {
        return null;
      }
      final NotificationInboxItem? item = NotificationInboxItem.tryCreate(
        id: id,
        itemVersion: itemRecord.itemVersion,
        sourceEventId: itemRecord.sourceEventId,
        householdId: householdId!,
        category: category,
        subjectType: itemRecord.subjectType,
        subjectId: itemRecord.subjectId,
        scheduledAt: scheduledAt,
        createdAt: createdAt,
        readAt: readAt,
        snoozeCount: itemRecord.snoozeCount,
        snoozeMaxMinutes: itemRecord.snoozeMaxMinutes,
        payload: itemRecord.payload,
      );
      if (item == null) {
        return null;
      }
      items.add(item);
      previousCreatedAt = createdAt;
      previousId = id;
    }
    final DateTime? cursorCreatedAt = record.nextBeforeCreatedAt == null
        ? null
        : DateTime.tryParse(record.nextBeforeCreatedAt!)?.toUtc();
    final NotificationInboxItemId? cursorId = record.nextBeforeId == null
        ? null
        : NotificationInboxItemId.tryParse(record.nextBeforeId!);
    if (record.hasMore != (cursorCreatedAt != null && cursorId != null) ||
        (!record.hasMore &&
            (record.nextBeforeCreatedAt != null ||
                record.nextBeforeId != null)) ||
        record.hasMore &&
            (items.isEmpty ||
                cursorCreatedAt != items.last.createdAt ||
                cursorId != items.last.id)) {
      return null;
    }
    return NotificationInboxPage(
      items: items,
      hasMore: record.hasMore,
      nextCursor: record.hasMore
          ? NotificationInboxCursor(createdAt: cursorCreatedAt!, id: cursorId!)
          : null,
    );
  }

  String? _normalizeTime(String? value) {
    if (value == null) {
      return null;
    }
    final RegExpMatch? match = RegExp(
      r'^(\d{2}):(\d{2})(?::00(?:\.0+)?)?$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    final int hour = int.parse(match.group(1)!);
    final int minute = int.parse(match.group(2)!);
    return hour < 24 && minute < 60
        ? '${match.group(1)}:${match.group(2)}'
        : null;
  }

  NotificationFailure _mapFailure(NotificationDataFailureKind kind) {
    return NotificationFailure(switch (kind) {
      NotificationDataFailureKind.unauthenticated =>
        NotificationFailureKind.unauthenticated,
      NotificationDataFailureKind.invalidInput =>
        NotificationFailureKind.invalidInput,
      NotificationDataFailureKind.notFoundOrForbidden =>
        NotificationFailureKind.notFoundOrForbidden,
      NotificationDataFailureKind.versionConflict =>
        NotificationFailureKind.versionConflict,
      NotificationDataFailureKind.snoozeUnavailable =>
        NotificationFailureKind.snoozeUnavailable,
      NotificationDataFailureKind.temporarilyUnavailable =>
        NotificationFailureKind.temporarilyUnavailable,
      NotificationDataFailureKind.invalidPayload =>
        NotificationFailureKind.invalidPayload,
      NotificationDataFailureKind.unknown => NotificationFailureKind.unknown,
    });
  }
}
