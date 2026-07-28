import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';

abstract interface class HouseholdCreationIdGenerator {
  HouseholdCreationId generate();
}
