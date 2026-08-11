import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/settings/application/diagnostic_report_state.dart';
import 'package:kinflow_app/features/settings/domain/entities/diagnostic_report.dart';
import 'package:kinflow_app/features/settings/domain/failures/diagnostic_report_failure.dart';
import 'package:kinflow_app/features/settings/presentation/providers/diagnostic_report_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class DiagnosticReportScreen extends ConsumerStatefulWidget {
  const DiagnosticReportScreen({super.key});

  @override
  ConsumerState<DiagnosticReportScreen> createState() =>
      _DiagnosticReportScreenState();
}

class _DiagnosticReportScreenState
    extends ConsumerState<DiagnosticReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool hasContent =
          ref.read(diagnosticReportProvider) is DiagnosticReportReady;
      unawaited(
        ref
            .read(diagnosticReportProvider.notifier)
            .load(preserveContent: hasContent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final DiagnosticReportState state = ref.watch(diagnosticReportProvider);
    final bool busy = state is DiagnosticReportReady && state.busy;
    return AppResponsiveScaffold(
      key: const Key('diagnostics.screen'),
      title: localizations.diagnosticsTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('diagnostics.refreshIcon'),
          onPressed: busy || state is! DiagnosticReportReady
              ? null
              : () => unawaited(
                  ref
                      .read(diagnosticReportProvider.notifier)
                      .load(preserveContent: true),
                ),
          tooltip: localizations.diagnosticsNewIncidentAction,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          key: const Key('diagnostics.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: switch (state) {
        DiagnosticReportInitial() ||
        DiagnosticReportLoading() => _loading(localizations),
        DiagnosticReportLoadFailed(:final failure) => _loadFailed(
          localizations,
          failure,
        ),
        DiagnosticReportReady() => _ready(localizations, state),
      },
    );
  }

  Widget _loading(AppLocalizations localizations) {
    return ScrollableStatusLayout(
      child: Column(
        key: const Key('diagnostics.loading'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(localizations.diagnosticsLoading, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _loadFailed(
    AppLocalizations localizations,
    DiagnosticReportFailure failure,
  ) {
    final String message = switch (failure.kind) {
      DiagnosticReportFailureKind.unavailable =>
        localizations.diagnosticsUnavailable,
      DiagnosticReportFailureKind.invalidMetadata =>
        localizations.diagnosticsInvalidMetadata,
      DiagnosticReportFailureKind.clipboardUnavailable ||
      DiagnosticReportFailureKind.internal => localizations.diagnosticsInternal,
    };
    return ScrollableStatusLayout(
      child: Column(
        key: const Key('diagnostics.error'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.info_outline, size: AppIconSize.status),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('diagnostics.retry'),
            onPressed: () =>
                unawaited(ref.read(diagnosticReportProvider.notifier).load()),
            icon: const Icon(Icons.refresh),
            label: Text(localizations.retryAction),
          ),
        ],
      ),
    );
  }

  Widget _ready(AppLocalizations localizations, DiagnosticReportReady state) {
    return ListView(
      key: const Key('diagnostics.content'),
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
                _introCard(localizations),
                const SizedBox(height: AppSpacing.md),
                _privacyCard(localizations),
                if (state.isRefreshing || state.isCopying) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(),
                  const SizedBox(height: AppSpacing.sm),
                  _statusCard(
                    key: state.isRefreshing
                        ? const Key('diagnostics.status.refreshing')
                        : const Key('diagnostics.status.copying'),
                    message: state.isRefreshing
                        ? localizations.diagnosticsRefreshing
                        : localizations.diagnosticsCopying,
                  ),
                ] else if (state.notice != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _noticeCard(localizations, state.notice!),
                ],
                const SizedBox(height: AppSpacing.md),
                _reportCard(localizations, state.report),
                const SizedBox(height: AppSpacing.md),
                _clipboardCard(localizations, state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _introCard(AppLocalizations localizations) {
    return Card(
      key: const Key('diagnostics.intro'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.diagnosticsIntroHeading,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.diagnosticsIntroBody),
          ],
        ),
      ),
    );
  }

  Widget _privacyCard(AppLocalizations localizations) {
    return Card(
      key: const Key('diagnostics.privacy'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.diagnosticsIncludedTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.diagnosticsIncludedBody),
            const Divider(height: AppSpacing.xl),
            Text(
              localizations.diagnosticsExcludedTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.diagnosticsExcludedBody),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(AppLocalizations localizations, DiagnosticReport report) {
    return Card(
      key: const Key('diagnostics.report'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.diagnosticsReportTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            _field(
              key: const Key('diagnostics.applicationId'),
              label: localizations.diagnosticsApplicationIdLabel,
              value: report.appBuild.applicationId,
            ),
            _field(
              key: const Key('diagnostics.appVersion'),
              label: localizations.diagnosticsAppVersionLabel,
              value: report.appBuild.version,
            ),
            _field(
              key: const Key('diagnostics.buildNumber'),
              label: localizations.diagnosticsBuildNumberLabel,
              value: report.appBuild.buildNumber,
            ),
            _field(
              key: const Key('diagnostics.environment'),
              label: localizations.diagnosticsEnvironmentLabel,
              value: report.environment.wireValue,
            ),
            _field(
              key: const Key('diagnostics.contractVersion'),
              label: localizations.diagnosticsContractVersionLabel,
              value: report.contractVersion,
            ),
            _field(
              key: const Key('diagnostics.devicePlatform'),
              label: localizations.diagnosticsDevicePlatformLabel,
              value: report.devicePlatform.wireValue,
            ),
            _field(
              key: const Key('diagnostics.incidentId'),
              label: localizations.diagnosticsIncidentIdLabel,
              value: report.incidentId.value,
            ),
            _field(
              key: const Key('diagnostics.generatedAt'),
              label: localizations.diagnosticsGeneratedAtLabel,
              value: report.generatedAt.toIso8601String(),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xxs),
          SelectableText(value),
        ],
      ),
    );
  }

  Widget _clipboardCard(
    AppLocalizations localizations,
    DiagnosticReportReady state,
  ) {
    return Card(
      key: const Key('diagnostics.clipboard'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(localizations.diagnosticsClipboardNotice),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const Key('diagnostics.copy'),
              style: FilledButton.styleFrom(
                minimumSize: AppTouchTarget.minimumSize,
              ),
              onPressed: state.busy
                  ? null
                  : () => unawaited(
                      ref.read(diagnosticReportProvider.notifier).copy(),
                    ),
              child: _buttonContent(
                state.isCopying ? Icons.hourglass_top : Icons.copy_outlined,
                localizations.diagnosticsCopyAction,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              key: const Key('diagnostics.newIncident'),
              style: OutlinedButton.styleFrom(
                minimumSize: AppTouchTarget.minimumSize,
              ),
              onPressed: state.busy
                  ? null
                  : () => unawaited(
                      ref
                          .read(diagnosticReportProvider.notifier)
                          .load(preserveContent: true),
                    ),
              child: _buttonContent(
                Icons.refresh,
                localizations.diagnosticsNewIncidentAction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttonContent(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon),
          const SizedBox(width: AppSpacing.sm),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _noticeCard(
    AppLocalizations localizations,
    DiagnosticReportNotice notice,
  ) {
    final (Key key, String message) = switch (notice) {
      DiagnosticReportNotice.copied => (
        const Key('diagnostics.status.copied'),
        localizations.diagnosticsCopied,
      ),
      DiagnosticReportNotice.copyFailed => (
        const Key('diagnostics.status.copyFailed'),
        localizations.diagnosticsCopyFailed,
      ),
      DiagnosticReportNotice.refreshFailed => (
        const Key('diagnostics.status.refreshFailed'),
        localizations.diagnosticsRefreshFailed,
      ),
    };
    return _statusCard(key: key, message: message);
  }

  Widget _statusCard({required Key key, required String message}) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Semantics(liveRegion: true, child: Text(message)),
      ),
    );
  }
}
