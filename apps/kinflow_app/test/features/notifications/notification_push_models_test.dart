import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/infrastructure/firebase/firebase_notification_push_gateway.dart';
import 'package:kinflow_app/infrastructure/firebase/flutter_local_notification_presenter.dart';

const String _deliveryId = '84000000-0000-4000-8000-000000000001';
const String _sourceEventId = '84010000-0000-4000-8000-000000000001';
const String _householdId = '22222222-2222-4222-8222-222222222222';
const String _inboxItemId = '84020000-0000-4000-8000-000000000001';
const String _subjectId = '84030000-0000-4000-8000-000000000001';

void main() {
  test('push envelope accepts only the exact versioned routing shape', () {
    final NotificationPushEnvelope? envelope =
        NotificationPushEnvelope.tryParse(_data());

    expect(envelope, isNotNull);
    expect(envelope?.deliveryId, _deliveryId);
    expect(envelope?.inboxItemId?.value, _inboxItemId);
    expect(envelope?.toData(), _data());
    expect(envelope.toString(), isNot(contains(_deliveryId)));

    final Map<String, String> calendarData = <String, String>{
      ..._data(),
      'category': 'calendar_event',
      'subjectType': 'calendar_occurrence',
    };
    final NotificationPushEnvelope? calendarEnvelope =
        NotificationPushEnvelope.tryParse(calendarData);
    expect(calendarEnvelope?.category.wireValue, 'calendar_event');
    expect(calendarEnvelope?.toData(), calendarData);

    expect(
      NotificationPushEnvelope.tryParse(<String, Object?>{
        ..._data(),
        'title': 'private chore name',
      }),
      isNull,
    );
    expect(
      NotificationPushEnvelope.tryParse(<String, Object?>{
        ..._data(),
        'contractVersion': '2026-08-08-other',
      }),
      isNull,
    );
    expect(
      NotificationPushEnvelope.tryParse(<String, Object?>{
        ..._data()..remove('inboxItemId'),
        'subjectType': 'calendar_occurrence',
      }),
      isNull,
    );
    expect(
      NotificationPushEnvelope.tryParse(<String, Object?>{
        ...calendarData,
        'subjectType': 'chore_occurrence',
      }),
      isNull,
    );
  });

  test('authenticated target must echo the exact envelope', () {
    final NotificationPushEnvelope envelope = NotificationPushEnvelope.tryParse(
      _data(),
    )!;

    expect(
      _target(envelope)?.destination,
      NotificationPushSafeDestination.choreOccurrence,
    );
    expect(
      NotificationPushTarget.tryCreate(
        envelope: envelope,
        deliveryId: _deliveryId,
        householdId: _householdId,
        category: 'chore_due',
        subjectType: 'chore_occurrence',
        subjectId: _subjectId,
        inboxItemId: _inboxItemId,
        safeDestination: 'calendar_event',
      ),
      isNull,
    );
    expect(
      NotificationPushTarget.tryCreate(
        envelope: envelope,
        deliveryId: _deliveryId,
        householdId: _householdId,
        category: 'chore_due',
        subjectType: 'chore_occurrence',
        subjectId: _subjectId,
        inboxItemId: _inboxItemId,
        safeDestination: 'today',
      ),
      isNull,
    );
    expect(
      NotificationPushTarget.tryCreate(
        envelope: envelope,
        deliveryId: _deliveryId,
        householdId: _householdId,
        category: 'chore_due',
        subjectType: 'chore_occurrence',
        subjectId: '84030000-0000-4000-8000-000000000002',
        inboxItemId: _inboxItemId,
        safeDestination: 'chore_occurrence',
      ),
      isNull,
    );
    expect(
      NotificationPushTarget.tryCreate(
        envelope: envelope,
        deliveryId: _deliveryId,
        householdId: _householdId,
        category: 'chore_due',
        subjectType: 'chore_occurrence',
        subjectId: _subjectId,
        inboxItemId: _inboxItemId,
        safeDestination: '/today?unsafe=true',
      ),
      isNull,
    );
  });

  test('Firebase and local payload adapters share the strict parser', () {
    final NotificationPushEnvelope? remote =
        notificationPushEnvelopeFromRemoteMessage(RemoteMessage(data: _data()));
    final NotificationPushEnvelope? local =
        notificationPushEnvelopeFromLocalPayload(jsonEncode(_data()));

    expect(remote, isNotNull);
    expect(local, remote);
    expect(
      notificationPushEnvelopeFromRemoteMessage(
        const RemoteMessage(data: <String, dynamic>{'deliveryId': _deliveryId}),
      ),
      isNull,
    );
    expect(notificationPushEnvelopeFromLocalPayload('{not-json'), isNull);
    expect(notificationIdForDelivery(_deliveryId), greaterThan(0));
    expect(notificationIdForDelivery('invalid'), 0);
  });

  test('foreground presentation copy is bounded and control-free', () {
    expect(
      NotificationPushPresentationContent.tryCreate(
        title: 'KinFlow reminder',
        body: 'Open KinFlow to view the latest household update.',
        channelName: 'Household reminders',
        channelDescription: 'Generic reminders without private details',
      ),
      isNotNull,
    );
    expect(
      NotificationPushPresentationContent.tryCreate(
        title: 'Private\nname',
        body: 'Body',
        channelName: 'Channel',
        channelDescription: 'Description',
      ),
      isNull,
    );
  });
}

Map<String, String> _data() => <String, String>{
  'category': 'chore_due',
  'contractVersion': notificationPushContractVersion,
  'deliveryId': _deliveryId,
  'householdId': _householdId,
  'inboxItemId': _inboxItemId,
  'sourceEventId': _sourceEventId,
  'subjectId': _subjectId,
  'subjectType': 'chore_occurrence',
};

NotificationPushTarget? _target(NotificationPushEnvelope envelope) {
  return NotificationPushTarget.tryCreate(
    envelope: envelope,
    deliveryId: _deliveryId,
    householdId: _householdId,
    category: 'chore_due',
    subjectType: 'chore_occurrence',
    subjectId: _subjectId,
    inboxItemId: _inboxItemId,
    safeDestination: 'chore_occurrence',
  );
}
