import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/settings/application/household_privacy_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/household_privacy.dart';
import 'package:kinflow_app/features/settings/domain/failures/household_privacy_failure.dart';
import 'package:kinflow_app/features/settings/presentation/household_privacy_failure_message.dart';
import 'package:kinflow_app/features/settings/presentation/providers/household_privacy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class HouseholdPrivacyScreen extends ConsumerStatefulWidget {
  const HouseholdPrivacyScreen({super.key});

  @override
  ConsumerState<HouseholdPrivacyScreen> createState() =>
      _HouseholdPrivacyScreenState();
}

class _HouseholdPrivacyScreenState
    extends ConsumerState<HouseholdPrivacyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(householdPrivacyProvider.notifier).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final HouseholdPrivacyState state = ref.watch(householdPrivacyProvider);
    final bool busy = state is HouseholdPrivacyReady && state.busy;
    return AppResponsiveScaffold(
      key: const Key('householdPrivacy.screen'),
      title: localizations.householdPrivacyTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('householdPrivacy.refresh'),
          onPressed: busy
              ? null
              : () => unawaited(
                  ref
                      .read(householdPrivacyProvider.notifier)
                      .load(preserveContent: true),
                ),
          tooltip: localizations.retryAction,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const Key('householdPrivacy.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: _body(localizations, state),
    );
  }

  Widget _body(AppLocalizations localizations, HouseholdPrivacyState state) {
    return switch (state) {
      HouseholdPrivacyInitial() ||
      HouseholdPrivacyLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('householdPrivacy.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.householdPrivacyLoadingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      HouseholdPrivacyLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('householdPrivacy.error'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.admin_panel_settings_outlined, size: 52),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                householdPrivacyFailureMessage(localizations, failure),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('householdPrivacy.retry'),
              onPressed: () =>
                  unawaited(ref.read(householdPrivacyProvider.notifier).load()),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      HouseholdPrivacyReady() => _ready(localizations, state),
    };
  }

  Widget _ready(AppLocalizations localizations, HouseholdPrivacyReady state) {
    final HouseholdPrivacyPreflight preflight = state.preflight;
    final HouseholdPrivacyRequest? request = state.latestRequest;
    final bool pending = request?.status.isPending == true;
    final bool hasAvailableArtifact = request?.artifact?.available == true;
    return ListView(
      key: const Key('householdPrivacy.content'),
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
                _introCard(localizations, preflight),
                if (state.isRefreshing) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(),
                ],
                if (state.failure != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _failureBanner(localizations, state.failure!),
                ],
                if (state.lastOpenedFormat != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _successBanner(
                    localizations.householdPrivacyOpenedMessage(
                      state.lastOpenedFormat == HouseholdExportFormat.json
                          ? localizations.dataExportJsonFormat
                          : localizations.dataExportTextFormat,
                    ),
                  ),
                ],
                if (request != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _statusCard(localizations, state, request),
                ],
                if (!pending && !hasAvailableArtifact) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _exportCard(localizations, state),
                ],
                if (!pending) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _deletionCard(localizations, state),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _introCard(
    AppLocalizations localizations,
    HouseholdPrivacyPreflight preflight,
  ) {
    return Card(
      key: const Key('householdPrivacy.intro'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              localizations.householdPrivacyIntroHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.householdPrivacyIntroBody),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.householdPrivacyMemberCount(preflight.memberCount),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.householdPrivacyExportRetention(
                (preflight.artifactRetention.inMinutes / 60).ceil(),
                preflight.downloadGrantLifetime.inMinutes,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              localizations.householdPrivacyDeletionWindow(
                (preflight.deletionCancellationWindow.inMinutes / 60).ceil(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportCard(
    AppLocalizations localizations,
    HouseholdPrivacyReady state,
  ) {
    return Card(
      key: const Key('householdPrivacy.export'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.householdPrivacyExportHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.householdPrivacyExportBody),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonalIcon(
              key: const Key('householdPrivacy.requestExport'),
              onPressed: !state.preflight.canExport || state.busy
                  ? null
                  : () => _confirmExport(localizations),
              icon: const Icon(Icons.archive_outlined),
              label: Text(localizations.householdPrivacyExportAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deletionCard(
    AppLocalizations localizations,
    HouseholdPrivacyReady state,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      key: const Key('householdPrivacy.deletion'),
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.householdPrivacyDeleteHeading,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: colors.onErrorContainer),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.householdPrivacyDeleteBody,
              style: TextStyle(color: colors.onErrorContainer),
            ),
            if (state.preflight.activeSubscription) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Text(
                localizations.householdPrivacySubscriptionWarning,
                style: TextStyle(
                  color: colors.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('householdPrivacy.requestDeletion'),
              onPressed: !state.preflight.canDelete || state.busy
                  ? null
                  : () => _confirmDeletion(localizations, state.preflight),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(localizations.householdPrivacyDeleteAction),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(
    AppLocalizations localizations,
    HouseholdPrivacyReady state,
    HouseholdPrivacyRequest request,
  ) {
    final HouseholdDeletionProgress? deletion = request.deletion;
    return Card(
      key: const Key('householdPrivacy.status'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.householdPrivacyStatusHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              request.kind == HouseholdPrivacyRequestKind.export
                  ? localizations.householdPrivacyExportKind
                  : localizations.householdPrivacyDeletionKind,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Semantics(
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(_statusIcon(request.status)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(_statusLabel(localizations, request.status)),
                  ),
                ],
              ),
            ),
            if (deletion?.retentionBlocked == true) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _warningBanner(localizations.householdPrivacyRetentionBlocked),
              if (deletion?.retentionReviewAt != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  localizations.householdPrivacyRetentionReview(
                    _formatDateTime(deletion!.retentionReviewAt!),
                  ),
                ),
              ],
            ],
            if (request.cancellable) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: const Key('householdPrivacy.cancel'),
                onPressed: state.busy
                    ? null
                    : () => _confirmCancellation(localizations),
                icon: const Icon(Icons.undo),
                label: Text(localizations.householdPrivacyCancelAction),
              ),
            ],
            if (request.kind == HouseholdPrivacyRequestKind.export &&
                request.status ==
                    HouseholdPrivacyRequestStatus.completed) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              if (request.artifact?.available == true)
                _downloads(localizations, state, request.artifact!)
              else
                Text(localizations.householdPrivacyArtifactError),
              if (request.artifact?.revokedAt == null &&
                  request.artifact?.purgedAt == null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  key: const Key('householdPrivacy.revoke'),
                  onPressed: state.busy
                      ? null
                      : () => _confirmRevocation(localizations),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(localizations.householdPrivacyRevokeAction),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _downloads(
    AppLocalizations localizations,
    HouseholdPrivacyReady state,
    HouseholdExportArtifact artifact,
  ) {
    return Column(
      key: const Key('householdPrivacy.downloads'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          localizations.householdPrivacyDownloadHeading,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(localizations.householdPrivacyDownloadBody),
        if (artifact.expiresAt != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.dataExportExpiresAt(
              _formatDateTime(artifact.expiresAt!),
            ),
          ),
        ],
        if (artifact.machineSizeBytes != null &&
            artifact.humanSizeBytes != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.dataExportFileSizes(
              _formatSize(localizations, artifact.machineSizeBytes!),
              _formatSize(localizations, artifact.humanSizeBytes!),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            FilledButton.tonalIcon(
              key: const Key('householdPrivacy.downloadJson'),
              onPressed: !state.preflight.downloadsEnabled || state.busy
                  ? null
                  : () => unawaited(
                      ref
                          .read(householdPrivacyProvider.notifier)
                          .download(HouseholdExportFormat.json),
                    ),
              icon: const Icon(Icons.data_object),
              label: Text(localizations.dataExportJsonAction),
            ),
            FilledButton.tonalIcon(
              key: const Key('householdPrivacy.downloadText'),
              onPressed: !state.preflight.downloadsEnabled || state.busy
                  ? null
                  : () => unawaited(
                      ref
                          .read(householdPrivacyProvider.notifier)
                          .download(HouseholdExportFormat.text),
                    ),
              icon: const Icon(Icons.description_outlined),
              label: Text(localizations.dataExportTextAction),
            ),
          ],
        ),
      ],
    );
  }

  Widget _failureBanner(
    AppLocalizations localizations,
    HouseholdPrivacyFailure failure,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('householdPrivacy.actionError'),
      color: colors.errorContainer,
      borderRadius: AppRadii.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: Text(
            householdPrivacyFailureMessage(localizations, failure),
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
      ),
    );
  }

  Widget _successBanner(String message) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('householdPrivacy.opened'),
      color: colors.secondaryContainer,
      borderRadius: AppRadii.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: Text(
            message,
            style: TextStyle(color: colors.onSecondaryContainer),
          ),
        ),
      ),
    );
  }

  Widget _warningBanner(String message) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.tertiaryContainer,
      borderRadius: AppRadii.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          message,
          style: TextStyle(color: colors.onTertiaryContainer),
        ),
      ),
    );
  }

  Future<void> _confirmExport(AppLocalizations localizations) async {
    final bool? confirmed = await _simpleConfirmation(
      title: localizations.householdPrivacyExportConfirmTitle,
      body: localizations.householdPrivacyExportConfirmBody,
      confirmLabel: localizations.householdPrivacyExportAction,
      confirmKey: const Key('householdPrivacy.exportConfirm.submit'),
    );
    if (confirmed == true && mounted) {
      unawaited(ref.read(householdPrivacyProvider.notifier).requestExport());
    }
  }

  Future<void> _confirmCancellation(AppLocalizations localizations) async {
    final bool? confirmed = await _simpleConfirmation(
      title: localizations.householdPrivacyCancelConfirmTitle,
      body: localizations.householdPrivacyCancelConfirmBody,
      confirmLabel: localizations.householdPrivacyCancelAction,
      confirmKey: const Key('householdPrivacy.cancelConfirm.submit'),
    );
    if (confirmed == true && mounted) {
      unawaited(ref.read(householdPrivacyProvider.notifier).cancel());
    }
  }

  Future<void> _confirmRevocation(AppLocalizations localizations) async {
    final bool? confirmed = await _simpleConfirmation(
      title: localizations.householdPrivacyRevokeConfirmTitle,
      body: localizations.householdPrivacyRevokeConfirmBody,
      confirmLabel: localizations.householdPrivacyRevokeAction,
      confirmKey: const Key('householdPrivacy.revokeConfirm.submit'),
    );
    if (confirmed == true && mounted) {
      unawaited(ref.read(householdPrivacyProvider.notifier).revokeExport());
    }
  }

  Future<bool?> _simpleConfirmation({
    required String title,
    required String body,
    required String confirmLabel,
    required Key confirmKey,
  }) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.dataExportDismissAction),
          ),
          FilledButton(
            key: confirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeletion(
    AppLocalizations localizations,
    HouseholdPrivacyPreflight preflight,
  ) async {
    String confirmationName = '';
    bool memberAccess = false;
    bool redaction = false;
    bool subscription = false;
    final _DeletionConfirmation?
    confirmation = await showAppDialog<_DeletionConfirmation>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final bool valid =
              confirmationName == preflight.household.name &&
              memberAccess &&
              redaction &&
              (!preflight.activeSubscription || subscription);
          return AlertDialog(
            title: Text(localizations.householdPrivacyDeleteConfirmTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(localizations.householdPrivacyDeleteConfirmBody),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    key: const Key('householdPrivacy.delete.name'),
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: localizations.householdPrivacyNameLabel,
                      hintText: localizations.householdPrivacyNameHint(
                        preflight.household.name,
                      ),
                    ),
                    onChanged: (String value) =>
                        setDialogState(() => confirmationName = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CheckboxListTile(
                    key: const Key('householdPrivacy.delete.memberAck'),
                    contentPadding: EdgeInsets.zero,
                    value: memberAccess,
                    onChanged: (bool? value) =>
                        setDialogState(() => memberAccess = value ?? false),
                    title: Text(localizations.householdPrivacyMemberAccessAck),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    key: const Key('householdPrivacy.delete.redactionAck'),
                    contentPadding: EdgeInsets.zero,
                    value: redaction,
                    onChanged: (bool? value) =>
                        setDialogState(() => redaction = value ?? false),
                    title: Text(localizations.householdPrivacyRedactionAck),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (preflight.activeSubscription)
                    CheckboxListTile(
                      key: const Key('householdPrivacy.delete.subscriptionAck'),
                      contentPadding: EdgeInsets.zero,
                      value: subscription,
                      onChanged: (bool? value) =>
                          setDialogState(() => subscription = value ?? false),
                      title: Text(
                        localizations.householdPrivacySubscriptionAck,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(localizations.dataExportDismissAction),
              ),
              FilledButton(
                key: const Key('householdPrivacy.delete.submit'),
                onPressed: valid
                    ? () => Navigator.of(dialogContext).pop(
                        _DeletionConfirmation(
                          name: confirmationName,
                          memberAccess: memberAccess,
                          redaction: redaction,
                          subscription: subscription,
                        ),
                      )
                    : null,
                child: Text(localizations.householdPrivacyDeleteConfirmAction),
              ),
            ],
          );
        },
      ),
    );
    if (confirmation != null && mounted) {
      unawaited(
        ref
            .read(householdPrivacyProvider.notifier)
            .requestDeletion(
              confirmationName: confirmation.name,
              acknowledgeMemberAccessLoss: confirmation.memberAccess,
              acknowledgeSharedDataRedaction: confirmation.redaction,
              acknowledgeSubscriptionNotCancelled: confirmation.subscription,
            ),
      );
    }
  }

  IconData _statusIcon(HouseholdPrivacyRequestStatus status) =>
      switch (status) {
        HouseholdPrivacyRequestStatus.queued => Icons.schedule,
        HouseholdPrivacyRequestStatus.verifying => Icons.verified_user_outlined,
        HouseholdPrivacyRequestStatus.processing => Icons.sync,
        HouseholdPrivacyRequestStatus.completed => Icons.check_circle_outline,
        HouseholdPrivacyRequestStatus.failed => Icons.error_outline,
        HouseholdPrivacyRequestStatus.cancelled => Icons.cancel_outlined,
      };

  String _statusLabel(
    AppLocalizations localizations,
    HouseholdPrivacyRequestStatus status,
  ) => switch (status) {
    HouseholdPrivacyRequestStatus.queued =>
      localizations.householdPrivacyStatusQueued,
    HouseholdPrivacyRequestStatus.verifying =>
      localizations.householdPrivacyStatusVerifying,
    HouseholdPrivacyRequestStatus.processing =>
      localizations.householdPrivacyStatusProcessing,
    HouseholdPrivacyRequestStatus.completed =>
      localizations.householdPrivacyStatusCompleted,
    HouseholdPrivacyRequestStatus.failed =>
      localizations.householdPrivacyStatusFailed,
    HouseholdPrivacyRequestStatus.cancelled =>
      localizations.householdPrivacyStatusCancelled,
  };

  String _formatDateTime(DateTime value) => DateFormat.yMMMd(
    Localizations.localeOf(context).toLanguageTag(),
  ).add_jm().format(value.toLocal());

  String _formatSize(AppLocalizations localizations, int bytes) {
    if (bytes >= 1024 * 1024) {
      return localizations.dataExportMegabytes(
        (bytes / (1024 * 1024)).toStringAsFixed(1),
      );
    }
    if (bytes >= 1024) {
      return localizations.dataExportKilobytes(
        (bytes / 1024).toStringAsFixed(1),
      );
    }
    return localizations.dataExportBytes(bytes.toString());
  }
}

final class _DeletionConfirmation {
  const _DeletionConfirmation({
    required this.name,
    required this.memberAccess,
    required this.redaction,
    required this.subscription,
  });

  final String name;
  final bool memberAccess;
  final bool redaction;
  final bool subscription;
}
