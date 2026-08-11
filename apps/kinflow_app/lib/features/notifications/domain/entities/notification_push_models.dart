import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';

const String notificationPushContractVersion = '2026-08-08-wp05-04';

final RegExp _pushUuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
final RegExp _pushControlCharacterPattern = RegExp(r'[\x00-\x1f\x7f]');

enum NotificationPushPermission {
  unavailable,
  notDetermined,
  denied,
  authorized,
}

enum NotificationPushSafeDestination {
  choreOccurrence('chore_occurrence'),
  calendarEvent('calendar_event');

  const NotificationPushSafeDestination(this.wireValue);

  final String wireValue;

  static NotificationPushSafeDestination? tryParse(String value) {
    for (final NotificationPushSafeDestination destination in values) {
      if (destination.wireValue == value) return destination;
    }
    return null;
  }
}

final class NotificationPushEnvelope {
  const NotificationPushEnvelope._({
    required this.deliveryId,
    required this.sourceEventId,
    required this.householdId,
    required this.inboxItemId,
    required this.category,
    required this.subjectId,
  });

  static const Set<String> _requiredKeys = <String>{
    'category',
    'contractVersion',
    'deliveryId',
    'householdId',
    'sourceEventId',
    'subjectId',
    'subjectType',
  };

  final String deliveryId;
  final String sourceEventId;
  final HouseholdId householdId;
  final NotificationInboxItemId? inboxItemId;
  final NotificationCategory category;
  final String subjectId;

  static NotificationPushEnvelope? tryParse(Map<String, Object?> data) {
    final Set<String> keys = data.keys.toSet();
    final bool hasInboxItem = keys.contains('inboxItemId');
    final Set<String> expected = <String>{
      ..._requiredKeys,
      if (hasInboxItem) 'inboxItemId',
    };
    if (keys.length != expected.length || !keys.containsAll(expected)) {
      return null;
    }
    for (final Object? value in data.values) {
      if (value is! String) return null;
    }

    final String deliveryId = (data['deliveryId']! as String).toLowerCase();
    final String sourceEventId = (data['sourceEventId']! as String)
        .toLowerCase();
    final String subjectId = (data['subjectId']! as String).toLowerCase();
    final HouseholdId? householdId = HouseholdId.tryParse(
      data['householdId']! as String,
    );
    final NotificationInboxItemId? inboxItemId = hasInboxItem
        ? NotificationInboxItemId.tryParse(data['inboxItemId']! as String)
        : null;
    final NotificationCategory? category = NotificationCategory.tryParse(
      data['category']! as String,
    );
    if (data['contractVersion'] != notificationPushContractVersion ||
        !_pushUuidPattern.hasMatch(deliveryId) ||
        !_pushUuidPattern.hasMatch(sourceEventId) ||
        householdId == null ||
        hasInboxItem && inboxItemId == null ||
        category == null ||
        data['subjectType'] != category.subjectType ||
        !_pushUuidPattern.hasMatch(subjectId)) {
      return null;
    }
    return NotificationPushEnvelope._(
      deliveryId: deliveryId,
      sourceEventId: sourceEventId,
      householdId: householdId,
      inboxItemId: inboxItemId,
      category: category,
      subjectId: subjectId,
    );
  }

  Map<String, String> toData() => <String, String>{
    'category': category.wireValue,
    'contractVersion': notificationPushContractVersion,
    'deliveryId': deliveryId,
    'householdId': householdId.value,
    if (inboxItemId != null) 'inboxItemId': inboxItemId!.value,
    'sourceEventId': sourceEventId,
    'subjectId': subjectId,
    'subjectType': category.subjectType,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationPushEnvelope && other.deliveryId == deliveryId;

  @override
  int get hashCode => deliveryId.hashCode;

  @override
  String toString() => 'NotificationPushEnvelope(deliveryId: redacted)';
}

final class NotificationPushTarget {
  const NotificationPushTarget._({
    required this.envelope,
    required this.destination,
  });

  final NotificationPushEnvelope envelope;
  final NotificationPushSafeDestination destination;

  static NotificationPushTarget? tryCreate({
    required NotificationPushEnvelope envelope,
    required String deliveryId,
    required String householdId,
    required String category,
    required String subjectType,
    required String subjectId,
    required String? inboxItemId,
    required String safeDestination,
  }) {
    final NotificationPushSafeDestination? destination =
        NotificationPushSafeDestination.tryParse(safeDestination);
    final NotificationPushSafeDestination expectedDestination =
        envelope.category.subjectType == 'chore_occurrence'
        ? NotificationPushSafeDestination.choreOccurrence
        : NotificationPushSafeDestination.calendarEvent;
    if (deliveryId.toLowerCase() != envelope.deliveryId ||
        householdId.toLowerCase() != envelope.householdId.value ||
        category != envelope.category.wireValue ||
        subjectType != envelope.category.subjectType ||
        subjectId.toLowerCase() != envelope.subjectId ||
        inboxItemId?.toLowerCase() != envelope.inboxItemId?.value ||
        destination == null ||
        destination != expectedDestination) {
      return null;
    }
    return NotificationPushTarget._(
      envelope: envelope,
      destination: destination,
    );
  }
}

final class NotificationPushPresentationContent {
  const NotificationPushPresentationContent._({
    required this.title,
    required this.body,
    required this.channelName,
    required this.channelDescription,
  });

  final String title;
  final String body;
  final String channelName;
  final String channelDescription;

  static NotificationPushPresentationContent? tryCreate({
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) {
    if (!_validPresentationText(title, 1, 80) ||
        !_validPresentationText(body, 1, 160) ||
        !_validPresentationText(channelName, 1, 80) ||
        !_validPresentationText(channelDescription, 1, 160)) {
      return null;
    }
    return NotificationPushPresentationContent._(
      title: title,
      body: body,
      channelName: channelName,
      channelDescription: channelDescription,
    );
  }
}

bool _validPresentationText(String value, int minimum, int maximum) {
  return value.length >= minimum &&
      value.length <= maximum &&
      value == value.trim() &&
      !_pushControlCharacterPattern.hasMatch(value);
}

enum NotificationPushNavigationDestination {
  choreOccurrence,
  calendarEvent,
  notificationCenter,
}

final class NotificationPushNavigationIntent {
  const NotificationPushNavigationIntent({
    required this.destination,
    required this.deliveryId,
    required this.subjectId,
  }) : assert(
         (destination ==
                 NotificationPushNavigationDestination.notificationCenter) ==
             (subjectId == null),
       );

  final NotificationPushNavigationDestination destination;
  final String deliveryId;
  final String? subjectId;
}

enum NotificationPushFailureKind {
  permissionUnavailable,
  tokenUnavailable,
  registrationUnavailable,
  presentationUnavailable,
  targetAuthorizationUnavailable,
  invalidConfiguration,
}

final class NotificationPushState {
  const NotificationPushState({
    required this.permission,
    required this.busy,
    required this.permissionRequestAttempted,
    required this.endpointRegistered,
    required this.failure,
  });

  const NotificationPushState.unavailable()
    : permission = NotificationPushPermission.unavailable,
      busy = false,
      permissionRequestAttempted = false,
      endpointRegistered = false,
      failure = null;

  final NotificationPushPermission permission;
  final bool busy;
  final bool permissionRequestAttempted;
  final bool endpointRegistered;
  final NotificationPushFailureKind? failure;
}
