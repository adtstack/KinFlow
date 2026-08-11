import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/domain/services/icalendar_import_parser.dart';
import 'package:kinflow_app/infrastructure/calendar/method_channel_calendar_import_file_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel channel = MethodChannel('calendar-import-test');
  const MethodChannelCalendarImportFileGateway gateway =
      MethodChannelCalendarImportFileGateway(channel: channel);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('maps an exact selected file without exposing a URI', () async {
    MethodCall? captured;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          captured = call;
          return <String, Object?>{
            'status': 'selected',
            'displayName': 'family.ics',
            'content': 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR',
          };
        });

    final CalendarImportFilePickResult result = await gateway.pick();

    expect(captured!.method, MethodChannelCalendarImportFileGateway.pickMethod);
    expect(captured!.arguments, isNull);
    final CalendarImportFile file = (result as CalendarImportFileSelected).file;
    expect(file.displayName, 'family.ics');
    expect(file.content, contains('VCALENDAR'));
  });

  test(
    'maps cancellation unavailable and native size status exactly',
    () async {
      for (final ({String status, Type type}) fixture
          in <({String status, Type type})>[
            (status: 'cancelled', type: CalendarImportFilePickCancelled),
            (status: 'unavailable', type: CalendarImportFilePickerUnavailable),
            (status: 'too_large', type: CalendarImportFileTooLarge),
            (status: 'failed', type: CalendarImportFilePickFailed),
          ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (MethodCall call) async => <String, Object?>{
                'status': fixture.status,
              },
            );

        expect((await gateway.pick()).runtimeType, fixture.type);
      }
    },
  );

  test(
    'fails closed for extra keys, wrong types, names and oversized text',
    () async {
      final List<Object?> payloads = <Object?>[
        <String, Object?>{'status': 'cancelled', 'uri': 'content://secret'},
        <String, Object?>{
          'status': 'selected',
          'displayName': 7,
          'content': 'x',
        },
        <String, Object?>{
          'status': 'selected',
          'displayName': ' bad.ics ',
          'content': 'x',
        },
        <String, Object?>{
          'status': 'selected',
          'displayName': 'calendar.txt',
          'content': 'x',
        },
        <String, Object?>{
          'status': 'selected',
          'displayName': 'large.ics',
          'content': 'x' * (IcalendarImportParser.maximumBytes + 1),
        },
        <String, Object?>{'status': 'unknown'},
        'not-a-map',
      ];
      for (final Object? payload in payloads) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (MethodCall call) async => payload,
            );

        expect(await gateway.pick(), isA<CalendarImportFilePickFailed>());
      }
    },
  );

  test('distinguishes missing plugin from platform read failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await gateway.pick(), isA<CalendarImportFilePickerUnavailable>());

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          throw PlatformException(code: 'read_failed');
        });
    expect(await gateway.pick(), isA<CalendarImportFilePickFailed>());
  });
}
