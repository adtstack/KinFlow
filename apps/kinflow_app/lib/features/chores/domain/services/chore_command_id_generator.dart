import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';

abstract interface class ChoreCommandIdGenerator {
  ChoreCommandId generate();
}
