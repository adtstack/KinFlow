import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:kinflow_app/features/household/domain/entities/household_invite.dart';
import 'package:kinflow_app/features/household/domain/failures/invite_failure.dart';
import 'package:kinflow_app/features/household/domain/value_objects/household_identifiers.dart';
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
    final String? link = invite.rawToken == null
        ? null
        : Uri(
            scheme: 'https',
            host: configuration.authRedirectHost,
            pathSegments: <String>['invite', invite.rawToken!.value],
          ).toString();

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
        if (link != null) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          SelectableText(
            link,
            key: const Key('invite.create.link'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('invite.create.copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (!context.mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(localizations.inviteCopiedBody)),
              );
            },
            icon: const Icon(Icons.copy),
            label: Text(localizations.inviteCopyAction),
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
          onPressed: isRevoking
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
}
