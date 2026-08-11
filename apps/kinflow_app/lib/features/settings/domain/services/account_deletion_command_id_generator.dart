import 'package:kinflow_app/features/settings/domain/value_objects/account_deletion_identifiers.dart';

abstract interface class AccountDeletionCommandIdGenerator {
  AccountDeletionCommandId generate();
}
