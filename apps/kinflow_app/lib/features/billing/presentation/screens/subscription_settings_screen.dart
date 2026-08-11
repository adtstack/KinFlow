import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/billing/application/billing_flow_state.dart';
import 'package:kinflow_app/features/billing/application/ports/billing_external_link_launcher.dart';
import 'package:kinflow_app/features/billing/domain/entities/billing_store_models.dart';
import 'package:kinflow_app/features/billing/domain/entities/household_entitlement.dart';
import 'package:kinflow_app/features/billing/domain/failures/billing_failure.dart';
import 'package:kinflow_app/features/billing/presentation/providers/billing_providers.dart';
import 'package:kinflow_app/features/settings/application/profile_preferences_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/profile_preferences.dart';
import 'package:kinflow_app/features/settings/presentation/providers/profile_preferences_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class SubscriptionSettingsScreen extends ConsumerStatefulWidget {
  const SubscriptionSettingsScreen({super.key});

  @override
  ConsumerState<SubscriptionSettingsScreen> createState() =>
      _SubscriptionSettingsScreenState();
}

class _SubscriptionSettingsScreenState
    extends ConsumerState<SubscriptionSettingsScreen> {
  var _externalBusy = false;
  var _externalFailure = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final BillingFlowState billingState = ref.watch(billingFlowProvider);
    final ProfilePreferencesState profileState = ref.watch(
      profilePreferencesProvider,
    );
    return AppResponsiveScaffold(
      key: const Key('subscription.screen'),
      title: localizations.subscriptionTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('subscription.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: _body(localizations, billingState, profileState),
    );
  }

  Widget _body(
    AppLocalizations localizations,
    BillingFlowState billingState,
    ProfilePreferencesState profileState,
  ) {
    final BillingFlowSnapshot? snapshot = billingState.snapshot;
    if (snapshot == null) {
      return switch (billingState) {
        BillingFlowFailed(:final failure) => ScrollableStatusLayout(
          child: _failurePanel(
            localizations,
            failure,
            canRefresh: false,
            canReturn: false,
          ),
        ),
        _ => ScrollableStatusLayout(
          child: Column(
            key: const Key('subscription.loading'),
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                localizations.subscriptionLoading,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      };
    }

    final _HouseholdBillingContext household = _householdContext(
      localizations,
      snapshot,
      profileState,
    );
    return ListView(
      key: const Key('subscription.content'),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutTokens.statusContentMaxWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _statusCard(localizations, snapshot, household),
                const SizedBox(height: AppSpacing.md),
                _stateSection(localizations, billingState, snapshot, household),
                if (_externalFailure) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _messageCard(
                    key: const Key('subscription.externalFailure'),
                    icon: Icons.open_in_new_off,
                    message: localizations.subscriptionExternalUnavailable,
                    liveRegion: true,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _policyLinks(localizations),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusCard(
    AppLocalizations localizations,
    BillingFlowSnapshot snapshot,
    _HouseholdBillingContext household,
  ) {
    final HouseholdEntitlement entitlement = snapshot.entitlement;
    return Card(
      key: const Key('subscription.statusCard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.subscriptionStatusHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _statusRow(
              localizations.subscriptionHouseholdLabel,
              household.name,
            ),
            _statusRow(
              localizations.subscriptionPlanLabel,
              entitlement.hasPlus
                  ? localizations.subscriptionPlanPlus
                  : localizations.subscriptionPlanFree,
            ),
            _statusRow(
              localizations.subscriptionLifecycleLabel,
              _statusLabel(localizations, entitlement.status),
            ),
            _statusRow(
              localizations.subscriptionSourceLabel,
              _sourceLabel(localizations, entitlement.source),
            ),
            _statusRow(
              localizations.subscriptionBillingOwnerLabel,
              _billingOwnerLabel(localizations, entitlement),
            ),
            _statusRow(
              localizations.subscriptionPeriodLabel,
              _periodEndLabel(localizations, entitlement),
            ),
            _statusRow(
              localizations.subscriptionVerifiedLabel,
              localizations.subscriptionVerifiedAt(
                _formatDate(entitlement.verifiedAt),
              ),
              showDivider: false,
            ),
            if (_lifecycleMessage(localizations, entitlement)
                case final message?)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _messageCard(
                  key: const Key('subscription.lifecycleNotice'),
                  icon: entitlement.requiresBillingAttention
                      ? Icons.warning_amber_outlined
                      : Icons.info_outline,
                  message: message,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value, {bool showDivider = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xxs),
        Text(value),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Divider(height: 1),
          ),
      ],
    );
  }

  Widget _stateSection(
    AppLocalizations localizations,
    BillingFlowState state,
    BillingFlowSnapshot snapshot,
    _HouseholdBillingContext household,
  ) {
    return switch (state) {
      BillingFlowReady() => _readySection(
        localizations,
        state,
        snapshot,
        household,
      ),
      BillingAssignmentPreparingState(:final operation) => _busyPanel(
        operation == BillingOperationKind.purchase
            ? localizations.subscriptionPreparingPurchase
            : localizations.subscriptionPreparingRestore,
      ),
      BillingFlowPurchasing() => _busyPanel(
        localizations.subscriptionPurchasing,
      ),
      BillingFlowRestoring() => _busyPanel(localizations.subscriptionRestoring),
      BillingStorePendingState() => _pendingPanel(
        localizations,
        localizations.subscriptionStorePending,
      ),
      BillingServerConfirmationPendingState() => _pendingPanel(
        localizations,
        localizations.subscriptionServerPending,
      ),
      BillingRestoreEmptyState() => _restoreEmptyPanel(localizations),
      BillingAssignmentConflictState(
        :final remediationRequest,
        :final remediationFailure,
      ) =>
        _conflictPanel(
          localizations,
          message: localizations.subscriptionConflictBody,
          remediationSubmitted: remediationRequest != null,
          remediationFailed: remediationFailure != null,
        ),
      BillingRestoreConflictState(
        :final remediationRequest,
        :final remediationFailure,
      ) =>
        _conflictPanel(
          localizations,
          message: localizations.subscriptionRestoreConflictBody,
          remediationSubmitted: remediationRequest != null,
          remediationFailed: remediationFailure != null,
        ),
      BillingFlowFailed(:final failure) => _failurePanel(
        localizations,
        failure,
        canRefresh: true,
        canReturn: _canReturnFromFailure(failure),
      ),
      BillingFlowInitial() ||
      BillingFlowLoading() => _busyPanel(localizations.subscriptionLoading),
    };
  }

  Widget _readySection(
    AppLocalizations localizations,
    BillingFlowReady state,
    BillingFlowSnapshot snapshot,
    _HouseholdBillingContext household,
  ) {
    final HouseholdEntitlement entitlement = snapshot.entitlement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.notice case final notice?) ...<Widget>[
          _messageCard(
            key: const Key('subscription.notice'),
            icon: Icons.check_circle_outline,
            message: _noticeLabel(localizations, notice),
            liveRegion: true,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (state.actionFailure case final failure?) ...<Widget>[
          _messageCard(
            key: const Key('subscription.failure'),
            icon: Icons.error_outline,
            message: _failureMessage(localizations, failure),
            liveRegion: true,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (!entitlement.hasPlus) ...<Widget>[
          _benefitsCard(localizations),
          const SizedBox(height: AppSpacing.md),
          if (!household.roleVerified)
            _messageCard(
              key: const Key('subscription.profileRequired'),
              icon: Icons.shield_outlined,
              message: localizations.subscriptionProfileUnavailable,
            )
          else if (!household.canManage)
            _messageCard(
              key: const Key('subscription.adminRequired'),
              icon: Icons.lock_outline,
              message: localizations.subscriptionAdminRequired,
            ),
          if (!household.canManage) const SizedBox(height: AppSpacing.md),
          if (snapshot.catalog case final catalog?)
            _offersCard(localizations, catalog, household)
          else
            _messageCard(
              key: const Key('subscription.storeUnavailable'),
              icon: Icons.storefront_outlined,
              message: localizations.subscriptionStoreUnavailable,
            ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('subscription.restore'),
            onPressed:
                household.canManage &&
                    snapshot.catalogFailure?.kind !=
                        BillingFailureKind.unsupported
                ? () =>
                      unawaited(_confirmRestore(localizations, household.name))
                : null,
            icon: const Icon(Icons.restore),
            label: Text(localizations.subscriptionRestoreAction),
          ),
        ] else if (_managementLink(entitlement) case final link?) ...<Widget>[
          FilledButton.icon(
            key: const Key('subscription.manage'),
            onPressed: entitlement.isBillingOwner && !_externalBusy
                ? () => unawaited(_openExternal(link))
                : null,
            icon: const Icon(Icons.open_in_new),
            label: Text(localizations.subscriptionManageAction),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('subscription.refresh'),
          onPressed: () => unawaited(
            ref.read(billingFlowProvider.notifier).refreshServerStatus(),
          ),
          icon: const Icon(Icons.refresh),
          label: Text(localizations.subscriptionRefreshAction),
        ),
      ],
    );
  }

  Widget _benefitsCard(AppLocalizations localizations) {
    return Card(
      key: const Key('subscription.benefits'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.subscriptionBenefitsHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            _benefit(
              Icons.group_add_outlined,
              localizations.subscriptionBenefitMembers,
            ),
            _benefit(
              Icons.event_repeat_outlined,
              localizations.subscriptionBenefitRecurring,
            ),
            _benefit(
              Icons.inventory_2_outlined,
              localizations.subscriptionBenefitData,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.subscriptionLimitsPending,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: AppIconSize.inline),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Widget _offersCard(
    AppLocalizations localizations,
    BillingCatalog catalog,
    _HouseholdBillingContext household,
  ) {
    final List<BillingPackage> packages = catalog.currentOffering.packages;
    return Card(
      key: const Key('subscription.offers'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.subscriptionOffersHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var index = 0; index < packages.length; index++) ...<Widget>[
              if (index > 0) const Divider(),
              _packageOption(localizations, packages[index], index, household),
            ],
          ],
        ),
      ),
    );
  }

  Widget _packageOption(
    AppLocalizations localizations,
    BillingPackage package,
    int index,
    _HouseholdBillingContext household,
  ) {
    final String period = _billingPeriodLabel(localizations, package.period);
    final String price = localizations.subscriptionPackagePrice(
      package.localizedPrice.value,
      period,
    );
    return Column(
      key: Key('subscription.package.$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(price, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          key: Key('subscription.purchase.$index'),
          onPressed: household.canManage
              ? () => unawaited(
                  _confirmPurchase(
                    localizations,
                    household.name,
                    package,
                    period,
                  ),
                )
              : null,
          icon: const Icon(Icons.shopping_bag_outlined),
          label: Text(localizations.subscriptionPurchaseAction),
        ),
      ],
    );
  }

  Widget _busyPanel(String message) {
    return Card(
      key: const Key('subscription.busy'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(message, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingPanel(AppLocalizations localizations, String message) {
    return Card(
      key: const Key('subscription.pending'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(liveRegion: true, child: Text(message)),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('subscription.refresh'),
              onPressed: () => unawaited(
                ref.read(billingFlowProvider.notifier).refreshServerStatus(),
              ),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.subscriptionRefreshAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _restoreEmptyPanel(AppLocalizations localizations) {
    return Card(
      key: const Key('subscription.restoreEmpty'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.subscriptionRestoreEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.subscriptionRestoreEmptyBody),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('subscription.return'),
              onPressed: ref.read(billingFlowProvider.notifier).returnToReady,
              child: Text(localizations.subscriptionReturnAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conflictPanel(
    AppLocalizations localizations, {
    required String message,
    required bool remediationSubmitted,
    required bool remediationFailed,
  }) {
    return Card(
      key: const Key('subscription.conflict'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.subscriptionConflictTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(message),
            if (remediationSubmitted) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(localizations.subscriptionRemediationSubmitted),
            ],
            if (remediationFailed) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(localizations.subscriptionRemediationFailed),
            ],
            const SizedBox(height: AppSpacing.md),
            if (!remediationSubmitted)
              FilledButton.icon(
                key: const Key('subscription.remediation'),
                onPressed: () => unawaited(
                  ref
                      .read(billingFlowProvider.notifier)
                      .requestAssignmentRemediation(),
                ),
                icon: const Icon(Icons.support_agent),
                label: Text(localizations.subscriptionRemediationAction),
              ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('subscription.support'),
              onPressed: _externalBusy
                  ? null
                  : () => unawaited(_openExternal(BillingExternalLink.support)),
              icon: const Icon(Icons.open_in_new),
              label: Text(localizations.subscriptionSupportAction),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              key: const Key('subscription.return'),
              onPressed: ref.read(billingFlowProvider.notifier).returnToReady,
              child: Text(localizations.subscriptionReturnAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failurePanel(
    AppLocalizations localizations,
    BillingFailure failure, {
    required bool canRefresh,
    required bool canReturn,
  }) {
    return Column(
      key: const Key('subscription.failure'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Icon(Icons.error_outline, size: AppIconSize.status),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          liveRegion: true,
          child: Text(
            _failureMessage(localizations, failure),
            textAlign: TextAlign.center,
          ),
        ),
        if (canRefresh) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('subscription.refresh'),
            onPressed: () => unawaited(
              ref.read(billingFlowProvider.notifier).refreshServerStatus(),
            ),
            icon: const Icon(Icons.refresh),
            label: Text(localizations.subscriptionRefreshAction),
          ),
        ],
        if (canReturn) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            key: const Key('subscription.return'),
            onPressed: ref.read(billingFlowProvider.notifier).returnToReady,
            child: Text(localizations.subscriptionReturnAction),
          ),
        ],
      ],
    );
  }

  Widget _messageCard({
    required Key key,
    required IconData icon,
    required String message,
    bool liveRegion = false,
  }) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: AppIconSize.inline),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Semantics(liveRegion: liveRegion, child: Text(message)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _policyLinks(AppLocalizations localizations) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        TextButton(
          key: const Key('subscription.terms'),
          onPressed: _externalBusy
              ? null
              : () => unawaited(_openExternal(BillingExternalLink.terms)),
          child: Text(localizations.subscriptionTermsAction),
        ),
        TextButton(
          key: const Key('subscription.privacy'),
          onPressed: _externalBusy
              ? null
              : () => unawaited(_openExternal(BillingExternalLink.privacy)),
          child: Text(localizations.subscriptionPrivacyAction),
        ),
      ],
    );
  }

  Future<void> _confirmPurchase(
    AppLocalizations localizations,
    String householdName,
    BillingPackage package,
    String period,
  ) async {
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              key: const Key('subscription.confirmPurchase'),
              title: Text(localizations.subscriptionPurchaseConfirmTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      localizations.subscriptionPurchaseConfirmBody(
                        householdName,
                        package.localizedPrice.value,
                        period,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(localizations.subscriptionPurchaseConfirmRenewal),
                    const SizedBox(height: AppSpacing.sm),
                    Text(localizations.subscriptionPurchaseConfirmServer),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(localizations.subscriptionCancelAction),
                ),
                FilledButton(
                  key: const Key('subscription.confirmPurchase.submit'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(localizations.subscriptionPurchaseConfirmAction),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await ref.read(billingFlowProvider.notifier).purchase(package.id);
  }

  Future<void> _confirmRestore(
    AppLocalizations localizations,
    String householdName,
  ) async {
    final bool confirmed =
        await showAppDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              key: const Key('subscription.confirmRestore'),
              title: Text(localizations.subscriptionRestoreConfirmTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      localizations.subscriptionRestoreConfirmBody(
                        householdName,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(localizations.subscriptionRestoreConfirmConflict),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(localizations.subscriptionCancelAction),
                ),
                FilledButton(
                  key: const Key('subscription.confirmRestore.submit'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(localizations.subscriptionRestoreConfirmAction),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await ref.read(billingFlowProvider.notifier).restore();
  }

  Future<void> _openExternal(BillingExternalLink link) async {
    if (_externalBusy) return;
    setState(() {
      _externalBusy = true;
      _externalFailure = false;
    });
    final BillingExternalLinkLaunchResult result = await ref
        .read(billingExternalLinkLauncherProvider)
        .launch(link);
    if (!mounted) return;
    setState(() {
      _externalBusy = false;
      _externalFailure = result != BillingExternalLinkLaunchResult.opened;
    });
  }

  _HouseholdBillingContext _householdContext(
    AppLocalizations localizations,
    BillingFlowSnapshot snapshot,
    ProfilePreferencesState state,
  ) {
    if (state case ProfilePreferencesReady(:final preferences)) {
      final bool matches =
          preferences.householdId == snapshot.context.householdId.value;
      if (matches) {
        return _HouseholdBillingContext(
          name: preferences.householdName,
          roleVerified: true,
          canManage:
              preferences.householdRole == ProfileHouseholdRole.owner ||
              preferences.householdRole == ProfileHouseholdRole.admin,
        );
      }
    }
    return _HouseholdBillingContext(
      name: localizations.subscriptionHouseholdFallback,
      roleVerified: false,
      canManage: false,
    );
  }

  String _formatDate(DateTime value) {
    return MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
  }

  String _periodEndLabel(
    AppLocalizations localizations,
    HouseholdEntitlement entitlement,
  ) {
    final DateTime? end = entitlement.currentPeriodEnd;
    if (end == null) return localizations.subscriptionNoPeriodEnd;
    final String date = _formatDate(end);
    return entitlement.willRenew
        ? localizations.subscriptionRenewsOn(date)
        : localizations.subscriptionAccessThrough(date);
  }

  String _statusLabel(
    AppLocalizations localizations,
    HouseholdEntitlementStatus status,
  ) {
    return switch (status) {
      HouseholdEntitlementStatus.none => localizations.subscriptionStatusNone,
      HouseholdEntitlementStatus.trialing =>
        localizations.subscriptionStatusTrialing,
      HouseholdEntitlementStatus.active =>
        localizations.subscriptionStatusActive,
      HouseholdEntitlementStatus.grace => localizations.subscriptionStatusGrace,
      HouseholdEntitlementStatus.billingIssue =>
        localizations.subscriptionStatusBillingIssue,
      HouseholdEntitlementStatus.expired =>
        localizations.subscriptionStatusExpired,
      HouseholdEntitlementStatus.revoked =>
        localizations.subscriptionStatusRevoked,
    };
  }

  String _sourceLabel(
    AppLocalizations localizations,
    EntitlementSource source,
  ) {
    return switch (source) {
      EntitlementSource.none => localizations.subscriptionSourceNone,
      EntitlementSource.playStore => localizations.subscriptionSourcePlayStore,
      EntitlementSource.appStore => localizations.subscriptionSourceAppStore,
      EntitlementSource.web => localizations.subscriptionSourceWeb,
      EntitlementSource.manualSupport =>
        localizations.subscriptionSourceSupport,
    };
  }

  String _billingOwnerLabel(
    AppLocalizations localizations,
    HouseholdEntitlement entitlement,
  ) {
    if (entitlement.source == EntitlementSource.none) {
      return localizations.subscriptionBillingOwnerNone;
    }
    return entitlement.isBillingOwner
        ? localizations.subscriptionBillingOwnerYou
        : localizations.subscriptionBillingOwnerOther;
  }

  String? _lifecycleMessage(
    AppLocalizations localizations,
    HouseholdEntitlement entitlement,
  ) {
    return switch (entitlement.lifecycleNotice) {
      HouseholdEntitlementLifecycleNotice.none => null,
      HouseholdEntitlementLifecycleNotice.trialing =>
        localizations.subscriptionLifecycleTrialing,
      HouseholdEntitlementLifecycleNotice.grace =>
        localizations.subscriptionLifecycleGrace,
      HouseholdEntitlementLifecycleNotice.billingIssue =>
        localizations.subscriptionLifecycleBillingIssue,
      HouseholdEntitlementLifecycleNotice.expired =>
        localizations.subscriptionLifecycleExpired,
      HouseholdEntitlementLifecycleNotice.revoked =>
        localizations.subscriptionLifecycleRevoked,
    };
  }

  String _billingPeriodLabel(
    AppLocalizations localizations,
    BillingPeriod period,
  ) {
    return switch (period.unit) {
      BillingPeriodUnit.day => localizations.subscriptionPeriodDays(
        period.count,
      ),
      BillingPeriodUnit.week => localizations.subscriptionPeriodWeeks(
        period.count,
      ),
      BillingPeriodUnit.month => localizations.subscriptionPeriodMonths(
        period.count,
      ),
      BillingPeriodUnit.year => localizations.subscriptionPeriodYears(
        period.count,
      ),
    };
  }

  String _noticeLabel(
    AppLocalizations localizations,
    BillingReadyNotice notice,
  ) {
    return switch (notice) {
      BillingReadyNotice.purchaseCancelled =>
        localizations.subscriptionNoticePurchaseCancelled,
      BillingReadyNotice.alreadyActive =>
        localizations.subscriptionNoticeAlreadyActive,
      BillingReadyNotice.purchaseServerConfirmed =>
        localizations.subscriptionNoticePurchaseConfirmed,
      BillingReadyNotice.restoreServerConfirmed =>
        localizations.subscriptionNoticeRestoreConfirmed,
      BillingReadyNotice.serverRefreshed =>
        localizations.subscriptionNoticeServerRefreshed,
    };
  }

  String _failureMessage(
    AppLocalizations localizations,
    BillingFailure failure,
  ) {
    return switch (failure.kind) {
      BillingFailureKind.unsupported =>
        localizations.subscriptionFailureUnsupported,
      BillingFailureKind.unauthenticated =>
        localizations.subscriptionFailureUnauthenticated,
      BillingFailureKind.identityConflict ||
      BillingFailureKind.identityClearFailed =>
        localizations.subscriptionFailureIdentity,
      BillingFailureKind.invalidInput =>
        localizations.subscriptionFailureInvalidInput,
      BillingFailureKind.catalogUnavailable =>
        localizations.subscriptionFailureCatalog,
      BillingFailureKind.storeUnavailable ||
      BillingFailureKind.providerRejected =>
        localizations.subscriptionFailureStore,
      BillingFailureKind.networkUnavailable =>
        localizations.subscriptionFailureNetwork,
      BillingFailureKind.serverAuthorization =>
        localizations.subscriptionFailureAuthorization,
      BillingFailureKind.serverUnavailable =>
        localizations.subscriptionFailureServer,
      BillingFailureKind.invalidServerState =>
        localizations.subscriptionFailureInvalidState,
      BillingFailureKind.unknown => localizations.subscriptionFailureUnknown,
    };
  }

  bool _canReturnFromFailure(BillingFailure failure) {
    return failure.kind != BillingFailureKind.identityConflict &&
        failure.kind != BillingFailureKind.identityClearFailed &&
        failure.kind != BillingFailureKind.unauthenticated;
  }

  BillingExternalLink? _managementLink(HouseholdEntitlement entitlement) {
    if (!entitlement.isBillingOwner) return null;
    return switch (entitlement.source) {
      EntitlementSource.playStore =>
        BillingExternalLink.googlePlaySubscriptions,
      EntitlementSource.appStore =>
        BillingExternalLink.appleAppStoreSubscriptions,
      EntitlementSource.web ||
      EntitlementSource.manualSupport ||
      EntitlementSource.none => null,
    };
  }
}

final class _HouseholdBillingContext {
  const _HouseholdBillingContext({
    required this.name,
    required this.roleVerified,
    required this.canManage,
  });

  final String name;
  final bool roleVerified;
  final bool canManage;
}
