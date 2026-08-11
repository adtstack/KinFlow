import 'dart:math';

import 'package:kinflow_app/features/settings/domain/services/account_deletion_command_id_generator.dart';
import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

final class SecureAccountDeletionCommandIdGenerator
    implements AccountDeletionCommandIdGenerator {
  SecureAccountDeletionCommandIdGenerator({Random? random})
    : _random = random ?? Random.secure();

  final Random _random;

  @override
  AccountDeletionCommandId generate() {
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
    final String value =
        '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
    final AccountDeletionCommandId? id = AccountDeletionCommandId.tryParse(
      value,
    );
    if (id == null) {
      throw StateError('Secure UUID generation produced an invalid value.');
    }
    return id;
  }
}
