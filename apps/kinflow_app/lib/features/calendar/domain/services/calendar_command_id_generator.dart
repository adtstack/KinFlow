import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';

abstract interface class CalendarCommandIdGenerator {
  CalendarEventCommandId generate();
}
