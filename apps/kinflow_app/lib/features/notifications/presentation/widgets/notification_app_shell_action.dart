import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

/// Shared app-shell entry point backed by the root Notification Center state.
class NotificationAppShellAction extends StatelessWidget {
  const NotificationAppShellAction({
    this.buttonKey = const Key('appShell.notifications'),
    super.key,
  });

  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final int unreadCount = NotificationAppShellBadgeScope.unreadCountOf(
      context,
    );
    return Tooltip(
      message: localizations.notificationOpenAction,
      excludeFromSemantics: true,
      child: Semantics(
        label: localizations.notificationBadgeSemantics(unreadCount),
        button: true,
        child: IconButton(
          key: buttonKey,
          onPressed: () =>
              unawaited(context.push<void>(AppRoutes.notifications)),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ),
    );
  }
}

/// Read-only app-shell projection of the authoritative Notification Center
/// unread count. Isolated screens without the root host safely see zero.
class NotificationAppShellBadgeScope extends InheritedWidget {
  const NotificationAppShellBadgeScope({
    required this.unreadCount,
    required super.child,
    super.key,
  });

  final int unreadCount;

  static int unreadCountOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              NotificationAppShellBadgeScope
            >()
            ?.unreadCount ??
        0;
  }

  @override
  bool updateShouldNotify(NotificationAppShellBadgeScope oldWidget) {
    return unreadCount != oldWidget.unreadCount;
  }
}
