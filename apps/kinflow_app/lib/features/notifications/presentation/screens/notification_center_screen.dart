import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/providers/timezone_catalog_dependencies.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/presentation/widgets/timezone_picker_sheet.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/calendar/domain/value_objects/calendar_event_identifiers.dart';
import 'package:kinflow_app/features/chores/domain/value_objects/chore_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/notifications/application/notification_center_state.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_sync_signal.dart';
import 'package:kinflow_app/features/notifications/domain/failures/notification_failure.dart';
import 'package:kinflow_app/features/notifications/presentation/notification_failure_message.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/settings/domain/repositories/timezone_catalog_repository.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  HouseholdId? _requestedHouseholdId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load({bool force = false}) {
    final HouseholdId? householdId = ref
        .read(authLifecycleProvider)
        .activeHousehold
        ?.householdId;
    if (householdId == null) {
      context.go(AppRoutes.home);
      return;
    }
    if (!force && _requestedHouseholdId == householdId) {
      return;
    }
    _requestedHouseholdId = householdId;
    final NotificationCenterState state = ref.read(notificationCenterProvider);
    final bool preserve =
        force &&
        state is NotificationCenterReady &&
        state.snapshot.householdId == householdId;
    final notifier = ref.read(notificationCenterProvider.notifier);
    unawaited(
      force
          ? notifier.load(householdId, preserveContent: preserve)
          : notifier.ensureLoaded(householdId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final NotificationCenterState state = ref.watch(notificationCenterProvider);
    final NotificationPushState pushState = ref.watch(
      notificationPushStateProvider,
    );
    final bool busy = state is NotificationCenterReady && state.busy;
    return AppResponsiveScaffold(
      key: const Key('notification.screen'),
      title: localizations.notificationTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('notification.refresh'),
          onPressed: busy ? null : () => _load(force: true),
          tooltip: localizations.retryAction,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const Key('notification.today'),
          onPressed: () => context.go(AppRoutes.today),
          tooltip: localizations.notificationOpenTodayAction,
          icon: const Icon(Icons.today_outlined),
        ),
      ],
      body: _body(localizations, state, pushState),
    );
  }

  Widget _body(
    AppLocalizations localizations,
    NotificationCenterState state,
    NotificationPushState pushState,
  ) {
    return switch (state) {
      NotificationCenterInitial() ||
      NotificationCenterLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('notification.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.notificationLoadingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      NotificationCenterLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('notification.error'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.notifications_off_outlined,
              size: AppIconSize.status,
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                notificationFailureMessage(localizations, failure),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('notification.retry'),
              onPressed: () => _load(force: true),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      NotificationCenterReady() => _ready(localizations, state, pushState),
    };
  }

  Widget _ready(
    AppLocalizations localizations,
    NotificationCenterReady state,
    NotificationPushState pushState,
  ) {
    final NotificationSnapshot snapshot = state.snapshot;
    return RefreshIndicator(
      onRefresh: () => ref.read(notificationCenterProvider.notifier).refresh(),
      child: ListView(
        key: const Key('notification.list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayoutTokens.pageContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _inboxHeader(localizations, state),
                  if (state.syncStatus ==
                      NotificationSyncConnectionStatus
                          .disconnected) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _liveDisconnectedBanner(localizations),
                  ],
                  if (state.refreshing) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    const LinearProgressIndicator(),
                  ],
                  if (state.actionFailure != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    _failureBanner(localizations, state.actionFailure!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  if (snapshot.inbox.items.isEmpty)
                    _emptyInbox(localizations)
                  else
                    ...snapshot.inbox.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _inboxItem(localizations, state, item),
                      ),
                    ),
                  if (snapshot.inbox.hasMore) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      key: const Key('notification.loadMore'),
                      onPressed: state.busy
                          ? null
                          : () => unawaited(
                              ref
                                  .read(notificationCenterProvider.notifier)
                                  .loadMore(),
                            ),
                      icon: state.loadingMore
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more),
                      label: Text(localizations.notificationLoadMoreAction),
                    ),
                  ],
                  if (state.loadMoreFailure != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      localizations.notificationLoadMoreError,
                      key: const Key('notification.loadMoreError'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _pushPermissionCard(localizations, pushState),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      localizations.notificationSettingsHeading,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(localizations.notificationSettingsBody),
                  const SizedBox(height: AppSpacing.md),
                  ...snapshot.preferences.map(
                    (preference) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _preferenceCard(localizations, state, preference),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pushPermissionCard(
    AppLocalizations localizations,
    NotificationPushState state,
  ) {
    final String body = switch (state.permission) {
      NotificationPushPermission.unavailable =>
        localizations.notificationPushUnavailableBody,
      NotificationPushPermission.authorized when state.endpointRegistered =>
        localizations.notificationPushAuthorizedBody,
      NotificationPushPermission.authorized =>
        localizations.notificationPushSetupError,
      NotificationPushPermission.denied when state.permissionRequestAttempted =>
        localizations.notificationPushDeniedBody,
      NotificationPushPermission.denied ||
      NotificationPushPermission.notDetermined =>
        localizations.notificationPushPrePromptBody,
    };
    final bool canRequest =
        state.permission == NotificationPushPermission.notDetermined ||
        state.permission == NotificationPushPermission.denied &&
            !state.permissionRequestAttempted;
    final bool canOpenSettings =
        state.permission == NotificationPushPermission.denied &&
        state.permissionRequestAttempted;
    return Card(
      key: const Key('notification.pushPermission'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                state.permission == NotificationPushPermission.authorized &&
                        state.endpointRegistered
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_outlined,
              ),
              title: Text(localizations.notificationPushPermissionHeading),
              subtitle: Text(body),
              trailing: state.busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
            ),
            if (state.failure != null &&
                state.permission !=
                    NotificationPushPermission.unavailable) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  localizations.notificationPushSetupError,
                  key: const Key('notification.pushError'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            if (canRequest) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const Key('notification.pushEnable'),
                onPressed: state.busy
                    ? null
                    : () => unawaited(
                        ref
                            .read(notificationPushStateProvider.notifier)
                            .requestPermission(),
                      ),
                icon: const Icon(Icons.notifications_active_outlined),
                label: Text(localizations.notificationPushEnableAction),
              ),
            ] else if (canOpenSettings) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('notification.pushSettings'),
                onPressed: state.busy
                    ? null
                    : () => unawaited(
                        ref
                            .read(notificationPushStateProvider.notifier)
                            .openSystemSettings(),
                      ),
                icon: const Icon(Icons.settings_outlined),
                label: Text(localizations.notificationPushOpenSettingsAction),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _inboxHeader(
    AppLocalizations localizations,
    NotificationCenterReady state,
  ) {
    final int unreadCount = state.snapshot.unreadCount;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            localizations.notificationInboxHeading,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            Semantics(
              label: localizations.notificationBadgeSemantics(unreadCount),
              child: Chip(
                key: const Key('notification.badge'),
                label: Text(localizations.notificationUnreadBadge(unreadCount)),
              ),
            ),
            TextButton(
              key: const Key('notification.markAllRead'),
              onPressed: unreadCount == 0 || state.busy
                  ? null
                  : () => unawaited(
                      ref
                          .read(notificationCenterProvider.notifier)
                          .markAllRead(),
                    ),
              child: Text(localizations.notificationMarkAllReadAction),
            ),
          ],
        ),
      ],
    );
  }

  Widget _liveDisconnectedBanner(AppLocalizations localizations) {
    final Color foreground = Theme.of(context).colorScheme.onTertiaryContainer;
    return Container(
      key: const Key('notification.live.disconnected'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: AppRadii.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.cloud_off_outlined, color: foreground),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    localizations.notificationLiveDisconnectedMessage,
                    style: TextStyle(color: foreground),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            key: const Key('notification.live.reconnect'),
            onPressed: () => unawaited(
              ref.read(notificationCenterProvider.notifier).reconnect(),
            ),
            icon: const Icon(Icons.sync),
            label: Text(localizations.notificationReconnectAction),
          ),
        ],
      ),
    );
  }

  Widget _emptyInbox(AppLocalizations localizations) {
    return Card(
      key: const Key('notification.empty'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          children: <Widget>[
            const Icon(Icons.notifications_none, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.notificationEmptyTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.notificationEmptyBody,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _inboxItem(
    AppLocalizations localizations,
    NotificationCenterReady state,
    NotificationInboxItem item,
  ) {
    final DateTime localCreatedAt = item.createdAt.toLocal();
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String schedule = localizations.notificationCreatedSchedule(
      material.formatMediumDate(localCreatedAt),
      material.formatTimeOfDay(TimeOfDay.fromDateTime(localCreatedAt)),
    );
    final List<String> details = <String>[
      localizations.notificationItemBody,
      schedule,
      if (item.snoozeCount > 0)
        localizations.notificationSnoozeCount(item.snoozeCount),
    ];
    return Card(
      key: Key('notification.item.${item.id.value}'),
      child: Column(
        children: <Widget>[
          ListTile(
            enabled: !state.actionPending,
            onTap: () => _openItem(item),
            leading: Icon(
              item.isRead
                  ? Icons.notifications_none
                  : Icons.notifications_active,
              color: item.isRead ? null : Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              _categoryLabel(localizations, item.category),
              style: item.isRead
                  ? null
                  : const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(details.join('\n')),
            trailing: const Icon(Icons.chevron_right),
            isThreeLine: true,
          ),
          if (item.canSnooze) ...<Widget>[
            const Divider(height: 1),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: TextButton.icon(
                  key: Key('notification.snooze.${item.id.value}'),
                  onPressed: state.actionPending
                      ? null
                      : () => unawaited(_snoozeItem(localizations, item)),
                  icon: const Icon(Icons.snooze),
                  label: Text(localizations.notificationSnoozeAction),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _snoozeItem(
    AppLocalizations localizations,
    NotificationInboxItem item,
  ) async {
    final int? minutes = await showAppModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: ListView(
          key: const Key('notification.snooze.sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: <Widget>[
            Text(
              localizations.notificationSnoozeSheetTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.notificationSnoozeSheetBody),
            const SizedBox(height: AppSpacing.md),
            ...item.availableSnoozeMinutes.map(
              (minutes) => ListTile(
                key: Key('notification.snooze.option.$minutes'),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_outlined),
                title: Text(
                  localizations.notificationSnoozeMinutesAction(minutes),
                ),
                onTap: () => Navigator.of(context).pop(minutes),
              ),
            ),
          ],
        ),
      ),
    );
    if (minutes == null || !mounted) {
      return;
    }
    final bool succeeded = await ref
        .read(notificationCenterProvider.notifier)
        .snoozeCalendar(item.id, minutes);
    if (!succeeded || !mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        key: const Key('notification.snooze.succeeded'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          child: SingleChildScrollView(
            child: Text(localizations.notificationSnoozeSucceeded(minutes)),
          ),
        ),
      ),
    );
  }

  Widget _preferenceCard(
    AppLocalizations localizations,
    NotificationCenterReady state,
    NotificationPreference preference,
  ) {
    final String category = _categoryLabel(localizations, preference.category);
    final String quietSummary = preference.quietHoursEnabled
        ? localizations.notificationQuietHoursSummary(
            preference.quietStart!,
            preference.quietEnd!,
            preference.timezone,
          )
        : localizations.notificationQuietHoursOff(preference.timezone);
    final List<String> summaries = <String>[
      '${localizations.notificationQuietHoursLabel}: $quietSummary',
      if (preference.category == NotificationCategory.calendarEvent)
        '${localizations.notificationReminderLeadLabel}: '
            '${preference.reminderLeadMinuteSet.map((minutes) => _reminderLeadLabel(localizations, minutes)).join(', ')}',
    ];
    return Card(
      key: Key('notification.preference.${preference.category.wireValue}'),
      child: Column(
        children: <Widget>[
          ListTile(
            title: Text(category),
            subtitle: Text(summaries.join('\n')),
            trailing: TextButton(
              key: Key(
                'notification.preference.${preference.category.wireValue}.edit',
              ),
              onPressed: state.busy
                  ? null
                  : () => _editPreference(localizations, preference),
              child: Text(localizations.notificationEditAction),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editPreference(
    AppLocalizations localizations,
    NotificationPreference preference,
  ) async {
    final NotificationPreference? changed =
        await showAppDialog<NotificationPreference>(
          context: context,
          builder: (BuildContext context) => _NotificationPreferenceDialog(
            preference: preference,
            categoryLabel: _categoryLabel(localizations, preference.category),
            timezoneCatalogRepository: ref.read(
              timezoneCatalogRepositoryProvider,
            ),
          ),
        );
    if (changed != null && mounted) {
      await ref
          .read(notificationCenterProvider.notifier)
          .updatePreference(changed);
    }
  }

  Future<void> _openItem(NotificationInboxItem item) async {
    if (!item.isRead) {
      await ref.read(notificationCenterProvider.notifier).markRead(item.id);
    }
    if (mounted) {
      final String? location = switch (item.category) {
        NotificationCategory.choreDue || NotificationCategory.choreAssignment =>
          switch (ChoreOccurrenceId.tryParse(item.subjectId)) {
            final ChoreOccurrenceId id => AppRoutes.choreOccurrenceLocation(id),
            null => null,
          },
        NotificationCategory.calendarEvent =>
          switch (CalendarEventOccurrenceId.tryParse(item.subjectId)) {
            final CalendarEventOccurrenceId id =>
              AppRoutes.calendarEventLocation(id),
            null => null,
          },
      };
      context.go(location ?? AppRoutes.notifications);
    }
  }

  Widget _failureBanner(
    AppLocalizations localizations,
    NotificationFailure failure,
  ) {
    return MaterialBanner(
      key: const Key('notification.actionError'),
      content: Text(notificationFailureMessage(localizations, failure)),
      actions: <Widget>[
        TextButton(
          onPressed: () => _load(force: true),
          child: Text(localizations.retryAction),
        ),
      ],
    );
  }

  String _categoryLabel(
    AppLocalizations localizations,
    NotificationCategory category,
  ) {
    return switch (category) {
      NotificationCategory.choreDue => localizations.notificationChoreDueLabel,
      NotificationCategory.choreAssignment =>
        localizations.notificationChoreAssignmentLabel,
      NotificationCategory.calendarEvent =>
        localizations.notificationCalendarEventLabel,
    };
  }
}

final class _NotificationPreferenceDialog extends StatefulWidget {
  const _NotificationPreferenceDialog({
    required this.preference,
    required this.categoryLabel,
    required this.timezoneCatalogRepository,
  });

  final NotificationPreference preference;
  final String categoryLabel;
  final TimezoneCatalogRepository timezoneCatalogRepository;

  @override
  State<_NotificationPreferenceDialog> createState() =>
      _NotificationPreferenceDialogState();
}

final class _NotificationPreferenceDialogState
    extends State<_NotificationPreferenceDialog> {
  late bool _email;
  late bool _inApp;
  late bool _nativePush;
  late int _reminderLeadMinutes;
  late final Set<int> _additionalReminderLeadMinutes;
  late bool _quietEnabled;
  late TimeOfDay _quietStart;
  late TimeOfDay _quietEnd;
  late final TextEditingController _timezoneController;
  var _showValidation = false;

  @override
  void initState() {
    super.initState();
    final NotificationPreference preference = widget.preference;
    _email = preference.email;
    _inApp = preference.inApp;
    _nativePush = preference.nativePush;
    _reminderLeadMinutes = preference.reminderLeadMinutes;
    _additionalReminderLeadMinutes = <int>{
      ...preference.additionalReminderLeadMinutes,
    };
    _quietEnabled = preference.quietHoursEnabled;
    _quietStart =
        _parseTime(preference.quietStart) ??
        const TimeOfDay(hour: 22, minute: 0);
    _quietEnd =
        _parseTime(preference.quietEnd) ?? const TimeOfDay(hour: 7, minute: 0);
    _timezoneController = TextEditingController(text: preference.timezone);
  }

  @override
  void dispose() {
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    return AlertDialog(
      key: const Key('notification.preferenceEditor'),
      scrollable: true,
      title: Text(localizations.notificationEditorTitle(widget.categoryLabel)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SwitchListTile(
            key: const Key('notification.editor.inApp'),
            contentPadding: EdgeInsets.zero,
            title: Text(localizations.notificationInAppLabel),
            value: _inApp,
            onChanged: (value) => setState(() => _inApp = value),
          ),
          SwitchListTile(
            key: const Key('notification.editor.push'),
            contentPadding: EdgeInsets.zero,
            title: Text(localizations.notificationNativePushLabel),
            value: _nativePush,
            onChanged: (value) => setState(() => _nativePush = value),
          ),
          SwitchListTile(
            key: const Key('notification.editor.email'),
            contentPadding: EdgeInsets.zero,
            title: Text(localizations.notificationEmailLabel),
            subtitle: Text(localizations.notificationEmailBody),
            value: _email,
            onChanged: (value) => setState(() => _email = value),
          ),
          if (widget.preference.category ==
              NotificationCategory.calendarEvent) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<int>(
              key: const Key('notification.editor.reminderLead'),
              initialValue: _reminderLeadMinutes,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: localizations.notificationReminderLeadLabel,
                helperText: localizations.notificationReminderLeadBody,
                helperMaxLines: 3,
              ),
              items: NotificationPreference.calendarReminderLeadMinuteOptions
                  .map(
                    (int minutes) => DropdownMenuItem<int>(
                      key: Key(
                        'notification.editor.reminderLead.option.$minutes',
                      ),
                      value: minutes,
                      child: Text(
                        _reminderLeadLabel(localizations, minutes),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (int? value) {
                if (value != null) {
                  setState(() {
                    _reminderLeadMinutes = value;
                    _additionalReminderLeadMinutes.remove(value);
                  });
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                localizations.notificationAdditionalRemindersLabel,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                localizations.notificationAdditionalRemindersBody,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ...NotificationPreference.calendarReminderLeadMinuteOptions
                .where((minutes) => minutes != _reminderLeadMinutes)
                .map((int minutes) {
                  final bool selected = _additionalReminderLeadMinutes.contains(
                    minutes,
                  );
                  final bool canSelect =
                      selected || _additionalReminderLeadMinutes.length < 2;
                  return CheckboxListTile(
                    key: Key('notification.editor.additionalReminder.$minutes'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(_reminderLeadLabel(localizations, minutes)),
                    value: selected,
                    onChanged: canSelect
                        ? (bool? value) {
                            setState(() {
                              if (value ?? false) {
                                _additionalReminderLeadMinutes.add(minutes);
                              } else {
                                _additionalReminderLeadMinutes.remove(minutes);
                              }
                            });
                          }
                        : null,
                  );
                }),
          ],
          SwitchListTile(
            key: const Key('notification.editor.quietEnabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(localizations.notificationQuietEnabledLabel),
            value: _quietEnabled,
            onChanged: (value) => setState(() => _quietEnabled = value),
          ),
          if (_quietEnabled) ...<Widget>[
            ListTile(
              key: const Key('notification.editor.quietStart'),
              contentPadding: EdgeInsets.zero,
              title: Text(localizations.notificationQuietStartLabel),
              trailing: Text(material.formatTimeOfDay(_quietStart)),
              onTap: () => _pickTime(start: true),
            ),
            ListTile(
              key: const Key('notification.editor.quietEnd'),
              contentPadding: EdgeInsets.zero,
              title: Text(localizations.notificationQuietEndLabel),
              trailing: Text(material.formatTimeOfDay(_quietEnd)),
              onTap: () => _pickTime(start: false),
            ),
          ],
          TimezoneSelectionFormField(
            fieldKey: const Key('notification.editor.timezone'),
            controller: _timezoneController,
            repository: widget.timezoneCatalogRepository,
            pickerTitle: localizations.notificationTimezonePickerTitle,
            labelText: localizations.notificationTimezoneLabel,
            hintText: localizations.notificationTimezoneHint,
            errorText: _showValidation
                ? localizations.notificationTimezoneValidation
                : null,
            onSelected: (_) {
              if (_showValidation) setState(() => _showValidation = false);
            },
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          key: const Key('notification.editor.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.notificationCancelAction),
        ),
        FilledButton(
          key: const Key('notification.editor.save'),
          onPressed: _save,
          child: Text(localizations.notificationSaveAction),
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool start}) async {
    final TimeOfDay? selected = await showTimePicker(
      context: context,
      initialTime: start ? _quietStart : _quietEnd,
    );
    if (selected != null && mounted) {
      setState(() {
        if (start) {
          _quietStart = selected;
        } else {
          _quietEnd = selected;
        }
      });
    }
  }

  void _save() {
    final NotificationPreference? changed = widget.preference.changed(
      email: _email,
      inApp: _inApp,
      nativePush: _nativePush,
      quietHoursEnabled: _quietEnabled,
      quietStart: _wireTime(_quietStart),
      quietEnd: _wireTime(_quietEnd),
      timezone: _timezoneController.text.trim(),
      reminderLeadMinutes: _reminderLeadMinutes,
      additionalReminderLeadMinutes: _additionalReminderLeadMinutes.toList(
        growable: false,
      )..sort(),
    );
    if (changed == null) {
      setState(() => _showValidation = true);
      return;
    }
    Navigator.of(context).pop(changed);
  }

  static TimeOfDay? _parseTime(String? value) {
    if (value == null) {
      return null;
    }
    final List<String> parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    return hour == null || minute == null || hour > 23 || minute > 59
        ? null
        : TimeOfDay(hour: hour, minute: minute);
  }

  static String _wireTime(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}

String _reminderLeadLabel(
  AppLocalizations localizations,
  int reminderLeadMinutes,
) {
  return reminderLeadMinutes == 0
      ? localizations.notificationReminderLeadAtStart
      : localizations.notificationReminderLeadMinutesBefore(
          reminderLeadMinutes,
        );
}
