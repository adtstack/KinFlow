import 'package:kinflow_app/features/settings/application/ports/diagnostic_clipboard.dart';

final class UnavailableDiagnosticClipboard implements DiagnosticClipboard {
  const UnavailableDiagnosticClipboard();

  @override
  Future<bool> write(String text) async => false;
}
