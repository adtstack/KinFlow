import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:kinflow_app/app/observability/app_log_record.dart';
import 'package:kinflow_app/app/observability/app_logger.dart';

final class JsonConsoleLogSink implements AppLogSink {
  JsonConsoleLogSink({void Function(String message)? writer})
    : _writer = writer ?? debugPrint;

  final void Function(String message) _writer;

  @override
  void write(AppLogRecord record) {
    _writer(jsonEncode(record.toJson()));
  }
}
