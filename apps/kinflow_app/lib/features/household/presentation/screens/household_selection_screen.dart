import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/app_modal_route.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/household/application/household_selection_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/entities/household_selection.dart';
import 'package:kinflow_app/features/household/presentation/household_selection_failure_message.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_selection_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class HouseholdSelectionScreen extends ConsumerStatefulWidget {
  const HouseholdSelectionScreen({super.key});

  @override
  ConsumerState<HouseholdSelectionScreen> createState() =>
      _HouseholdSelectionScreenState();
}

final class _HouseholdSelectionScreenState
    extends ConsumerState<HouseholdSelectionScreen> {
  var _loadRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (!mounted || _loadRequested) {
      return;
    }
    _loadRequested = true;
    unawaited(ref.read(householdSelectionProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final HouseholdSelectionState state = ref.watch(householdSelectionProvider);
    return AppResponsiveScaffold(
      key: const Key('householdSelection.screen'),
      title: localizations.householdSwitchTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('householdSelection.close'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.close),
        ),
      ],
      body: switch (state) {
        HouseholdSelectionInitial() ||
        HouseholdSelectionLoading() => ScrollableStatusLayout(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                localizations.householdSwitchLoading,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        HouseholdSelectionLoadFailed() => _loadFailure(localizations),
        HouseholdSelectionReady() => _ready(localizations, state),
      },
    );
  }

  Widget _loadFailure(AppLocalizations localizations) {
    return ScrollableStatusLayout(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.home_work_outlined, size: AppIconSize.status),
          const SizedBox(height: AppSpacing.md),
          Text(
            localizations.householdSwitchLoadError,
            key: const Key('householdSelection.loadError'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('householdSelection.retry'),
            onPressed: () {
              _loadRequested = false;
              _load();
            },
            icon: const Icon(Icons.refresh),
            label: Text(localizations.retryAction),
          ),
        ],
      ),
    );
  }

  Widget _ready(AppLocalizations localizations, HouseholdSelectionReady state) {
    return ListView(
      key: const Key('householdSelection.list'),
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
                Text(localizations.householdSwitchIntro),
                if (state.failure != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    liveRegion: true,
                    child: Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          children: <Widget>[
                            Text(
                              householdSelectionFailureMessage(
                                localizations,
                                state.failure!,
                              ),
                              key: const Key('householdSelection.actionError'),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            TextButton.icon(
                              key: const Key('householdSelection.errorRefresh'),
                              onPressed: state.isSwitching
                                  ? null
                                  : () {
                                      _loadRequested = false;
                                      _load();
                                    },
                              icon: const Icon(Icons.refresh),
                              label: Text(localizations.retryAction),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (state.isSwitching) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Semantics(
                    liveRegion: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const SizedBox.square(
                          dimension: AppSpacing.md,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(localizations.householdSwitchInProgress),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                if (state.snapshot.households.isEmpty)
                  Card(
                    key: const Key('householdSelection.empty'),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        localizations.householdSwitchEmpty,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...state.snapshot.households.map(
                    (HouseholdSelection household) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _householdTile(
                        localizations,
                        household,
                        state.isSwitching,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _householdTile(
    AppLocalizations localizations,
    HouseholdSelection household,
    bool isSwitching,
  ) {
    final String role = switch (household.memberRole) {
      HouseholdMemberRole.owner => localizations.householdSwitchRoleOwner,
      HouseholdMemberRole.admin => localizations.householdSwitchRoleAdmin,
      HouseholdMemberRole.member => localizations.householdSwitchRoleMember,
    };
    return Card(
      key: Key('householdSelection.household.${household.householdId.value}'),
      child: ListTile(
        enabled: !household.isActive && !isSwitching,
        leading: Icon(household.isActive ? Icons.home : Icons.home_outlined),
        title: Text(household.householdName),
        subtitle: household.isActive
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(role),
                  Text(localizations.householdSwitchCurrentLabel),
                ],
              )
            : Text(role),
        trailing: Icon(
          household.isActive ? Icons.check_circle : Icons.chevron_right,
        ),
        onTap: household.isActive || isSwitching
            ? null
            : () => unawaited(_confirmSwitch(localizations, household)),
      ),
    );
  }

  Future<void> _confirmSwitch(
    AppLocalizations localizations,
    HouseholdSelection target,
  ) async {
    final bool? confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(localizations.householdSwitchConfirmTitle),
        content: Text(
          localizations.householdSwitchConfirmBody(target.householdName),
        ),
        actions: <Widget>[
          TextButton(
            key: const Key('householdSelection.confirmCancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            key: const Key('householdSelection.confirmSwitch'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.householdSwitchConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final bool switched = await ref
        .read(householdSelectionProvider.notifier)
        .switchActiveHousehold(target.householdId);
    if (switched && mounted) {
      context.go(AppRoutes.today);
    }
  }
}
