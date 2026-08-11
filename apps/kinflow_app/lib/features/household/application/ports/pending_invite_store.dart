import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

abstract interface class PendingInviteStore {
  InviteToken? read();

  InviteShortCode? readShortCode();

  bool capture(String rawToken);

  bool captureShortCode(String rawShortCode);

  void clear();
}
