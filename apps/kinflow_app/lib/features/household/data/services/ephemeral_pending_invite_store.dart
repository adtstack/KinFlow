import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/features/household/application/ports/pending_invite_store.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';

final class EphemeralPendingInviteStore
    implements PendingInviteStore, SensitiveLocalStatePurgeParticipant {
  InviteToken? _token;
  InviteShortCode? _shortCode;

  @override
  InviteToken? read() => _token;

  @override
  InviteShortCode? readShortCode() => _shortCode;

  @override
  bool capture(String rawToken) {
    final InviteToken? token = InviteToken.tryParse(rawToken);
    if (token == null) {
      clear();
      return false;
    }
    _token = token;
    _shortCode = null;
    return true;
  }

  @override
  bool captureShortCode(String rawShortCode) {
    final InviteShortCode? shortCode = InviteShortCode.tryParse(rawShortCode);
    if (shortCode == null) {
      clear();
      return false;
    }
    _token = null;
    _shortCode = shortCode;
    return true;
  }

  @override
  void clear() {
    _token = null;
    _shortCode = null;
  }

  @override
  Future<void> purgeSensitiveLocalState() async {
    clear();
  }
}
