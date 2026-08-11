import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/services/billing_assignment_command_id_generator.dart';

final class UnavailableBillingAssignmentCommandIdGenerator
    implements BillingAssignmentCommandIdGenerator {
  const UnavailableBillingAssignmentCommandIdGenerator();

  @override
  BillingAssignmentCommandId generate() {
    throw StateError('Billing assignment command generation is unavailable.');
  }
}
