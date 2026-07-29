import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/domain/services/recent_authentication_service.dart';

final recentAuthenticationServiceProvider =
    Provider<RecentAuthenticationService>((ref) {
      throw StateError('RecentAuthenticationService override is required.');
    });
