import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/settings/presentation/providers/profile_preferences_providers.dart';

class ProfilePreferencesLifecycleHost extends ConsumerStatefulWidget {
  const ProfilePreferencesLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ProfilePreferencesLifecycleHost> createState() =>
      _ProfilePreferencesLifecycleHostState();
}

class _ProfilePreferencesLifecycleHostState
    extends ConsumerState<ProfilePreferencesLifecycleHost> {
  var _synchronizationGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSynchronize(ref.read(authLifecycleProvider));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(profilePreferencesProvider);
    ref.listen<AuthLifecycleState>(authLifecycleProvider, (
      AuthLifecycleState? previous,
      AuthLifecycleState next,
    ) {
      _scheduleSynchronize(next);
    });
    return widget.child;
  }

  void _scheduleSynchronize(AuthLifecycleState authState) {
    final int generation = ++_synchronizationGeneration;
    scheduleMicrotask(() {
      if (!mounted || generation != _synchronizationGeneration) return;
      unawaited(
        ref
            .read(profilePreferencesProvider.notifier)
            .synchronize(profilePreferencesScopeKeyForAuthState(authState)),
      );
    });
  }
}

String? profilePreferencesScopeKeyForAuthState(AuthLifecycleState authState) {
  final session = authState.session;
  final household = authState.activeHousehold;
  return session == null || household == null
      ? null
      : '${session.userId.value}|${household.householdId.value}';
}
