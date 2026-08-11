import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/value_objects/auth_user_id.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_state.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/notifications/presentation/widgets/notification_app_shell_action.dart';

/// Keeps one authoritative Notification Center alive for the authenticated app
/// shell, independent of whichever primary route is currently visible.
class NotificationCenterLifecycleHost extends ConsumerStatefulWidget {
  const NotificationCenterLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationCenterLifecycleHost> createState() =>
      _NotificationCenterLifecycleHostState();
}

class _NotificationCenterLifecycleHostState
    extends ConsumerState<NotificationCenterLifecycleHost>
    with WidgetsBindingObserver {
  NotificationCenterLifecycleContext? _context;
  var _hasSynchronized = false;
  var _synchronizationGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSynchronize(ref.read(authLifecycleProvider));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    final int generation = _synchronizationGeneration;
    scheduleMicrotask(() {
      if (!mounted || generation != _synchronizationGeneration) {
        return;
      }
      unawaited(_resume(generation));
    });
  }

  @override
  Widget build(BuildContext context) {
    final NotificationCenterState state = ref.watch(notificationCenterProvider);
    ref.listen<AuthLifecycleState>(authLifecycleProvider, (
      AuthLifecycleState? previous,
      AuthLifecycleState next,
    ) {
      _scheduleSynchronize(next);
    });
    return NotificationAppShellBadgeScope(
      unreadCount: state is NotificationCenterReady
          ? state.snapshot.unreadCount
          : 0,
      child: widget.child,
    );
  }

  void _scheduleSynchronize(AuthLifecycleState authState) {
    final NotificationCenterLifecycleContext? nextContext =
        notificationCenterLifecycleContextFor(authState);
    final int generation = ++_synchronizationGeneration;
    scheduleMicrotask(() {
      if (!mounted || generation != _synchronizationGeneration) {
        return;
      }
      unawaited(_synchronize(nextContext, generation));
    });
  }

  Future<void> _synchronize(
    NotificationCenterLifecycleContext? nextContext,
    int generation,
  ) async {
    if (!_hasSynchronized) {
      _hasSynchronized = true;
      _context = nextContext;
      if (nextContext == null) {
        await ref.read(notificationCenterProvider.notifier).deactivate();
      } else {
        await ref
            .read(notificationCenterProvider.notifier)
            .ensureLoaded(nextContext.householdId);
      }
      return;
    }

    if (_context == nextContext) {
      if (nextContext != null) {
        await ref
            .read(notificationCenterProvider.notifier)
            .ensureLoaded(nextContext.householdId);
      }
      return;
    }

    _context = nextContext;
    await ref.read(notificationCenterProvider.notifier).deactivate();
    if (!mounted ||
        generation != _synchronizationGeneration ||
        _context != nextContext ||
        nextContext == null) {
      return;
    }
    await ref
        .read(notificationCenterProvider.notifier)
        .ensureLoaded(nextContext.householdId);
  }

  Future<void> _resume(int generation) async {
    final NotificationCenterLifecycleContext? currentContext = _context;
    if (!_hasSynchronized || currentContext == null) {
      return;
    }
    final notifier = ref.read(notificationCenterProvider.notifier);
    await notifier.ensureLoaded(currentContext.householdId);
    if (!mounted ||
        generation != _synchronizationGeneration ||
        _context != currentContext) {
      return;
    }
    final NotificationCenterState state = ref.read(notificationCenterProvider);
    if (state case NotificationCenterReady(
      :final snapshot,
    ) when snapshot.householdId == currentContext.householdId) {
      await ref.read(notificationCenterProvider.notifier).resume();
    } else if (state is NotificationCenterLoadFailed) {
      await ref
          .read(notificationCenterProvider.notifier)
          .load(currentContext.householdId);
    }
  }

  @override
  void dispose() {
    _synchronizationGeneration += 1;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final class NotificationCenterLifecycleContext {
  const NotificationCenterLifecycleContext({
    required this.userId,
    required this.householdId,
  });

  final AuthUserId userId;
  final HouseholdId householdId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is NotificationCenterLifecycleContext &&
            other.userId == userId &&
            other.householdId == householdId;
  }

  @override
  int get hashCode => Object.hash(userId, householdId);
}

NotificationCenterLifecycleContext? notificationCenterLifecycleContextFor(
  AuthLifecycleState authState,
) {
  final session = authState.session;
  final activeHousehold = authState.activeHousehold;
  return session == null || activeHousehold == null
      ? null
      : NotificationCenterLifecycleContext(
          userId: session.userId,
          householdId: activeHousehold.householdId,
        );
}
