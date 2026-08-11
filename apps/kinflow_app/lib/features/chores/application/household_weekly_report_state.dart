import 'package:kinflow_app/features/chores/domain/entities/household_weekly_report.dart';
import 'package:kinflow_app/features/chores/domain/failures/chore_failure.dart';

sealed class HouseholdWeeklyReportState {
  const HouseholdWeeklyReportState();
}

final class HouseholdWeeklyReportInitial extends HouseholdWeeklyReportState {
  const HouseholdWeeklyReportInitial();
}

final class HouseholdWeeklyReportLoading extends HouseholdWeeklyReportState {
  const HouseholdWeeklyReportLoading(this.request);

  final HouseholdWeeklyReportRequest request;
}

final class HouseholdWeeklyReportReady extends HouseholdWeeklyReportState {
  const HouseholdWeeklyReportReady({
    required this.report,
    this.refreshing = false,
  });

  final HouseholdWeeklyReport report;
  final bool refreshing;
}

final class HouseholdWeeklyReportFailed extends HouseholdWeeklyReportState {
  const HouseholdWeeklyReportFailed({
    required this.request,
    required this.failure,
  });

  final HouseholdWeeklyReportRequest request;
  final ChoreFailure failure;
}
