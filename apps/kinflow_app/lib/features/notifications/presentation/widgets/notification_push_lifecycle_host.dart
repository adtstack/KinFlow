import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/notification_push_coordinator.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class NotificationPushLifecycleHost extends ConsumerStatefulWidget {
  const NotificationPushLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationPushLifecycleHost> createState() =>
      _NotificationPushLifecycleHostState();
}

class _NotificationPushLifecycleHostState
    extends ConsumerState<NotificationPushLifecycleHost>
    with WidgetsBindingObserver {
  late final StreamSubscription<NotificationPushNavigationIntent>
  _navigationSubscription;
  String? _localeTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final NotificationPushCoordinatorService coordinator = ref.read(
      notificationPushCoordinatorProvider,
    );
    _navigationSubscription = coordinator.navigationIntents.listen(_navigate);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppLocalizations localizations = AppLocalizations.of(context);
    _localeTag = Localizations.localeOf(context).toLanguageTag();
    final NotificationPushPresentationContent? content =
        NotificationPushPresentationContent.tryCreate(
          title: localizations.notificationPushPresentationTitle,
          body: localizations.notificationPushPresentationBody,
          channelName: localizations.notificationPushChannelName,
          channelDescription: localizations.notificationPushChannelDescription,
        );
    if (content != null) {
      ref
          .read(notificationPushStateProvider.notifier)
          .updatePresentationContent(content);
    }
    _synchronize(ref.read(authLifecycleProvider));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(
        ref.read(notificationPushStateProvider.notifier).refreshPermission(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(notificationPushStateProvider);
    ref.listen<AuthLifecycleState>(authLifecycleProvider, (
      AuthLifecycleState? previous,
      AuthLifecycleState next,
    ) {
      _synchronize(next);
    });
    return widget.child;
  }

  void _synchronize(AuthLifecycleState authState) {
    unawaited(
      ref
          .read(notificationPushStateProvider.notifier)
          .synchronize(
            activeHousehold: authState.activeHousehold,
            locale: _localeTag,
          ),
    );
  }

  void _navigate(NotificationPushNavigationIntent intent) {
    if (!mounted) return;
    final String? location = switch (intent.destination) {
      NotificationPushNavigationDestination.choreOccurrence =>
        switch (ChoreOccurrenceId.tryParse(intent.subjectId ?? '')) {
          final ChoreOccurrenceId id => AppRoutes.choreOccurrenceLocation(id),
          null => null,
        },
      NotificationPushNavigationDestination.calendarEvent =>
        switch (CalendarEventOccurrenceId.tryParse(intent.subjectId ?? '')) {
          final CalendarEventOccurrenceId id => AppRoutes.calendarEventLocation(
            id,
          ),
          null => null,
        },
      NotificationPushNavigationDestination.notificationCenter =>
        AppRoutes.notifications,
    };
    ref.read(appRouterProvider).go(location ?? AppRoutes.notifications);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_navigationSubscription.cancel());
    super.dispose();
  }
}
