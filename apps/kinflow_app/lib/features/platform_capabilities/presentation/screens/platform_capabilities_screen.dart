import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/notifications/domain/entities/notification_push_models.dart';
import 'package:kinflow_app/features/notifications/presentation/providers/notification_providers.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_recovery_plan.dart';
import 'package:kinflow_app/features/platform_capabilities/domain/entities/platform_capability_registry.dart';
import 'package:kinflow_app/features/platform_capabilities/presentation/providers/platform_capability_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class PlatformCapabilitiesScreen extends ConsumerStatefulWidget {
  const PlatformCapabilitiesScreen({super.key});

  @override
  ConsumerState<PlatformCapabilitiesScreen> createState() =>
      _PlatformCapabilitiesScreenState();
}

class _PlatformCapabilitiesScreenState
    extends ConsumerState<PlatformCapabilitiesScreen> {
  bool _selfCheckBusy = false;
  _PlatformCapabilitySelfCheckResult? _selfCheckResult;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final PlatformCapabilitySnapshot snapshot = ref.watch(
      platformCapabilitySnapshotProvider,
    );
    final PlatformCapabilityRecoveryPlan recoveryPlan = ref.watch(
      platformCapabilityRecoveryPlanProvider,
    );
    return AppResponsiveScaffold(
      key: const Key('platformCapabilities.screen'),
      title: localizations.platformCapabilitiesTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('platformCapabilities.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        key: const Key('platformCapabilities.list'),
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
                  _introCard(context, localizations),
                  const SizedBox(height: AppSpacing.md),
                  _selfCheckCard(context, localizations, recoveryPlan),
                  const SizedBox(height: AppSpacing.md),
                  for (final PlatformCapabilityStatus entry
                      in snapshot.entries) ...<Widget>[
                    _capabilityCard(context, localizations, entry),
                    if (entry != snapshot.entries.last)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selfCheckCard(
    BuildContext context,
    AppLocalizations localizations,
    PlatformCapabilityRecoveryPlan plan,
  ) {
    return Card(
      key: const Key('platformCapabilities.selfCheck'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.platformCapabilitiesSelfCheckTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.platformCapabilitiesSelfCheckBody),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                _summaryBadge(
                  context,
                  key: const Key('platformCapabilities.summary.ready'),
                  icon: Icons.check_circle_outline,
                  label: localizations.platformCapabilitiesReadyCount(
                    plan.readyCount,
                  ),
                ),
                _summaryBadge(
                  context,
                  key: const Key('platformCapabilities.summary.attention'),
                  icon: Icons.warning_amber_outlined,
                  label: localizations.platformCapabilitiesAttentionCount(
                    plan.attentionCount,
                  ),
                ),
                _summaryBadge(
                  context,
                  key: const Key('platformCapabilities.summary.alternative'),
                  icon: Icons.alt_route,
                  label: localizations.platformCapabilitiesAlternativeCount(
                    plan.alternativeCount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              localizations.platformCapabilitiesRecoveryHeading,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (plan.steps.isEmpty)
              Text(
                localizations.platformCapabilitiesRecoveryEmpty,
                key: const Key('platformCapabilities.recovery.empty'),
              )
            else
              for (final PlatformCapabilityRecoveryStep step
                  in plan.steps) ...<Widget>[
                _recoveryStep(context, localizations, step),
                if (step != plan.steps.last)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Divider(height: 1),
                  ),
              ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('platformCapabilities.selfCheck.refresh'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: _selfCheckBusy ? null : _refreshCapabilityState,
              icon: _selfCheckBusy
                  ? const SizedBox.square(
                      dimension: AppSpacing.md,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                _selfCheckBusy
                    ? localizations.platformCapabilitiesSelfCheckRefreshing
                    : localizations.platformCapabilitiesSelfCheckAction,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.platformCapabilitiesSelfCheckScope,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_selfCheckResult case final result?) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  result == _PlatformCapabilitySelfCheckResult.succeeded
                      ? localizations.platformCapabilitiesSelfCheckSucceeded
                      : localizations.platformCapabilitiesSelfCheckFailed,
                  key: const Key('platformCapabilities.selfCheck.result'),
                  style: result == _PlatformCapabilitySelfCheckResult.failed
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryBadge(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[Icon(icon, size: 18), Text(label)],
      ),
    );
  }

  Widget _recoveryStep(
    BuildContext context,
    AppLocalizations localizations,
    PlatformCapabilityRecoveryStep step,
  ) {
    final PlatformCapabilityStatus status = step.status;
    final String title = _title(localizations, status.id);
    final String state = _stateLabel(localizations, status.state);
    final String fallback = _fallbackLabel(localizations, status.fallback);
    return Semantics(
      container: true,
      label:
          '${localizations.platformCapabilitiesRecoveryStep(step.position)}. '
          '$title. $state. '
          '${localizations.platformCapabilitiesFallbackLabel}: $fallback.',
      child: Column(
        key: Key('platformCapabilities.recovery.${status.id.wireValue}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Icon(_capabilityIcon(status.id)),
              Text(
                localizations.platformCapabilitiesRecoveryStep(step.position),
                style: Theme.of(context).textTheme.labelLarge,
              ),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('$state · $fallback'),
          if (status.action != PlatformCapabilityAction.none) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                key: Key(
                  'platformCapabilities.recoveryAction.${status.id.wireValue}',
                ),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => _openAction(context, status.action),
                icon: const Icon(Icons.arrow_forward),
                label: Text(_actionLabel(localizations, status.action)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _refreshCapabilityState() async {
    if (_selfCheckBusy) return;
    setState(() {
      _selfCheckBusy = true;
      _selfCheckResult = null;
    });
    _PlatformCapabilitySelfCheckResult result;
    try {
      await ref
          .read(notificationPushStateProvider.notifier)
          .refreshPermission();
      final NotificationPushState state = ref.read(
        notificationPushStateProvider,
      );
      result = state.failure == null
          ? _PlatformCapabilitySelfCheckResult.succeeded
          : _PlatformCapabilitySelfCheckResult.failed;
    } on Object {
      result = _PlatformCapabilitySelfCheckResult.failed;
    }
    if (!mounted) return;
    setState(() {
      _selfCheckBusy = false;
      _selfCheckResult = result;
    });
  }

  Widget _introCard(BuildContext context, AppLocalizations localizations) {
    return Card(
      key: const Key('platformCapabilities.intro'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.platformCapabilitiesIntroTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.platformCapabilitiesIntroBody),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.platformCapabilitiesPrivacyNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _capabilityCard(
    BuildContext context,
    AppLocalizations localizations,
    PlatformCapabilityStatus entry,
  ) {
    final String title = _title(localizations, entry.id);
    final String state = _stateLabel(localizations, entry.state);
    final String provider = _providerLabel(localizations, entry.provider);
    final String reason = _reason(localizations, entry);
    final String fallback = _fallbackLabel(localizations, entry.fallback);
    return Semantics(
      container: true,
      label:
          '$title. $state. $reason. '
          '${localizations.platformCapabilitiesProviderLabel}: $provider. '
          '${localizations.platformCapabilitiesFallbackLabel}: $fallback.',
      child: Card(
        key: Key('platformCapabilities.${entry.id.wireValue}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Icon(_capabilityIcon(entry.id)),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  _statusBadge(context, state, entry.state),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(reason),
              const SizedBox(height: AppSpacing.md),
              _detail(
                context,
                label: localizations.platformCapabilitiesProviderLabel,
                value: provider,
              ),
              const SizedBox(height: AppSpacing.sm),
              _detail(
                context,
                label: localizations.platformCapabilitiesFallbackLabel,
                value: fallback,
              ),
              if (entry.action != PlatformCapabilityAction.none) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    key: Key(
                      'platformCapabilities.action.${entry.id.wireValue}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _openAction(context, entry.action),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text(_actionLabel(localizations, entry.action)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(
    BuildContext context,
    String label,
    PlatformCapabilitySupportState state,
  ) {
    final Color color = switch (state) {
      PlatformCapabilitySupportState.available => Theme.of(
        context,
      ).colorScheme.primary,
      PlatformCapabilitySupportState.actionRequired => Theme.of(
        context,
      ).colorScheme.tertiary,
      PlatformCapabilitySupportState.limited ||
      PlatformCapabilitySupportState.fallbackOnly => Theme.of(
        context,
      ).colorScheme.secondary,
      PlatformCapabilitySupportState.temporaryIssue => Theme.of(
        context,
      ).colorScheme.error,
    };
    final IconData icon = switch (state) {
      PlatformCapabilitySupportState.available => Icons.check_circle_outline,
      PlatformCapabilitySupportState.actionRequired =>
        Icons.notifications_active_outlined,
      PlatformCapabilitySupportState.limited => Icons.info_outline,
      PlatformCapabilitySupportState.fallbackOnly => Icons.alt_route,
      PlatformCapabilitySupportState.temporaryIssue => Icons.sync_problem,
    };
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Icon(icon, size: 18, color: color),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _detail(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(value),
      ],
    );
  }

  void _openAction(BuildContext context, PlatformCapabilityAction action) {
    final String? route = switch (action) {
      PlatformCapabilityAction.none => null,
      PlatformCapabilityAction.openNotificationCenter =>
        AppRoutes.notifications,
      PlatformCapabilityAction.openSubscriptionSettings =>
        AppRoutes.subscription,
      PlatformCapabilityAction.openDiagnostics => AppRoutes.diagnostics,
    };
    if (route != null) context.go(route);
  }

  IconData _capabilityIcon(PlatformCapabilityId id) {
    return switch (id) {
      PlatformCapabilityId.notificationDelivery => Icons.notifications_outlined,
      PlatformCapabilityId.storeBilling => Icons.shopping_bag_outlined,
      PlatformCapabilityId.secureLocalStorage => Icons.lock_outline,
      PlatformCapabilityId.externalLinks => Icons.open_in_new,
      PlatformCapabilityId.backgroundDelivery => Icons.cloud_sync_outlined,
    };
  }

  String _title(AppLocalizations l10n, PlatformCapabilityId id) {
    return switch (id) {
      PlatformCapabilityId.notificationDelivery =>
        l10n.platformCapabilitiesNotificationTitle,
      PlatformCapabilityId.storeBilling =>
        l10n.platformCapabilitiesBillingTitle,
      PlatformCapabilityId.secureLocalStorage =>
        l10n.platformCapabilitiesSecureStorageTitle,
      PlatformCapabilityId.externalLinks =>
        l10n.platformCapabilitiesExternalLinksTitle,
      PlatformCapabilityId.backgroundDelivery =>
        l10n.platformCapabilitiesBackgroundTitle,
    };
  }

  String _stateLabel(
    AppLocalizations l10n,
    PlatformCapabilitySupportState state,
  ) {
    return switch (state) {
      PlatformCapabilitySupportState.available =>
        l10n.platformCapabilitiesStateAvailable,
      PlatformCapabilitySupportState.actionRequired =>
        l10n.platformCapabilitiesStateActionRequired,
      PlatformCapabilitySupportState.limited =>
        l10n.platformCapabilitiesStateLimited,
      PlatformCapabilitySupportState.fallbackOnly =>
        l10n.platformCapabilitiesStateFallbackOnly,
      PlatformCapabilitySupportState.temporaryIssue =>
        l10n.platformCapabilitiesStateTemporaryIssue,
    };
  }

  String _providerLabel(
    AppLocalizations l10n,
    PlatformCapabilityProvider provider,
  ) {
    return switch (provider) {
      PlatformCapabilityProvider.firebaseMessagingAndroid =>
        l10n.platformCapabilitiesProviderFirebaseMessaging,
      PlatformCapabilityProvider.revenueCatGooglePlay =>
        l10n.platformCapabilitiesProviderRevenueCatPlay,
      PlatformCapabilityProvider.androidKeystore =>
        l10n.platformCapabilitiesProviderAndroidKeystore,
      PlatformCapabilityProvider.androidSystemUriLauncher =>
        l10n.platformCapabilitiesProviderAndroidUriLauncher,
      PlatformCapabilityProvider.browserExternalUriLauncher =>
        l10n.platformCapabilitiesProviderBrowserUriLauncher,
      PlatformCapabilityProvider.firebaseBackgroundMessageHandler =>
        l10n.platformCapabilitiesProviderFirebaseBackground,
      PlatformCapabilityProvider.unavailable =>
        l10n.platformCapabilitiesProviderUnavailable,
    };
  }

  String _fallbackLabel(
    AppLocalizations l10n,
    PlatformCapabilityFallback fallback,
  ) {
    return switch (fallback) {
      PlatformCapabilityFallback.inAppInbox =>
        l10n.platformCapabilitiesFallbackInbox,
      PlatformCapabilityFallback.inAppInboxAndConfiguredEmail =>
        l10n.platformCapabilitiesFallbackInboxAndEmail,
      PlatformCapabilityFallback.serverEntitlementReadOnly =>
        l10n.platformCapabilitiesFallbackEntitlement,
      PlatformCapabilityFallback.reauthenticateWithoutPersistentCache =>
        l10n.platformCapabilitiesFallbackReauthentication,
      PlatformCapabilityFallback.onScreenGuidanceAndDiagnostics =>
        l10n.platformCapabilitiesFallbackGuidance,
      PlatformCapabilityFallback.serverNotificationPipelineAndInAppInbox =>
        l10n.platformCapabilitiesFallbackServerNotifications,
    };
  }

  String _reason(AppLocalizations l10n, PlatformCapabilityStatus entry) {
    return switch ((entry.id, entry.reason)) {
      (
        PlatformCapabilityId.notificationDelivery,
        PlatformCapabilityReason.providerReady,
      ) =>
        l10n.platformCapabilitiesNotificationAvailable,
      (
        PlatformCapabilityId.notificationDelivery,
        PlatformCapabilityReason.permissionNotDetermined,
      ) =>
        l10n.platformCapabilitiesNotificationNotDetermined,
      (
        PlatformCapabilityId.notificationDelivery,
        PlatformCapabilityReason.permissionDenied,
      ) =>
        l10n.platformCapabilitiesNotificationDenied,
      (
        PlatformCapabilityId.notificationDelivery,
        PlatformCapabilityReason.runtimeUnavailable,
      ) =>
        l10n.platformCapabilitiesNotificationRuntimeUnavailable,
      (
        PlatformCapabilityId.notificationDelivery,
        PlatformCapabilityReason.providerTemporarilyUnavailable,
      ) =>
        l10n.platformCapabilitiesNotificationTemporary,
      (
        PlatformCapabilityId.notificationDelivery,
        PlatformCapabilityReason.providerNotConfigured,
      ) =>
        l10n.platformCapabilitiesNotificationNotConfigured,
      (
        PlatformCapabilityId.storeBilling,
        PlatformCapabilityReason.providerReady,
      ) =>
        l10n.platformCapabilitiesBillingAvailable,
      (
        PlatformCapabilityId.storeBilling,
        PlatformCapabilityReason.providerNotConfigured,
      ) =>
        l10n.platformCapabilitiesBillingNotConfigured,
      (
        PlatformCapabilityId.secureLocalStorage,
        PlatformCapabilityReason.providerReady,
      ) =>
        l10n.platformCapabilitiesSecureStorageAvailable,
      (
        PlatformCapabilityId.secureLocalStorage,
        PlatformCapabilityReason.providerNotConfigured,
      ) =>
        l10n.platformCapabilitiesSecureStorageNotConfigured,
      (
        PlatformCapabilityId.externalLinks,
        PlatformCapabilityReason.providerReady,
      ) =>
        l10n.platformCapabilitiesExternalLinksAvailable,
      (
        PlatformCapabilityId.externalLinks,
        PlatformCapabilityReason.providerNotConfigured,
      ) =>
        l10n.platformCapabilitiesExternalLinksNotConfigured,
      (
        PlatformCapabilityId.backgroundDelivery,
        PlatformCapabilityReason.serverAuthoritative,
      ) =>
        l10n.platformCapabilitiesBackgroundLimited,
      (
        PlatformCapabilityId.backgroundDelivery,
        PlatformCapabilityReason.providerNotConfigured,
      ) =>
        l10n.platformCapabilitiesBackgroundNotConfigured,
      _ => l10n.platformCapabilitiesSafeUnknownState,
    };
  }

  String _actionLabel(AppLocalizations l10n, PlatformCapabilityAction action) {
    return switch (action) {
      PlatformCapabilityAction.none => '',
      PlatformCapabilityAction.openNotificationCenter =>
        l10n.platformCapabilitiesOpenNotificationsAction,
      PlatformCapabilityAction.openSubscriptionSettings =>
        l10n.platformCapabilitiesOpenSubscriptionAction,
      PlatformCapabilityAction.openDiagnostics =>
        l10n.platformCapabilitiesOpenDiagnosticsAction,
    };
  }
}

enum _PlatformCapabilitySelfCheckResult { succeeded, failed }
