import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';

class AnalyticsLifecycleHost extends ConsumerStatefulWidget {
  const AnalyticsLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AnalyticsLifecycleHost> createState() =>
      _AnalyticsLifecycleHostState();
}

class _AnalyticsLifecycleHostState
    extends ConsumerState<AnalyticsLifecycleHost> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSynchronize(ref.read(authLifecycleProvider));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(analyticsSessionEntryCoordinatorProvider);
    ref.listen<AuthLifecycleState>(authLifecycleProvider, (
      AuthLifecycleState? previous,
      AuthLifecycleState next,
    ) {
      _scheduleSynchronize(next);
    });
    return widget.child;
  }

  void _scheduleSynchronize(AuthLifecycleState authState) {
    scheduleMicrotask(() {
      if (!mounted) return;
      unawaited(
        ref
            .read(analyticsSessionEntryCoordinatorProvider)
            .synchronize(
              authenticatedEntry: analyticsAuthenticatedEntryForAuthState(
                authState,
              ),
            ),
      );
    });
  }
}

bool analyticsAuthenticatedEntryForAuthState(AuthLifecycleState authState) {
  return authState.session != null && authState.activeHousehold != null;
}
