import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/chores/application/household_weekly_report_controller.dart';
import 'package:kinflow_app/features/chores/application/household_weekly_report_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/repositories/chore_repository.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

final class HouseholdWeeklyReportSheet extends StatefulWidget {
  const HouseholdWeeklyReportSheet({
    required this.repository,
    required this.householdId,
    this.initialReport,
    super.key,
  });

  final ChoreRepository repository;
  final HouseholdId householdId;
  final HouseholdWeeklyReport? initialReport;

  @override
  State<HouseholdWeeklyReportSheet> createState() =>
      _HouseholdWeeklyReportSheetState();
}

final class _HouseholdWeeklyReportSheetState
    extends State<HouseholdWeeklyReportSheet> {
  late final HouseholdWeeklyReportController _controller;
  late final StreamSubscription<HouseholdWeeklyReportState> _subscription;
  late HouseholdWeeklyReportState _state;

  @override
  void initState() {
    super.initState();
    final HouseholdWeeklyReport? initialReport =
        widget.initialReport?.householdId == widget.householdId
        ? widget.initialReport
        : null;
    _controller = HouseholdWeeklyReportController(
      repository: widget.repository,
      initialReport: initialReport,
    );
    _state = _controller.state;
    _subscription = _controller.states.listen((
      HouseholdWeeklyReportState next,
    ) {
      if (mounted) {
        setState(() => _state = next);
      }
    });
    if (initialReport == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _load(HouseholdWeeklyReportRequest.latestWeekOffset);
        }
      });
    }
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _load(int weekOffset, {bool preserveContent = false}) {
    final HouseholdWeeklyReportRequest? request =
        HouseholdWeeklyReportRequest.tryCreate(
          householdId: widget.householdId,
          weekOffset: weekOffset,
        );
    if (request != null) {
      unawaited(_controller.load(request, preserveContent: preserveContent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final double height = (MediaQuery.sizeOf(context).height * 0.9)
        .clamp(0, 760)
        .toDouble();
    return SafeArea(
      top: false,
      child: SizedBox(
        key: const Key('weeklyReport.sheet'),
        height: height,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        localizations.weeklyReportTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('weeklyReport.close'),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _content(localizations)),
          ],
        ),
      ),
    );
  }

  Widget _content(AppLocalizations localizations) {
    return switch (_state) {
      HouseholdWeeklyReportInitial() ||
      HouseholdWeeklyReportLoading() => Center(
        key: const Key('weeklyReport.loading'),
        child: Semantics(
          liveRegion: true,
          label: localizations.weeklyReportLoading,
          child: const CircularProgressIndicator(),
        ),
      ),
      HouseholdWeeklyReportFailed(:final request) => Center(
        key: const Key('weeklyReport.error'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.insights_outlined, size: AppIconSize.status),
              const SizedBox(height: AppSpacing.md),
              Semantics(
                header: true,
                child: Text(
                  localizations.weeklyReportUnavailableTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  localizations.weeklyReportUnavailableBody,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                key: const Key('weeklyReport.retry'),
                onPressed: () => _load(request.weekOffset),
                icon: const Icon(Icons.refresh),
                label: Text(localizations.retryAction),
              ),
            ],
          ),
        ),
      ),
      HouseholdWeeklyReportReady(:final report, :final refreshing) => _ready(
        localizations,
        report,
        refreshing: refreshing,
      ),
    };
  }

  Widget _ready(
    AppLocalizations localizations,
    HouseholdWeeklyReport report, {
    required bool refreshing,
  }) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String range = localizations.weeklyReportWeekRange(
      material.formatMediumDate(report.weekStart.toDateTime()),
      material.formatMediumDate(report.weekEnd.toDateTime()),
    );
    return ListView(
      key: const Key('weeklyReport.scroll'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              key: const Key('weeklyReport.newer'),
              onPressed: report.canLoadNewer
                  ? () => _load(report.weekOffset - 1)
                  : null,
              tooltip: localizations.weeklyReportNewerWeek,
              icon: const Icon(Icons.navigate_before),
            ),
            Expanded(
              child: Column(
                children: <Widget>[
                  Text(
                    report.weekOffset == 0
                        ? localizations.weeklyReportLatestWeek
                        : range,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (report.weekOffset == 0)
                    Text(range, textAlign: TextAlign.center),
                ],
              ),
            ),
            IconButton(
              key: const Key('weeklyReport.older'),
              onPressed: report.canLoadOlder
                  ? () => _load(report.weekOffset + 1)
                  : null,
              tooltip: localizations.weeklyReportOlderWeek,
              icon: const Icon(Icons.navigate_next),
            ),
          ],
        ),
        if (refreshing) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            label: localizations.weeklyReportRefreshing,
            child: const LinearProgressIndicator(),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (report.isEmpty)
          Text(
            localizations.weeklyReportEmpty,
            key: const Key('weeklyReport.empty'),
            textAlign: TextAlign.center,
          )
        else ...<Widget>[
          Text(
            localizations.weeklyReportSummary(
              report.completedCount,
              report.dueCount,
            ),
            key: const Key('weeklyReport.summary'),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (report.hasDueChores) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            LinearProgressIndicator(
              value: report.completedByWeekEndCount / report.dueCount,
              semanticsLabel: localizations.weeklyReportByWeekEndRate(
                report.completedByWeekEndPercent!,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _metric(
            icon: Icons.check_circle_outline,
            label: localizations.weeklyReportCompletedByWeekEnd(
              report.completedByWeekEndCount,
            ),
          ),
          _metric(
            icon: Icons.update,
            label: localizations.weeklyReportCompletedLater(
              report.completedAfterWeekEndCount,
            ),
          ),
          _metric(
            icon: Icons.pending_actions_outlined,
            label: localizations.weeklyReportStillOpen(report.openCount),
          ),
          _metric(
            icon: Icons.skip_next_outlined,
            label: localizations.weeklyReportSkipped(report.skippedCount),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: Text(
            localizations.weeklyReportBreakdownTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          localizations.weeklyReportYourContribution(
            report.viewerCompletedCount,
          ),
          key: const Key('weeklyReport.viewerContribution'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...report.members.map(
          (HouseholdWeeklyReportMember member) => ListTile(
            key: Key('weeklyReport.member.${member.memberId.value}'),
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              member.isViewer ? Icons.person : Icons.person_outline,
            ),
            title: Text(
              localizations.weeklyReportMemberContribution(
                member.displayName,
                member.completedCount,
              ),
            ),
            subtitle: Text(
              localizations.weeklyReportMemberByWeekEnd(
                member.completedByWeekEndCount,
              ),
            ),
          ),
        ),
        if (report.otherMemberCompletedCount > 0)
          ListTile(
            key: const Key('weeklyReport.otherContribution'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.more_horiz),
            title: Text(
              localizations.weeklyReportOtherContribution(
                report.otherMemberCompletedCount,
              ),
            ),
          ),
        if (report.memberBreakdownTruncated) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.weeklyReportTruncatedNotice,
            key: const Key('weeklyReport.truncated'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _metric({required IconData icon, required String label}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      dense: true,
    );
  }
}
