import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';

final class UnavailableCalendarImportFileGateway
    implements CalendarImportFileGateway {
  const UnavailableCalendarImportFileGateway();

  @override
  Future<CalendarImportFilePickResult> pick() async {
    return const CalendarImportFilePickerUnavailable();
  }
}
