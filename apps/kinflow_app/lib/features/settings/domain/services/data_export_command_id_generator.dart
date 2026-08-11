import 'package:kinflow_app/features/settings/domain/value_objects/data_export_identifiers.dart';

abstract interface class DataExportCommandIdGenerator {
  DataExportCommandId generate();
}
