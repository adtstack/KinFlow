import 'package:kinflow_app/features/calendar/application/ports/calendar_import_file_gateway.dart';
import 'package:kinflow_app/features/calendar/application/unavailable_calendar_import_file_gateway.dart';
import 'package:kinflow_app/infrastructure/calendar/method_channel_calendar_import_file_gateway.dart';

CalendarImportFileGateway createCalendarImportFileGateway() {
  return const MethodChannelCalendarImportFileGateway();
}

CalendarImportFileGateway createUnavailableCalendarImportFileGateway() {
  return const UnavailableCalendarImportFileGateway();
}
