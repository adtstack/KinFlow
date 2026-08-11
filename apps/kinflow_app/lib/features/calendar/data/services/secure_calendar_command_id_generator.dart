import 'dart:math';

import 'package:kinflow_app/features/calendar/domain/services/calendar_command_id_generator.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';

final class SecureCalendarCommandIdGenerator
    implements CalendarCommandIdGenerator {
  SecureCalendarCommandIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  CalendarEventCommandId generate() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes
        .map((int value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    final String uuid =
        '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    final CalendarEventCommandId? id = CalendarEventCommandId.tryParse(uuid);
    if (id == null) {
      throw StateError('Secure Calendar command UUID generation failed.');
    }
    return id;
  }
}
