import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/household/application/ports/pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class EphemeralPendingInviteStore
    implements PendingInviteStore, SensitiveLocalStatePurgeParticipant {
  InviteToken? _token;

  @override
  InviteToken? read() => _token;

  @override
  bool capture(String rawToken) {
    final InviteToken? token = InviteToken.tryParse(rawToken);
    if (token == null) {
      return false;
    }
    _token = token;
    return true;
  }

  @override
  void clear() {
    _token = null;
  }

  @override
  Future<void> purgeSensitiveLocalState() async {
    clear();
  }
}
