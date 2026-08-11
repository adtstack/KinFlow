import 'dart:math';

import 'package:kinflow_app/features/billing/domain/entities/billing_assignment.dart';
import 'package:kinflow_app/features/billing/domain/services/billing_assignment_command_id_generator.dart';

final class SecureBillingAssignmentCommandIdGenerator
    implements BillingAssignmentCommandIdGenerator {
  SecureBillingAssignmentCommandIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  BillingAssignmentCommandId generate() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final String hex = bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final BillingAssignmentCommandId? id = BillingAssignmentCommandId.tryParse(
      '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}',
    );
    if (id == null) {
      throw StateError('Secure UUID generation produced an invalid value.');
    }
    return id;
  }
}
