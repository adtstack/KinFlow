import 'package:flutter/services.dart';
import 'package:kinflow_app/features/settings/application/ports/diagnostic_clipboard.dart';

typedef DiagnosticClipboardWriter = Future<void> Function(String text);

final class FlutterDiagnosticClipboard implements DiagnosticClipboard {
  const FlutterDiagnosticClipboard({
    this.writer = writeDiagnosticClipboardText,
  });

  final DiagnosticClipboardWriter writer;

  @override
  Future<bool> write(String text) async {
    try {
      await writer(text);
      return true;
    } on Object {
      return false;
    }
  }
}

Future<void> writeDiagnosticClipboardText(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}
