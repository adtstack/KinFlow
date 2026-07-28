import 'package:kinflow_app/features/auth/application/ports/sensitive_local_state_purger.dart';
import 'package:kinflow_app/infrastructure/google/google_identity_gateway.dart';

final class GoogleIdentityStatePurgeParticipant
    implements SensitiveLocalStatePurgeParticipant {
  const GoogleIdentityStatePurgeParticipant({
    required this.serverClientId,
    required this.identityGateway,
  });

  final String serverClientId;
  final GoogleIdentityGateway identityGateway;

  @override
  Future<void> purgeSensitiveLocalState() {
    return identityGateway.signOut(serverClientId: serverClientId);
  }
}
