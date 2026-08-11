import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/chores/application/household_activation_progress_state.dart';
import 'package:kinflow_app/features/chores/domain/entities/household_activation_progress.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

final class HouseholdActivationProgressCard extends StatelessWidget {
  const HouseholdActivationProgressCard({
    required this.state,
    required this.expectedHouseholdId,
    required this.readOnly,
    required this.onInvite,
    required this.onCreateChore,
    required this.onRetry,
    super.key,
  });

  final HouseholdActivationProgressState state;
  final HouseholdId expectedHouseholdId;
  final bool readOnly;
  final VoidCallback onInvite;
  final VoidCallback onCreateChore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Card(
      key: const Key('today.activation.card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: switch (state) {
          HouseholdActivationProgressReady(:final progress)
              when progress.householdId == expectedHouseholdId =>
            _ready(context, localizations, progress),
          HouseholdActivationProgressFailed(:final householdId)
              when householdId == expectedHouseholdId =>
            _failed(context, localizations),
          _ => _loading(context, localizations),
        },
      ),
    );
  }

  Widget _loading(BuildContext context, AppLocalizations localizations) {
    return Column(
      key: const Key('today.activation.loading'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(context, localizations),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          label: localizations.householdActivationLoadingLabel,
          child: const LinearProgressIndicator(),
        ),
      ],
    );
  }

  Widget _failed(BuildContext context, AppLocalizations localizations) {
    return Column(
      key: const Key('today.activation.failed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(context, localizations),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          child: Text(localizations.householdActivationUnavailableBody),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('today.activation.retry'),
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(localizations.retryAction),
        ),
      ],
    );
  }

  Widget _ready(
    BuildContext context,
    AppLocalizations localizations,
    HouseholdActivationProgress progress,
  ) {
    final bool hasDisabledAction =
        readOnly &&
        (!progress.adultParticipantReached || !progress.choreCreationReached);
    return Column(
      key: const Key('today.activation.ready'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _heading(context, localizations),
        const SizedBox(height: AppSpacing.xs),
        Text(
          progress.isComplete
              ? localizations.householdActivationCompleteBody
              : localizations.householdActivationBody,
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          liveRegion: true,
          label: localizations.householdActivationSummary(
            progress.completedMilestoneCount,
            HouseholdActivationProgress.milestoneCount,
          ),
          child: LinearProgressIndicator(
            key: const Key('today.activation.progress'),
            value:
                progress.completedMilestoneCount /
                HouseholdActivationProgress.milestoneCount,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ActivationStep(
          key: const Key('today.activation.adult'),
          complete: progress.adultParticipantReached,
          title: localizations.householdActivationAdultTitle,
          status: localizations.householdActivationAdultProgress(
            progress.adultParticipantProgress,
            HouseholdActivationProgress.adultParticipantGoal,
          ),
          actionLabel: progress.adultParticipantReached
              ? null
              : localizations.householdActivationInviteAction,
          actionKey: const Key('today.activation.invite'),
          actionIcon: Icons.person_add_alt_1,
          onAction: progress.adultParticipantReached || readOnly
              ? null
              : onInvite,
        ),
        _ActivationStep(
          key: const Key('today.activation.chores'),
          complete: progress.choreCreationReached,
          title: localizations.householdActivationChoreTitle,
          status: localizations.householdActivationChoreProgress(
            progress.choreCreationProgress,
            HouseholdActivationProgress.choreCreationGoal,
          ),
          actionLabel: progress.choreCreationReached
              ? null
              : localizations.householdActivationCreateAction,
          actionKey: const Key('today.activation.create'),
          actionIcon: Icons.add_task,
          onAction: progress.choreCreationReached || readOnly
              ? null
              : onCreateChore,
        ),
        _ActivationStep(
          key: const Key('today.activation.completers'),
          complete: progress.distinctAdultCompleterReached,
          title: localizations.householdActivationCompletionTitle,
          status: localizations.householdActivationCompletionProgress(
            progress.distinctAdultCompleterProgress,
            HouseholdActivationProgress.distinctAdultCompleterGoal,
          ),
        ),
        _ActivationStep(
          key: const Key('today.activation.return'),
          complete: progress.returnAfterFirstDayReached,
          title: localizations.householdActivationReturnTitle,
          status: progress.returnAfterFirstDayReached
              ? localizations.householdActivationReturnComplete
              : localizations.householdActivationReturnPending,
          showDivider: false,
        ),
        if (hasDisabledAction) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.householdActivationReadOnlyBody,
            key: const Key('today.activation.readOnly'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (state case HouseholdActivationProgressReady(
          refreshing: true,
        )) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Semantics(
            liveRegion: true,
            label: localizations.householdActivationLoadingLabel,
            child: const LinearProgressIndicator(
              key: Key('today.activation.refreshing'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _heading(BuildContext context, AppLocalizations localizations) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            Icons.family_restroom,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              localizations.householdActivationTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
      ],
    );
  }
}

final class _ActivationStep extends StatelessWidget {
  const _ActivationStep({
    required this.complete,
    required this.title,
    required this.status,
    this.actionLabel,
    this.actionKey,
    this.actionIcon,
    this.onAction,
    this.showDivider = true,
    super.key,
  });

  final bool complete;
  final String title;
  final String status;
  final String? actionLabel;
  final Key? actionKey;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Semantics(
      container: true,
      label:
          '$title. $status. '
          '${complete ? localizations.householdActivationStepComplete : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ExcludeSemantics(
                  child: Icon(
                    complete
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: complete
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(status),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null) ...<Widget>[
            OutlinedButton.icon(
              key: actionKey,
              onPressed: onAction,
              icon: Icon(actionIcon),
              label: Text(actionLabel!),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (showDivider) const Divider(height: 1),
        ],
      ),
    );
  }
}
