import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_port.dart';
import 'package:kinflow_app/features/billing/presentation/providers/billing_providers.dart';

class BillingLifecycleHost extends ConsumerStatefulWidget {
  const BillingLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<BillingLifecycleHost> createState() =>
      _BillingLifecycleHostState();
}

class _BillingLifecycleHostState extends ConsumerState<BillingLifecycleHost> {
  var _synchronizationGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSynchronize(ref.read(authLifecycleProvider));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(billingFlowProvider);
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
      _synchronize(authState);
    });
  }

  void _synchronize(AuthLifecycleState authState) {
    final BillingOperationContext? context = billingContextForAuthState(
      authState,
    );
    unawaited(
      ref
          .read(billingFlowProvider.notifier)
          .synchronize(
            userId: context?.userId,
            householdId: context?.householdId,
          ),
    );
  }
}

BillingOperationContext? billingContextForAuthState(
  AuthLifecycleState authState,
) {
  final session = authState.session;
  final activeHousehold = authState.activeHousehold;
  return session == null || activeHousehold == null
      ? null
      : BillingOperationContext(
          userId: session.userId,
          householdId: activeHousehold.householdId,
        );
}
