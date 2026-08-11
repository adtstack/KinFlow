import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/config/app_public_configuration.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/providers/app_providers.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/household/application/invite_creation_state.dart';
import 'package:kinflow_app/features/household/application/invite_sharing_state.dart';
import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_invite_link.dart';
import 'package:kinflow_app/features/household/domain/value_objects/invite_identifiers.dart';
import 'package:kinflow_app/features/household/presentation/invite_failure_message.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class HouseholdInviteCreationScreen extends ConsumerStatefulWidget {
  const HouseholdInviteCreationScreen({super.key});

  @override
  ConsumerState<HouseholdInviteCreationScreen> createState() =>
      _HouseholdInviteCreationScreenState();
}

class _HouseholdInviteCreationScreenState
    extends ConsumerState<HouseholdInviteCreationScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final InviteCreationState state = ref.watch(inviteCreationProvider);
    final AuthLifecycleState authState = ref.watch(authLifecycleProvider);
    final HouseholdId? householdId = authState.activeHousehold?.householdId;

    return AppResponsiveScaffold(
      key: const Key('invite.create.screen'),
      title: localizations.inviteCreateTitle,
      actions: <Widget>[
        if (!context.canPop())
          IconButton(
            key: const Key('invite.create.close'),
            onPressed: () => context.go(AppRoutes.today),
            tooltip: localizations.goHomeAction,
            icon: const Icon(Icons.close),
          ),
      ],
      body: ScrollableStatusLayout(
        maxWidth: AppLayoutTokens.dialogContentMaxWidth,
        child: _content(context, localizations, state, householdId),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations localizations,
    InviteCreationState state,
    HouseholdId? householdId,
  ) {
    final HouseholdInvite? invite = switch (state) {
      InviteCreationSucceeded(:final invite) => invite,
      InviteCreationRevoking(:final invite) => invite,
      InviteCreationFailed(:final invite?) => invite,
      _ => null,
    };
    final InviteFailure? failure = switch (state) {
      InviteCreationFailed(:final failure) => failure,
      _ => null,
    };
    if (invite != null) {
      return _InviteLinkResult(
        invite: invite,
        failure: failure,
        isRevoking: state is InviteCreationRevoking,
      );
    }
    final bool isSubmitting = state is InviteCreationSubmitting;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              localizations.inviteCreateHeading,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(localizations.inviteCreateBody, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            key: const Key('invite.create.email'),
            controller: _emailController,
            enabled: !isSubmitting,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            decoration: InputDecoration(
              labelText: localizations.inviteEmailLabel,
              helperText: localizations.inviteEmailHint,
            ),
            validator: (String? value) {
              final String email = value?.trim() ?? '';
              if (email.isEmpty) {
                return null;
              }
              return RegExp(r'^[^\s@]+@[^\s@]+$').hasMatch(email) &&
                      email.length <= 254
                  ? null
                  : localizations.householdInvalidInputError;
            },
          ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                inviteFailureMessage(localizations, failure),
                key: const Key('invite.create.error'),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('invite.create.submit'),
            onPressed: isSubmitting || householdId == null
                ? null
                : () {
                    if (!(_formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    unawaited(
                      ref
                          .read(inviteCreationProvider.notifier)
                          .create(
                            householdId: householdId,
                            targetEmail: _emailController.text,
                          ),
                    );
                  },
            icon: isSubmitting
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1),
            label: Text(
              isSubmitting
                  ? localizations.inviteCreatingAction
                  : localizations.inviteCreateAction,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteLinkResult extends ConsumerWidget {
  const _InviteLinkResult({
    required this.invite,
    required this.failure,
    required this.isRevoking,
  });

  final HouseholdInvite invite;
  final InviteFailure? failure;
  final bool isRevoking;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPublicConfiguration configuration = ref.watch(
      appPublicConfigurationProvider,
    );
    final HouseholdInviteLink? inviteLink = invite.rawToken == null
        ? null
        : HouseholdInviteLink.tryCreate(
            host: configuration.authRedirectHost,
            token: invite.rawToken!,
          );
    final String? link = inviteLink?.value;
    final InviteShortCode? inviteShortCode = invite.rawShortCode;
    final String? shortCode = inviteShortCode?.formatted;
    final InviteSharingState sharingState = ref.watch(inviteSharingProvider);
    final bool sharingBusy = sharingState is InviteSharingInProgress;
    final String? sharingMessage = _sharingMessage(localizations, sharingState);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            localizations.inviteLinkHeading,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          link == null
              ? localizations.inviteTokenUnavailableBody
              : localizations.inviteLinkBody,
          textAlign: TextAlign.center,
        ),
        if (shortCode != null && invite.shortCodeExpiresAt != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            localizations.inviteCodeHeading,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(localizations.inviteCodeBody, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          SelectableText(
            shortCode,
            key: const Key('invite.create.code'),
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.inviteExpiryLabel(
              _expiryLabel(context, invite.shortCodeExpiresAt!),
            ),
            key: const Key('invite.create.codeExpiry'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            key: const Key('invite.create.copyCode'),
            onPressed: isRevoking || sharingBusy
                ? null
                : () => unawaited(
                    ref
                        .read(inviteSharingProvider.notifier)
                        .copyShortCode(inviteShortCode!),
                  ),
            icon:
                sharingState is InviteSharingInProgress &&
                    sharingState.action == InviteSharingAction.copyShortCode
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy),
            label: Text(localizations.inviteCodeCopyAction),
          ),
        ],
        if (link != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          SelectableText(
            link,
            key: const Key('invite.create.link'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('invite.create.share'),
            onPressed: isRevoking || sharingBusy
                ? null
                : () => unawaited(
                    ref
                        .read(inviteSharingProvider.notifier)
                        .share(
                          inviteLink!,
                          chooserTitle: localizations.inviteShareChooserTitle,
                        ),
                  ),
            icon:
                sharingState is InviteSharingInProgress &&
                    sharingState.action == InviteSharingAction.shareLink
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share),
            label: Text(localizations.inviteShareAction),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('invite.create.copy'),
            onPressed: isRevoking || sharingBusy
                ? null
                : () => unawaited(
                    ref
                        .read(inviteSharingProvider.notifier)
                        .copyLink(inviteLink!),
                  ),
            icon:
                sharingState is InviteSharingInProgress &&
                    sharingState.action == InviteSharingAction.copyLink
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy),
            label: Text(localizations.inviteCopyAction),
          ),
        ],
        if (link != null || shortCode != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(
            localizations.inviteClipboardNotice,
            key: const Key('invite.create.clipboardNotice'),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (sharingMessage != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              sharingMessage,
              key: const Key('invite.create.actionStatus'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        if (failure != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              inviteFailureMessage(localizations, failure!),
              key: const Key('invite.revoke.error'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          key: const Key('invite.create.revoke'),
          onPressed: isRevoking || sharingBusy
              ? null
              : () => unawaited(
                  ref.read(inviteCreationProvider.notifier).revoke(),
                ),
          icon: isRevoking
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.link_off),
          label: Text(
            isRevoking
                ? localizations.inviteRevokingAction
                : localizations.inviteRevokeAction,
          ),
        ),
      ],
    );
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

  String? _sharingMessage(
    AppLocalizations localizations,
    InviteSharingState state,
  ) {
    return switch (state) {
      InviteSharingIdle() => null,
      InviteSharingInProgress(:final action) => switch (action) {
        InviteSharingAction.shareLink => localizations.inviteShareOpeningBody,
        InviteSharingAction.copyLink ||
        InviteSharingAction.copyShortCode => localizations.inviteCopyingBody,
      },
      InviteSharingCompleted(:final outcome) => switch (outcome) {
        InviteSharingOutcome.shareSheetOpened =>
          localizations.inviteShareOpenedBody,
        InviteSharingOutcome.shareUnavailable =>
          localizations.inviteShareUnavailableBody,
        InviteSharingOutcome.shareFailed => localizations.inviteShareFailedBody,
        InviteSharingOutcome.linkCopied => localizations.inviteCopiedBody,
        InviteSharingOutcome.shortCodeCopied =>
          localizations.inviteCodeCopiedBody,
        InviteSharingOutcome.linkCopyFailed ||
        InviteSharingOutcome.shortCodeCopyFailed =>
          localizations.inviteCopyFailedBody,
      },
    };
  }
}
