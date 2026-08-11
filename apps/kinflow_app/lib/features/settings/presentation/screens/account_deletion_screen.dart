import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/settings/application/account_deletion_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/account_deletion.dart';
import 'package:kinflow_app/features/settings/domain/failures/account_deletion_failure.dart';
import 'package:kinflow_app/features/settings/presentation/account_deletion_failure_message.dart';
import 'package:kinflow_app/features/settings/presentation/providers/account_deletion_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class AccountDeletionScreen extends ConsumerStatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  ConsumerState<AccountDeletionScreen> createState() =>
      _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends ConsumerState<AccountDeletionScreen> {
  bool _subscriptionAcknowledged = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(accountDeletionProvider.notifier).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    ref.listen<AccountDeletionState>(accountDeletionProvider, (
      AccountDeletionState? previous,
      AccountDeletionState next,
    ) {
      final bool previouslyRequested =
          previous is AccountDeletionReady && previous.logoutRequested;
      if (next is AccountDeletionReady &&
          next.logoutRequested &&
          !previouslyRequested) {
        scheduleMicrotask(() {
          if (!mounted) {
            return;
          }
          ref.read(accountDeletionProvider.notifier).acknowledgeLogoutRequest();
          unawaited(ref.read(accountDeletionAcceptedHandlerProvider)());
        });
      }
    });
    final AccountDeletionState state = ref.watch(accountDeletionProvider);
    final bool busy = state is AccountDeletionReady && state.busy;
    return AppResponsiveScaffold(
      key: const Key('accountDeletion.screen'),
      title: localizations.accountDeletionTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('accountDeletion.refresh'),
          onPressed: busy
              ? null
              : () => unawaited(
                  ref
                      .read(accountDeletionProvider.notifier)
                      .load(preserveContent: true),
                ),
          tooltip: localizations.retryAction,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const Key('accountDeletion.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: _body(localizations, state),
    );
  }

  Widget _body(AppLocalizations localizations, AccountDeletionState state) {
    return switch (state) {
      AccountDeletionInitial() ||
      AccountDeletionLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('accountDeletion.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.accountDeletionLoadingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      AccountDeletionLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('accountDeletion.error'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.person_off_outlined, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                accountDeletionFailureMessage(localizations, failure),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('accountDeletion.retry'),
              onPressed: () =>
                  unawaited(ref.read(accountDeletionProvider.notifier).load()),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      AccountDeletionReady() => _ready(localizations, state),
    };
  }

  Widget _ready(AppLocalizations localizations, AccountDeletionReady state) {
    final AccountDeletionRequest? request = state.latestRequest;
    final bool pending = request?.status.isPending == true;
    return ListView(
      key: const Key('accountDeletion.content'),
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
                _explanationCard(localizations),
                if (state.isRefreshing) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(),
                ],
                if (state.failure != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _failureBanner(localizations, state.failure!),
                ],
                if (request != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _statusCard(localizations, state, request),
                ],
                if (!pending &&
                    state.preflight.requiresOwnerTransfer) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _ownerBlockCard(localizations, state.preflight),
                ],
                if (!pending && !state.preflight.requestsEnabled) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _pausedCard(localizations),
                ],
                if (!pending &&
                    state.preflight.hasActiveSubscription) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _subscriptionCard(localizations, state),
                ],
                if (!pending) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    key: const Key('accountDeletion.request'),
                    onPressed:
                        state.busy ||
                            !state.preflight.canRequest ||
                            state.preflight.hasActiveSubscription &&
                                !_subscriptionAcknowledged
                        ? null
                        : () => _confirmRequest(localizations),
                    icon: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_remove_outlined),
                    label: Text(localizations.accountDeletionRequestAction),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    localizations.accountDeletionCancellationWindow(
                      (state.preflight.cancellationWindow.inMinutes / 60)
                          .ceil(),
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _explanationCard(AppLocalizations localizations) {
    return Card(
      key: const Key('accountDeletion.explanation'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              localizations.accountDeletionIntroHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.accountDeletionIntroBody),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.accountDeletionPreservedBody),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(
    AppLocalizations localizations,
    AccountDeletionReady state,
    AccountDeletionRequest request,
  ) {
    return Card(
      key: const Key('accountDeletion.status'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.accountDeletionStatusHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(_statusIcon(request.status)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _statusLabel(localizations, request.status),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ),
              ],
            ),
            if (request.status.isPending) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                localizations.accountDeletionScheduledFor(
                  _formatDateTime(request.scheduledFor),
                ),
              ),
            ],
            if (request.cancellable) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: const Key('accountDeletion.cancel'),
                onPressed: state.busy
                    ? null
                    : () => _confirmCancellation(localizations),
                icon: state.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo),
                label: Text(localizations.accountDeletionCancelAction),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ownerBlockCard(
    AppLocalizations localizations,
    AccountDeletionPreflight preflight,
  ) {
    return Card(
      key: const Key('accountDeletion.ownerBlock'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.accountDeletionOwnerBlockTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.accountDeletionOwnerBlockBody(
                preflight.ownerHouseholdCount,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('accountDeletion.manageHouseholds'),
              onPressed: () => context.go(AppRoutes.householdMembers),
              icon: const Icon(Icons.group_outlined),
              label: Text(localizations.accountDeletionManageHouseholdsAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subscriptionCard(
    AppLocalizations localizations,
    AccountDeletionReady state,
  ) {
    return Card(
      key: const Key('accountDeletion.subscription'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              localizations.accountDeletionSubscriptionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.accountDeletionSubscriptionBody),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              key: const Key('accountDeletion.subscriptionAcknowledgement'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _subscriptionAcknowledged,
              onChanged: state.busy
                  ? null
                  : (bool? value) {
                      setState(() => _subscriptionAcknowledged = value == true);
                    },
              title: Text(localizations.accountDeletionSubscriptionAcknowledge),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pausedCard(AppLocalizations localizations) {
    return Card(
      key: const Key('accountDeletion.paused'),
      child: ListTile(
        leading: const Icon(Icons.pause_circle_outline),
        title: Text(localizations.accountDeletionPausedTitle),
        subtitle: Text(localizations.accountDeletionPausedBody),
      ),
    );
  }

  Widget _failureBanner(
    AppLocalizations localizations,
    AccountDeletionFailure failure,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('accountDeletion.actionError'),
      color: colors.errorContainer,
      borderRadius: AppRadii.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: Text(
            accountDeletionFailureMessage(localizations, failure),
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRequest(AppLocalizations localizations) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(localizations.accountDeletionConfirmTitle),
        content: Text(localizations.accountDeletionConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('accountDeletion.confirm.keep'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.accountDeletionConfirmCancelAction),
          ),
          FilledButton(
            key: const Key('accountDeletion.confirm.delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.accountDeletionConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      unawaited(
        ref
            .read(accountDeletionProvider.notifier)
            .requestDeletion(
              subscriptionAcknowledged: _subscriptionAcknowledged,
            ),
      );
    }
  }

  Future<void> _confirmCancellation(AppLocalizations localizations) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(localizations.accountDeletionCancelConfirmTitle),
        content: Text(localizations.accountDeletionCancelConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('accountDeletion.cancelConfirm.keep'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.accountDeletionConfirmCancelAction),
          ),
          FilledButton(
            key: const Key('accountDeletion.cancelConfirm.cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.accountDeletionCancelConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      unawaited(ref.read(accountDeletionProvider.notifier).cancel());
    }
  }

  String _formatDateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String date = material.formatMediumDate(local);
    final String time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date · $time';
  }

  String _statusLabel(
    AppLocalizations localizations,
    AccountDeletionRequestStatus status,
  ) {
    return switch (status) {
      AccountDeletionRequestStatus.queued =>
        localizations.accountDeletionStatusQueued,
      AccountDeletionRequestStatus.verifying =>
        localizations.accountDeletionStatusVerifying,
      AccountDeletionRequestStatus.processing =>
        localizations.accountDeletionStatusProcessing,
      AccountDeletionRequestStatus.completed =>
        localizations.accountDeletionStatusCompleted,
      AccountDeletionRequestStatus.failed =>
        localizations.accountDeletionStatusFailed,
      AccountDeletionRequestStatus.cancelled =>
        localizations.accountDeletionStatusCancelled,
    };
  }

  IconData _statusIcon(AccountDeletionRequestStatus status) {
    return switch (status) {
      AccountDeletionRequestStatus.queued => Icons.schedule,
      AccountDeletionRequestStatus.verifying => Icons.verified_user_outlined,
      AccountDeletionRequestStatus.processing => Icons.sync,
      AccountDeletionRequestStatus.completed => Icons.check_circle_outline,
      AccountDeletionRequestStatus.failed => Icons.error_outline,
      AccountDeletionRequestStatus.cancelled => Icons.undo,
    };
  }
}
