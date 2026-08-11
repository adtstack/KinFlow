final class CalendarImportFile {
  const CalendarImportFile({required this.displayName, required this.content});

  final String displayName;
  final String content;
}

sealed class CalendarImportFilePickResult {
  const CalendarImportFilePickResult();
}

final class CalendarImportFileSelected extends CalendarImportFilePickResult {
  const CalendarImportFileSelected(this.file);

  final CalendarImportFile file;
}

final class CalendarImportFilePickCancelled
    extends CalendarImportFilePickResult {
  const CalendarImportFilePickCancelled();
}

final class CalendarImportFilePickerUnavailable
    extends CalendarImportFilePickResult {
  const CalendarImportFilePickerUnavailable();
}

final class CalendarImportFileTooLarge extends CalendarImportFilePickResult {
  const CalendarImportFileTooLarge();
}

final class CalendarImportFilePickFailed extends CalendarImportFilePickResult {
  const CalendarImportFilePickFailed();
}

abstract interface class CalendarImportFileGateway {
  Future<CalendarImportFilePickResult> pick();
}
