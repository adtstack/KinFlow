import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/application/invite_flow_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/presentation/invite_failure_message.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class HouseholdInviteScreen extends ConsumerStatefulWidget {
  const HouseholdInviteScreen({super.key});

  @override
  ConsumerState<HouseholdInviteScreen> createState() =>
      _HouseholdInviteScreenState();
}

class _HouseholdInviteScreenState extends ConsumerState<HouseholdInviteScreen> {
  var _started = false;
  var _switchConfirmed = false;
  var _completingAcceptance = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    scheduleMicrotask(
      () => ref.read(inviteFlowProvider.notifier).loadPreview(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final InviteFlowState inviteState = ref.watch(inviteFlowProvider);
    final AuthLifecycleState authState = ref.watch(authLifecycleProvider);

    ref.listen<InviteFlowState>(inviteFlowProvider, (
      InviteFlowState? previous,
      InviteFlowState next,
    ) {
      if (next is InviteFlowAccepted && !_completingAcceptance) {
        _completingAcceptance = true;
        unawaited(_completeAcceptance(next.acceptance));
      }
    });
    ref.listen<AuthLifecycleState>(authLifecycleProvider, (
      AuthLifecycleState? previous,
      AuthLifecycleState next,
    ) {
      final previousUser = previous?.session?.userId;
      final nextUser = next.session?.userId;
      if (previousUser != null && previousUser != nextUser) {
        _switchConfirmed = false;
        ref.read(inviteFlowProvider.notifier).clear();
      }
    });

    return Scaffold(
      key: const Key('invite.open.screen'),
      appBar: AppBar(
        title: Semantics(
          header: true,
          child: Text(localizations.inviteOpenTitle),
        ),
      ),
      body: SafeArea(
        child: ScrollableStatusLayout(
          maxWidth: AppLayoutTokens.dialogContentMaxWidth,
          child: _content(context, localizations, inviteState, authState),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations localizations,
    InviteFlowState inviteState,
    AuthLifecycleState authState,
  ) {
    if (inviteState is InviteFlowIdle ||
        inviteState is InviteFlowLoading ||
        authState is AuthBootstrapping) {
      return _LoadingInvite(localizations: localizations);
    }
    if (inviteState is InviteFlowMissing) {
      return _MissingInvite(localizations: localizations);
    }
    if (inviteState is InviteFlowAccepted) {
      return Semantics(
        liveRegion: true,
        child: Text(
          localizations.inviteAcceptedBody,
          key: const Key('invite.accepted'),
          textAlign: TextAlign.center,
        ),
      );
    }

    final HouseholdInvitePreview? preview = switch (inviteState) {
      InviteFlowPreviewReady(:final preview) => preview,
      InviteFlowAccepting(:final preview) => preview,
      InviteFlowFailed(:final preview) => preview,
      _ => null,
    };
    final InviteFailure? failure = switch (inviteState) {
      InviteFlowFailed(:final failure) => failure,
      _ => null,
    };
    if (preview == null) {
      return _PreviewFailure(failure: failure, localizations: localizations);
    }

    final bool isAccepting = inviteState is InviteFlowAccepting;
    final bool isAuthenticated =
        authState.session != null && authState.permitsProtectedRoutes;
    final bool hasActiveHousehold = authState.activeHousehold != null;
    final bool terminalFailure = failure != null && _isTerminal(failure);
    final bool canAccept =
        isAuthenticated &&
        !isAccepting &&
        !terminalFailure &&
        (!hasActiveHousehold || _switchConfirmed);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExcludeSemantics(
          child: Icon(
            Icons.mark_email_read_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: AppIconSize.status,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          localizations.invitePreviewSentence(
            preview.inviterDisplayName,
            preview.householdDisplayName,
          ),
          key: const Key('invite.preview.summary'),
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _roleLabel(localizations, preview.role),
          key: const Key('invite.preview.role'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          localizations.inviteExpiryLabel(
            _expiryLabel(context, preview.expiresAt),
          ),
          key: const Key('invite.preview.expiry'),
          textAlign: TextAlign.center,
        ),
        if (failure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              inviteFailureMessage(localizations, failure),
              key: const Key('invite.accept.error'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (!isAuthenticated) ...<Widget>[
          Text(localizations.inviteSignInBody, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('invite.signIn'),
            onPressed: () => context.go('${AppRoutes.signIn}?continue=invite'),
            icon: const Icon(Icons.login),
            label: Text(localizations.inviteSignInAction),
          ),
        ] else ...<Widget>[
          if (hasActiveHousehold) ...<Widget>[
            Text(
              localizations.inviteSwitchTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.inviteSwitchBody, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              key: const Key('invite.switch.confirm'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _switchConfirmed,
              onChanged: isAccepting || terminalFailure
                  ? null
                  : (bool? value) {
                      setState(() => _switchConfirmed = value ?? false);
                    },
              title: Text(localizations.inviteSwitchConfirmation),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          FilledButton.icon(
            key: const Key('invite.accept'),
            onPressed: canAccept
                ? () => unawaited(
                    ref
                        .read(inviteFlowProvider.notifier)
                        .accept(setActiveHousehold: true),
                  )
                : null,
            icon: isAccepting
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.group_add),
            label: Text(
              isAccepting
                  ? localizations.inviteAcceptingAction
                  : localizations.inviteAcceptAction,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _completeAcceptance(AcceptedHouseholdInvite acceptance) async {
    if (!acceptance.activeHouseholdSet) {
      _completingAcceptance = false;
      return;
    }
    await ref
        .read(authLifecycleProvider.notifier)
        .markActiveHousehold(acceptance.household);
    if (mounted) {
      context.go(AppRoutes.today);
    }
  }

  bool _isTerminal(InviteFailure failure) {
    return switch (failure.kind) {
      InviteFailureKind.invalid ||
      InviteFailureKind.expired ||
      InviteFailureKind.revoked ||
      InviteFailureKind.alreadyUsed => true,
      _ => false,
    };
  }

  String _roleLabel(AppLocalizations localizations, HouseholdInviteRole role) {
    return switch (role) {
      HouseholdInviteRole.member => localizations.inviteRoleMember,
      HouseholdInviteRole.admin => localizations.inviteRoleAdmin,
    };
  }

  String _expiryLabel(BuildContext context, DateTime expiresAt) {
    final MaterialLocalizations material = MaterialLocalizations.of(context);
    final DateTime local = expiresAt.toLocal();
    final String date = material.formatFullDate(local);
    final String time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(local),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return '$date, $time';
  }
}

class _LoadingInvite extends StatelessWidget {
  const _LoadingInvite({required this.localizations});

  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('invite.loading'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpacing.md),
        Text(localizations.inviteLoadingLabel, textAlign: TextAlign.center),
      ],
    );
  }
}

class _MissingInvite extends StatelessWidget {
  const _MissingInvite({required this.localizations});

  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('invite.missing'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.link_off, size: AppIconSize.status),
        const SizedBox(height: AppSpacing.md),
        Text(
          localizations.inviteMissingTitle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(localizations.inviteMissingBody, textAlign: TextAlign.center),
      ],
    );
  }
}

class _PreviewFailure extends ConsumerWidget {
  const _PreviewFailure({required this.failure, required this.localizations});

  final InviteFailure? failure;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      key: const Key('invite.preview.failure'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(Icons.error_outline, size: AppIconSize.status),
        const SizedBox(height: AppSpacing.md),
        Text(
          failure == null
              ? localizations.inviteGenericError
              : inviteFailureMessage(localizations, failure!),
          textAlign: TextAlign.center,
        ),
        if (failure == null || !_terminal(failure!)) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('invite.preview.retry'),
            onPressed: () =>
                unawaited(ref.read(inviteFlowProvider.notifier).loadPreview()),
            child: Text(localizations.retryAction),
          ),
        ],
      ],
    );
  }

  bool _terminal(InviteFailure failure) {
    return switch (failure.kind) {
      InviteFailureKind.invalid ||
      InviteFailureKind.expired ||
      InviteFailureKind.revoked ||
      InviteFailureKind.alreadyUsed => true,
      _ => false,
    };
  }
}
