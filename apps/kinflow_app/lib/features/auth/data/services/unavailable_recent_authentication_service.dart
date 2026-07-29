import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';

final class UnavailableRecentAuthenticationService
    implements RecentAuthenticationService {
  const UnavailableRecentAuthenticationService();

  @override
  bool get isAvailable => false;

  @override
  Future<RecentAuthenticationResult> authenticate() async {
    return const RecentAuthenticationFailed(
      RecentAuthenticationFailureKind.providerUnavailable,
    );
  }
}
