import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

abstract interface class InviteCommandIdGenerator {
  InviteCommandId generate();
}
