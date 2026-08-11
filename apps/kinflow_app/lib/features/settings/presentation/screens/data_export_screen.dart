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
import 'package:kinflow_app/features/settings/application/data_export_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/data_export.dart';
import 'package:kinflow_app/features/settings/domain/failures/data_export_failure.dart';
import 'package:kinflow_app/features/settings/presentation/data_export_failure_message.dart';
import 'package:kinflow_app/features/settings/presentation/providers/data_export_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(dataExportProvider.notifier).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final DataExportState state = ref.watch(dataExportProvider);
    final bool busy = state is DataExportReady && state.busy;
    return AppResponsiveScaffold(
      key: const Key('dataExport.screen'),
      title: localizations.dataExportTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('dataExport.refresh'),
          onPressed: busy
              ? null
              : () => unawaited(
                  ref
                      .read(dataExportProvider.notifier)
                      .load(preserveContent: true),
                ),
          tooltip: localizations.retryAction,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const Key('dataExport.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: _body(localizations, state),
    );
  }

  Widget _body(AppLocalizations localizations, DataExportState state) {
    return switch (state) {
      DataExportInitial() || DataExportLoading() => ScrollableStatusLayout(
        child: Column(
          key: const Key('dataExport.loading'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.dataExportLoadingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      DataExportLoadFailed(:final failure) => ScrollableStatusLayout(
        child: Column(
          key: const Key('dataExport.error'),
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.file_download_off_outlined,
              size: AppIconSize.status,
            ),
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                dataExportFailureMessage(localizations, failure),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('dataExport.retry'),
              onPressed: () =>
                  unawaited(ref.read(dataExportProvider.notifier).load()),
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      DataExportReady() => _ready(localizations, state),
    };
  }

  Widget _ready(AppLocalizations localizations, DataExportReady state) {
    final DataExportRequest? request = state.latestRequest;
    final bool pending = request?.status.isPending == true;
    final bool currentArtifactAvailable = request?.artifact.available == true;
    final bool showNewRequest =
        !pending && !currentArtifactAvailable && state.preflight.canRequest;
    return ListView(
      key: const Key('dataExport.content'),
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
                _explanationCard(localizations, state.preflight),
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
                  _openedBanner(localizations, state.lastOpenedFormat!),
                ],
                if (request != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _statusCard(localizations, state, request),
                ],
                if (!pending &&
                    state.preflight.conflictingRequestPending) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _infoCard(
                    key: const Key('dataExport.conflict'),
                    icon: Icons.privacy_tip_outlined,
                    body: localizations.dataExportConflictingRequestBody,
                  ),
                ],
                if (!pending && !state.preflight.requestsEnabled) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  _infoCard(
                    key: const Key('dataExport.paused'),
                    icon: Icons.pause_circle_outline,
                    title: localizations.dataExportRequestsPausedTitle,
                    body: localizations.dataExportRequestsPausedBody,
                  ),
                ],
                if (showNewRequest) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.icon(
                    key: const Key('dataExport.request'),
                    onPressed: state.busy
                        ? null
                        : () => _confirmRequest(localizations),
                    icon: state.isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.archive_outlined),
                    label: Text(localizations.dataExportRequestAction),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _explanationCard(
    AppLocalizations localizations,
    DataExportPreflight preflight,
  ) {
    return Card(
      key: const Key('dataExport.explanation'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              localizations.dataExportIntroHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.dataExportIntroBody),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.dataExportScopeBody),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.dataExportRetentionBody(
                (preflight.artifactRetention.inMinutes / 60).ceil(),
                preflight.downloadGrantLifetime.inMinutes,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(
    AppLocalizations localizations,
    DataExportReady state,
    DataExportRequest request,
  ) {
    return Card(
      key: const Key('dataExport.status'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.dataExportStatusHeading,
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
            if (request.cancellable) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                key: const Key('dataExport.cancel'),
                onPressed: state.busy
                    ? null
                    : () => _confirmCancellation(localizations),
                icon: const Icon(Icons.undo),
                label: Text(localizations.dataExportCancelAction),
              ),
            ],
            if (request.status ==
                DataExportRequestStatus.completed) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              if (request.artifact.available)
                _downloadSection(localizations, state, request)
              else
                Text(_unavailableArtifactBody(localizations, request.artifact)),
              if (request.artifact.revokedAt == null &&
                  request.artifact.purgedAt == null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  key: const Key('dataExport.revoke'),
                  onPressed: state.busy
                      ? null
                      : () => _confirmRevocation(localizations),
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: Text(localizations.dataExportRevokeAction),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _downloadSection(
    AppLocalizations localizations,
    DataExportReady state,
    DataExportRequest request,
  ) {
    final DataExportArtifact artifact = request.artifact;
    return Column(
      key: const Key('dataExport.downloads'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          localizations.dataExportDownloadHeading,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(localizations.dataExportDownloadBody),
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
        if (!state.preflight.downloadsEnabled)
          _infoCard(
            key: const Key('dataExport.downloadsPaused'),
            icon: Icons.pause_circle_outline,
            body: localizations.dataExportDownloadsPausedBody,
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              FilledButton.tonalIcon(
                key: const Key('dataExport.downloadJson'),
                onPressed: state.busy
                    ? null
                    : () => unawaited(
                        ref
                            .read(dataExportProvider.notifier)
                            .download(DataExportFormat.json),
                      ),
                icon: const Icon(Icons.data_object),
                label: Text(localizations.dataExportJsonAction),
              ),
              FilledButton.tonalIcon(
                key: const Key('dataExport.downloadText'),
                onPressed: state.busy
                    ? null
                    : () => unawaited(
                        ref
                            .read(dataExportProvider.notifier)
                            .download(DataExportFormat.text),
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
    DataExportFailure failure,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('dataExport.actionError'),
      color: colors.errorContainer,
      borderRadius: AppRadii.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: Text(
            dataExportFailureMessage(localizations, failure),
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
      ),
    );
  }

  Widget _openedBanner(
    AppLocalizations localizations,
    DataExportFormat format,
  ) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('dataExport.opened'),
      color: colors.secondaryContainer,
      borderRadius: AppRadii.medium,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: Text(
            localizations.dataExportOpenedMessage(
              format == DataExportFormat.json
                  ? localizations.dataExportJsonFormat
                  : localizations.dataExportTextFormat,
            ),
            style: TextStyle(color: colors.onSecondaryContainer),
          ),
        ),
      ),
    );
  }

  Widget _infoCard({
    required Key key,
    required IconData icon,
    required String body,
    String? title,
  }) {
    return Card(
      key: key,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title ?? body),
        subtitle: title == null ? null : Text(body),
        contentPadding: const EdgeInsets.all(AppSpacing.sm),
        isThreeLine: title != null,
        dense: title == null,
        visualDensity: VisualDensity.standard,
      ),
    );
  }

  Future<void> _confirmRequest(AppLocalizations localizations) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(localizations.dataExportConfirmTitle),
        content: Text(localizations.dataExportConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('dataExport.confirm.dismiss'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.dataExportDismissAction),
          ),
          FilledButton(
            key: const Key('dataExport.confirm.create'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.dataExportConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      unawaited(ref.read(dataExportProvider.notifier).requestExport());
    }
  }

  Future<void> _confirmCancellation(AppLocalizations localizations) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(localizations.dataExportCancelConfirmTitle),
        content: Text(localizations.dataExportCancelConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('dataExport.cancelConfirm.keep'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.dataExportDismissAction),
          ),
          FilledButton(
            key: const Key('dataExport.cancelConfirm.cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.dataExportCancelConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      unawaited(ref.read(dataExportProvider.notifier).cancel());
    }
  }

  Future<void> _confirmRevocation(AppLocalizations localizations) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(localizations.dataExportRevokeConfirmTitle),
        content: Text(localizations.dataExportRevokeConfirmBody),
        actions: <Widget>[
          TextButton(
            key: const Key('dataExport.revokeConfirm.keep'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.dataExportDismissAction),
          ),
          FilledButton(
            key: const Key('dataExport.revokeConfirm.delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.dataExportRevokeConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      unawaited(ref.read(dataExportProvider.notifier).revoke());
    }
  }

  String _unavailableArtifactBody(
    AppLocalizations localizations,
    DataExportArtifact artifact,
  ) {
    if (artifact.purgedAt != null) {
      return localizations.dataExportPurgedBody;
    }
    if (artifact.revokedAt != null) {
      return localizations.dataExportRevokedBody;
    }
    return localizations.dataExportExpiredBody;
  }

  String _formatDateTime(DateTime value) {
    final DateTime local = value.toLocal();
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String date = material.formatMediumDate(local);
    final String time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date, $time';
  }

  String _formatSize(AppLocalizations localizations, int bytes) {
    final NumberFormat numbers = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    if (bytes < 1024) {
      return localizations.dataExportBytes(numbers.format(bytes));
    }
    if (bytes < 1024 * 1024) {
      return localizations.dataExportKilobytes(numbers.format(bytes / 1024));
    }
    return localizations.dataExportMegabytes(
      numbers.format(bytes / (1024 * 1024)),
    );
  }

  String _statusLabel(
    AppLocalizations localizations,
    DataExportRequestStatus status,
  ) {
    return switch (status) {
      DataExportRequestStatus.queued => localizations.dataExportStatusQueued,
      DataExportRequestStatus.verifying =>
        localizations.dataExportStatusVerifying,
      DataExportRequestStatus.processing =>
        localizations.dataExportStatusProcessing,
      DataExportRequestStatus.completed =>
        localizations.dataExportStatusCompleted,
      DataExportRequestStatus.failed => localizations.dataExportStatusFailed,
      DataExportRequestStatus.cancelled =>
        localizations.dataExportStatusCancelled,
    };
  }

  IconData _statusIcon(DataExportRequestStatus status) {
    return switch (status) {
      DataExportRequestStatus.queued => Icons.schedule,
      DataExportRequestStatus.verifying => Icons.verified_user_outlined,
      DataExportRequestStatus.processing => Icons.sync,
      DataExportRequestStatus.completed => Icons.download_done_outlined,
      DataExportRequestStatus.failed => Icons.error_outline,
      DataExportRequestStatus.cancelled => Icons.cancel_outlined,
    };
  }
}
