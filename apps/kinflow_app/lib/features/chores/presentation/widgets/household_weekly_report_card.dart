import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

final class HouseholdWeeklyReportCard extends StatelessWidget {
  const HouseholdWeeklyReportCard({
    required this.report,
    required this.onOpen,
    super.key,
  });

  final HouseholdWeeklyReport report;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final String range = localizations.weeklyReportWeekRange(
      material.formatMediumDate(report.weekStart.toDateTime()),
      material.formatMediumDate(report.weekEnd.toDateTime()),
    );
    final String summary = report.isEmpty
        ? localizations.weeklyReportEmpty
        : localizations.weeklyReportCardSummary(
            report.completedByWeekEndCount,
            report.dueCount,
          );

    return Card(
      key: const Key('today.weeklyReport.card'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Semantics(
            button: true,
            label: '${localizations.weeklyReportOpenAction}. $range. $summary',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.insights_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          localizations.weeklyReportTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(range),
                const SizedBox(height: AppSpacing.sm),
                Text(summary, style: Theme.of(context).textTheme.titleMedium),
                if (report.hasDueChores) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  LinearProgressIndicator(
                    key: const Key('today.weeklyReport.progress'),
                    value: report.completedByWeekEndCount / report.dueCount,
                    semanticsLabel: localizations.weeklyReportByWeekEndRate(
                      report.completedByWeekEndPercent!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
