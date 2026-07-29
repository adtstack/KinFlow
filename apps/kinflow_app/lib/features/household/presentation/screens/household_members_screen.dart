import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/application/household_members_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_member.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/presentation/household_member_failure_message.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

enum _MemberAction { promote, demote, transferOwner, remove }

class HouseholdMembersScreen extends ConsumerStatefulWidget {
  const HouseholdMembersScreen({super.key});

  @override
  ConsumerState<HouseholdMembersScreen> createState() =>
      _HouseholdMembersScreenState();
}

class _HouseholdMembersScreenState
    extends ConsumerState<HouseholdMembersScreen> {
  var _loadRequested = false;
  var _leaveHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoster());
  }

  void _loadRoster() {
    if (!mounted || _loadRequested) {
      return;
    }
    final HouseholdId? householdId = ref
        .read(authLifecycleProvider)
        .activeHousehold
        ?.householdId;
    if (householdId == null) {
      context.go(AppRoutes.home);
      return;
    }
    _loadRequested = true;
    unawaited(ref.read(householdMembersProvider.notifier).load(householdId));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final HouseholdMembersState state = ref.watch(householdMembersProvider);
    ref.listen<HouseholdMembersState>(householdMembersProvider, (
      HouseholdMembersState? previous,
      HouseholdMembersState next,
    ) {
      if (next is HouseholdMembersLeft &&
          previous is! HouseholdMembersLeft &&
          !_leaveHandled) {
        _leaveHandled = true;
        unawaited(_finishLeaving());
      }
    });

    return AppResponsiveScaffold(
      key: const Key('members.screen'),
      title: localizations.membersTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('members.close'),
          onPressed: () => context.go(AppRoutes.today),
          tooltip: localizations.goHomeAction,
          icon: const Icon(Icons.close),
        ),
      ],
      body: _body(localizations, state),
    );
  }

  Widget _body(AppLocalizations localizations, HouseholdMembersState state) {
    return switch (state) {
      HouseholdMembersInitial() ||
      HouseholdMembersLoading() ||
      HouseholdMembersLeft() => ScrollableStatusLayout(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              state is HouseholdMembersLeft
                  ? localizations.memberActionInProgress
                  : localizations.membersLoadingLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      HouseholdMembersLoadFailed() => ScrollableStatusLayout(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.group_off_outlined, size: AppIconSize.status),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.membersLoadError,
              key: const Key('members.loadError'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              key: const Key('members.retry'),
              onPressed: () {
                _loadRequested = false;
                _loadRoster();
              },
              icon: const Icon(Icons.refresh),
              label: Text(localizations.retryAction),
            ),
          ],
        ),
      ),
      HouseholdMembersReady(:final roster) => _roster(
        localizations,
        state,
        roster,
      ),
    };
  }

  Widget _roster(
    AppLocalizations localizations,
    HouseholdMembersReady state,
    HouseholdMemberRoster roster,
  ) {
    final HouseholdMember currentMember = roster.currentMember;
    return ScrollableStatusLayout(
      maxWidth: AppLayoutTokens.pageContentMaxWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              localizations.membersHeading(roster.householdName),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(localizations.membersBody),
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
                        householdMemberFailureMessage(
                          localizations,
                          state.failure!,
                        ),
                        key: const Key('members.actionError'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextButton.icon(
                        key: const Key('members.errorReload'),
                        onPressed: state.isSubmitting
                            ? null
                            : () => unawaited(
                                ref
                                    .read(householdMembersProvider.notifier)
                                    .load(roster.householdId),
                              ),
                        icon: const Icon(Icons.refresh),
                        label: Text(localizations.retryAction),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (state.isSubmitting) ...<Widget>[
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
                  Flexible(child: Text(localizations.memberActionInProgress)),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          ...roster.members.map(
            (HouseholdMember member) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _memberCard(
                localizations,
                currentMember,
                member,
                state.isSubmitting,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (currentMember.role == HouseholdMemberRole.owner)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  localizations.ownerMustTransferBody,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            OutlinedButton.icon(
              key: const Key('members.leave'),
              onPressed: state.isSubmitting
                  ? null
                  : () => unawaited(_confirmLeave(localizations)),
              icon: const Icon(Icons.exit_to_app),
              label: Text(localizations.householdLeaveAction),
            ),
        ],
      ),
    );
  }

  Widget _memberCard(
    AppLocalizations localizations,
    HouseholdMember currentMember,
    HouseholdMember member,
    bool isSubmitting,
  ) {
    final List<_MemberAction> actions = _actionsFor(currentMember, member);
    return Card(
      key: Key('members.member.${member.id.value}'),
      child: ListTile(
        leading: CircleAvatar(child: Text(_initial(member.displayName))),
        title: Text(member.displayName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              Chip(label: Text(_roleLabel(localizations, member.role))),
              if (member.isCurrentUser)
                Chip(label: Text(localizations.membersYouLabel)),
            ],
          ),
        ),
        trailing: actions.isEmpty
            ? null
            : PopupMenuButton<_MemberAction>(
                key: Key('members.menu.${member.id.value}'),
                enabled: !isSubmitting,
                tooltip: localizations.membersMenuTooltip(member.displayName),
                onSelected: (_MemberAction action) => unawaited(
                  _confirmMemberAction(localizations, member, action),
                ),
                itemBuilder: (BuildContext context) => actions
                    .map(
                      (_MemberAction action) => PopupMenuItem<_MemberAction>(
                        value: action,
                        child: Text(_actionLabel(localizations, action)),
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
  }

  List<_MemberAction> _actionsFor(
    HouseholdMember actor,
    HouseholdMember target,
  ) {
    if (actor.id == target.id || target.role == HouseholdMemberRole.owner) {
      return const <_MemberAction>[];
    }
    if (actor.role == HouseholdMemberRole.owner) {
      return <_MemberAction>[
        if (target.role == HouseholdMemberRole.member)
          _MemberAction.promote
        else
          _MemberAction.demote,
        _MemberAction.transferOwner,
        _MemberAction.remove,
      ];
    }
    if (actor.role == HouseholdMemberRole.admin &&
        target.role == HouseholdMemberRole.member) {
      return const <_MemberAction>[_MemberAction.promote, _MemberAction.remove];
    }
    return const <_MemberAction>[];
  }

  Future<void> _confirmMemberAction(
    AppLocalizations localizations,
    HouseholdMember member,
    _MemberAction action,
  ) async {
    final String title;
    final String body;
    switch (action) {
      case _MemberAction.promote:
        title = localizations.memberRoleChangeTitle;
        body = localizations.memberRoleChangeBody(
          member.displayName,
          localizations.membersRoleAdmin,
        );
      case _MemberAction.demote:
        title = localizations.memberRoleChangeTitle;
        body = localizations.memberRoleChangeBody(
          member.displayName,
          localizations.membersRoleMember,
        );
      case _MemberAction.transferOwner:
        title = localizations.ownerTransferTitle;
        body = localizations.ownerTransferBody(member.displayName);
      case _MemberAction.remove:
        title = localizations.memberRemoveTitle;
        body = localizations.memberRemoveBody(member.displayName);
    }
    final bool confirmed = await _confirmDialog(
      title: title,
      body: body,
      destructive: action == _MemberAction.remove,
    );
    if (!confirmed || !mounted) {
      return;
    }
    final HouseholdMembersNotifier notifier = ref.read(
      householdMembersProvider.notifier,
    );
    switch (action) {
      case _MemberAction.promote:
        await notifier.changeRole(member, HouseholdMemberRole.admin);
      case _MemberAction.demote:
        await notifier.changeRole(member, HouseholdMemberRole.member);
      case _MemberAction.transferOwner:
        await notifier.transferOwner(member);
      case _MemberAction.remove:
        await notifier.removeMember(member);
    }
  }

  Future<void> _confirmLeave(AppLocalizations localizations) async {
    final bool confirmed = await _confirmDialog(
      title: localizations.householdLeaveTitle,
      body: localizations.householdLeaveBody,
      destructive: true,
    );
    if (confirmed && mounted) {
      await ref.read(householdMembersProvider.notifier).leaveHousehold();
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String body,
    required bool destructive,
  }) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(localizations.memberCancelAction),
              ),
              FilledButton(
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      )
                    : null,
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(localizations.memberConfirmAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _finishLeaving() async {
    await ref.read(authLifecycleProvider.notifier).refresh();
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  String _initial(String displayName) {
    final String trimmed = displayName.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }

  String _roleLabel(AppLocalizations localizations, HouseholdMemberRole role) {
    return switch (role) {
      HouseholdMemberRole.owner => localizations.membersRoleOwner,
      HouseholdMemberRole.admin => localizations.membersRoleAdmin,
      HouseholdMemberRole.member => localizations.membersRoleMember,
    };
  }

  String _actionLabel(AppLocalizations localizations, _MemberAction action) {
    return switch (action) {
      _MemberAction.promote => localizations.memberPromoteAdminAction,
      _MemberAction.demote => localizations.memberDemoteMemberAction,
      _MemberAction.transferOwner => localizations.memberTransferOwnerAction,
      _MemberAction.remove => localizations.memberRemoveAction,
    };
  }
}
