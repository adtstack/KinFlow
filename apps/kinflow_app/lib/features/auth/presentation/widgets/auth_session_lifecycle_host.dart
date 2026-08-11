import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';

/// Revalidates the authenticated session when the app shell returns to the
/// foreground. Initial restoration remains owned by the auth controller.
class AuthSessionLifecycleHost extends ConsumerStatefulWidget {
  const AuthSessionLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AuthSessionLifecycleHost> createState() =>
      _AuthSessionLifecycleHostState();
}

class _AuthSessionLifecycleHostState
    extends ConsumerState<AuthSessionLifecycleHost>
    with WidgetsBindingObserver {
  var _refreshInFlight = false;
  var _trailingRefreshRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    _requestRefresh();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authLifecycleProvider);
    return widget.child;
  }

  void _requestRefresh() {
    if (_refreshInFlight) {
      _trailingRefreshRequested = true;
      return;
    }
    if (!_isRefreshEligible(ref.read(authLifecycleProvider))) {
      return;
    }

    _refreshInFlight = true;
    scheduleMicrotask(() => unawaited(_drainRefreshRequests()));
  }

  Future<void> _drainRefreshRequests() async {
    try {
      do {
        _trailingRefreshRequested = false;
        if (!mounted) {
          return;
        }
        final AuthLifecycleState state = ref.read(authLifecycleProvider);
        if (!_isRefreshEligible(state)) {
          return;
        }
        await ref.read(authLifecycleProvider.notifier).revalidateOnResume();
      } while (mounted && _trailingRefreshRequested);
    } finally {
      _refreshInFlight = false;
      _trailingRefreshRequested = false;
    }
  }

  bool _isRefreshEligible(AuthLifecycleState state) {
    return state is AuthAuthenticatedNoHousehold ||
        state is AuthAuthenticatedActiveHousehold;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
