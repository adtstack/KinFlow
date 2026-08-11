import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/domain/services/icalendar_import_parser.dart';

final class MethodChannelCalendarImportFileGateway
    implements CalendarImportFileGateway {
  const MethodChannelCalendarImportFileGateway({
    this.channel = const MethodChannel(channelName),
  });

  static const String channelName = 'me.newlines.kinflow/calendar_import';
  static const String pickMethod = 'pickIcalendarFile';

  final MethodChannel channel;

  @override
  Future<CalendarImportFilePickResult> pick() async {
    try {
      final Object? raw = await channel.invokeMethod<Object?>(pickMethod);
      final Map<String, Object?>? value = _stringObjectMap(raw);
      if (value == null || value['status'] is! String) {
        return const CalendarImportFilePickFailed();
      }
      return switch (value['status']) {
        'selected'
            when _hasExactKeys(value, const <String>{
              'status',
              'displayName',
              'content',
            }) =>
          _selected(value),
        'cancelled' when _hasExactKeys(value, const <String>{'status'}) =>
          const CalendarImportFilePickCancelled(),
        'unavailable' when _hasExactKeys(value, const <String>{'status'}) =>
          const CalendarImportFilePickerUnavailable(),
        'too_large' when _hasExactKeys(value, const <String>{'status'}) =>
          const CalendarImportFileTooLarge(),
        'failed' when _hasExactKeys(value, const <String>{'status'}) =>
          const CalendarImportFilePickFailed(),
        _ => const CalendarImportFilePickFailed(),
      };
    } on MissingPluginException {
      return const CalendarImportFilePickerUnavailable();
    } on PlatformException {
      return const CalendarImportFilePickFailed();
    } on Object {
      return const CalendarImportFilePickFailed();
    }
  }

  CalendarImportFilePickResult _selected(Map<String, Object?> value) {
    if (value['displayName'] is! String || value['content'] is! String) {
      return const CalendarImportFilePickFailed();
    }
    final String displayName = value['displayName']! as String;
    final String content = value['content']! as String;
    if (displayName.trim() != displayName ||
        displayName.isEmpty ||
        displayName.length > 120 ||
        !displayName.toLowerCase().endsWith('.ics') ||
        displayName.codeUnits.any((int unit) => unit < 32 || unit == 127) ||
        utf8.encode(content).length > IcalendarImportParser.maximumBytes) {
      return const CalendarImportFilePickFailed();
    }
    return CalendarImportFileSelected(
      CalendarImportFile(displayName: displayName, content: content),
    );
  }
}

Map<String, Object?>? _stringObjectMap(Object? raw) {
  if (raw is! Map<Object?, Object?>) return null;
  final Map<String, Object?> result = <String, Object?>{};
  for (final MapEntry<Object?, Object?> entry in raw.entries) {
    if (entry.key is! String) return null;
    result[entry.key! as String] = entry.value;
  }
  return result;
}

bool _hasExactKeys(Map<String, Object?> value, Set<String> keys) {
  return value.length == keys.length && value.keys.toSet().containsAll(keys);
}
