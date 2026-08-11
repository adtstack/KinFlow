import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';

abstract interface class BillingAssignmentCommandIdGenerator {
  BillingAssignmentCommandId generate();
}
