import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/application/auth_email_otp_controller.dart';
import 'package:kinflow_app/features/auth/application/auth_email_otp_state.dart';
import 'package:kinflow_app/features/auth/application/auth_lifecycle_state.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_email_otp_failure.dart';
import 'package:kinflow_app/features/auth/domain/failures/auth_failure.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/presentation/providers/legal_support_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  late final AuthEmailOtpController _emailOtpController;
  late final StreamSubscription<AuthEmailOtpState> _emailOtpSubscription;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  AuthEmailOtpState _emailOtpState = const AuthEmailOtpEntry();
  bool _supportOpening = false;
  _IdentitySupportResult? _supportResult;

  @override
  void initState() {
    super.initState();
    _emailOtpController = AuthEmailOtpController(
      service: ref.read(authEmailOtpServiceProvider),
    );
    _emailOtpSubscription = _emailOtpController.states.listen((
      AuthEmailOtpState next,
    ) {
      final AuthEmailOtpState previous = _emailOtpState;
      if (next is AuthEmailOtpCodeSent &&
          (previous is! AuthEmailOtpCodeSent ||
              previous.challenge.generation != next.challenge.generation)) {
        _otpController.clear();
      }
      if (next is AuthEmailOtpVerifiedState) {
        TextInput.finishAutofillContext(shouldSave: false);
      }
      if (mounted) setState(() => _emailOtpState = next);
    });
  }

  @override
  void dispose() {
    unawaited(_emailOtpSubscription.cancel());
    unawaited(_emailOtpController.dispose());
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AuthLifecycleState state = ref.watch(authLifecycleProvider);
    final AuthLifecycleNotifier notifier = ref.read(
      authLifecycleProvider.notifier,
    );
    final bool canRequestSignIn =
        notifier.canRequestSignIn && !_emailOtpState.isBusy;
    final bool isSignInAvailable = notifier.isSignInAvailable;
    final bool isAuthenticating = state is AuthAuthenticating;
    final bool hasIdentityConflict =
        state.failure?.kind == AuthFailureKind.identityConflict;
    final String? statusMessage = _statusMessage(
      localizations,
      state,
      isSignInAvailable: isSignInAvailable,
      isEmailSignInAvailable: _emailOtpController.isAvailable,
    );

    return Scaffold(
      key: const Key('auth.signIn'),
      body: SafeArea(
        child: ScrollableStatusLayout(
          maxWidth: AppLayoutTokens.pageContentMaxWidth,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool expanded =
                  constraints.maxWidth >= AppBreakpoints.expanded;
              final Widget hero = _signInHero(
                localizations,
                expanded: expanded,
              );
              final Widget panel = _signInPanel(
                localizations,
                notifier,
                canRequestSignIn: canRequestSignIn,
                isSignInAvailable: isSignInAvailable,
                isAuthenticating: isAuthenticating,
                hasIdentityConflict: hasIdentityConflict,
                statusMessage: statusMessage,
              );
              if (!expanded) {
                return Column(
                  key: const Key('auth.signIn.compact'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    hero,
                    const SizedBox(height: AppSpacing.xl),
                    panel,
                  ],
                );
              }
              return Row(
                key: const Key('auth.signIn.expanded'),
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: hero),
                  const SizedBox(width: AppSpacing.xxl),
                  SizedBox(
                    width: AppLayoutTokens.dialogContentMaxWidth,
                    child: Card.outlined(
                      key: const Key('auth.signIn.panel'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: panel,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _signInHero(AppLocalizations localizations, {required bool expanded}) {
    final CrossAxisAlignment alignment = expanded
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    final TextAlign textAlign = expanded ? TextAlign.start : TextAlign.center;
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: <Widget>[
        const ExcludeSemantics(child: _KinFlowBrandMark()),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(
            localizations.authSignInTitle,
            style: expanded
                ? Theme.of(context).textTheme.headlineMedium
                : Theme.of(context).textTheme.headlineSmall,
            textAlign: textAlign,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(localizations.authSignInBody, textAlign: textAlign),
      ],
    );
    if (!expanded) return content;
    final List<Color> heroColors =
        Theme.of(context).brightness == Brightness.dark
        ? const <Color>[
            AppBrandColors.darkPrimaryContainer,
            AppBrandColors.darkMintContainer,
          ]
        : const <Color>[AppBrandColors.familyBlueSoft, AppBrandColors.mintSoft];
    return DecoratedBox(
      key: const Key('auth.signIn.heroSurface'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: heroColors,
        ),
        borderRadius: AppRadii.large,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: content,
      ),
    );
  }

  Widget _signInPanel(
    AppLocalizations localizations,
    AuthLifecycleNotifier notifier, {
    required bool canRequestSignIn,
    required bool isSignInAvailable,
    required bool isAuthenticating,
    required bool hasIdentityConflict,
    required String? statusMessage,
  }) {
    final bool emailEntry =
        _emailOtpState is AuthEmailOtpEntry ||
        _emailOtpState is AuthEmailOtpRequesting;
    final bool emailCode =
        _emailOtpState is AuthEmailOtpCodeSent ||
        _emailOtpState is AuthEmailOtpVerifiedState;
    final bool showGoogle =
        hasIdentityConflict ||
        (emailEntry && (isSignInAvailable || !_emailOtpController.isAvailable));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (statusMessage != null)
          Semantics(
            liveRegion: true,
            child: Material(
              key: const Key('auth.signIn.status'),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: AppRadii.small,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.info_outline, size: AppIconSize.inline),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(statusMessage)),
                  ],
                ),
              ),
            ),
          ),
        if (hasIdentityConflict) ...<Widget>[
          if (statusMessage != null) const SizedBox(height: AppSpacing.md),
          _identityConflictCard(localizations),
        ],
        if (!hasIdentityConflict && emailEntry) ...<Widget>[
          if (statusMessage != null) const SizedBox(height: AppSpacing.lg),
          _emailEntry(localizations, isAuthenticating),
        ],
        if (!hasIdentityConflict && emailCode) ...<Widget>[
          if (statusMessage != null) const SizedBox(height: AppSpacing.lg),
          _emailCode(localizations),
        ],
        if (showGoogle) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _googleAction(
            localizations,
            notifier,
            canRequestSignIn: canRequestSignIn,
            isAuthenticating: isAuthenticating,
            hasIdentityConflict: hasIdentityConflict,
          ),
        ],
        if (hasIdentityConflict) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          _identitySupportAction(localizations),
        ],
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const Key('auth.inviteCode'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed:
              isAuthenticating ||
                  _emailOtpState.isBusy ||
                  _emailOtpState is AuthEmailOtpVerifiedState
              ? null
              : () => unawaited(context.push<void>(AppRoutes.invite)),
          icon: const Icon(Icons.password_outlined),
          label: Text(localizations.inviteEnterCodeAction),
        ),
      ],
    );
  }

  Widget _googleAction(
    AppLocalizations localizations,
    AuthLifecycleNotifier notifier, {
    required bool canRequestSignIn,
    required bool isAuthenticating,
    required bool hasIdentityConflict,
  }) {
    final Widget button = hasIdentityConflict
        ? FilledButton.icon(
            key: const Key('auth.identityConflict.retry'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: canRequestSignIn
                ? () => unawaited(notifier.requestSignIn())
                : null,
            icon: isAuthenticating
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(
              isAuthenticating
                  ? localizations.authSigningInLabel
                  : localizations.authIdentityChooseAnotherAction,
            ),
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: canRequestSignIn
                ? () => unawaited(notifier.requestSignIn())
                : null,
            icon: isAuthenticating
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(
              isAuthenticating
                  ? localizations.authSigningInLabel
                  : localizations.authGoogleSignInAction,
            ),
          );
    return Semantics(
      key: const Key('auth.signIn.google'),
      button: true,
      enabled: canRequestSignIn,
      hint: hasIdentityConflict
          ? localizations.authIdentityChooseAnotherHint
          : localizations.authGoogleSignInHint,
      label: hasIdentityConflict
          ? localizations.authIdentityChooseAnotherAction
          : localizations.authGoogleSignInAction,
      onTap: canRequestSignIn
          ? () => unawaited(notifier.requestSignIn())
          : null,
      child: ExcludeSemantics(child: button),
    );
  }

  Widget _emailEntry(AppLocalizations localizations, bool isAuthenticating) {
    final bool requesting = _emailOtpState is AuthEmailOtpRequesting;
    final bool available = _emailOtpController.isAvailable;
    final AuthEmailOtpFailure? failure =
        _emailOtpState.failure ??
        (available
            ? null
            : const AuthEmailOtpFailure(
                AuthEmailOtpFailureKind.providerUnavailable,
              ));
    final bool enabled = available && !requesting && !isAuthenticating;
    return AutofillGroup(
      child: Column(
        key: const Key('auth.email.entry'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            localizations.authEmailSectionLabel,
            key: const Key('auth.email.heading'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('auth.email.address'),
            controller: _emailController,
            enabled: enabled,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            autocorrect: false,
            decoration: InputDecoration(
              labelText: localizations.authEmailLabel,
              helperText: localizations.authEmailHint,
              helperMaxLines: 100,
            ),
            onSubmitted: enabled
                ? (_) => unawaited(
                    _emailOtpController.requestCode(_emailController.text),
                  )
                : null,
          ),
          if (failure != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _emailFailure(localizations, failure),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('auth.email.send'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: enabled
                ? () => unawaited(
                    _emailOtpController.requestCode(_emailController.text),
                  )
                : null,
            icon: requesting
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mark_email_unread_outlined),
            label: Text(
              requesting
                  ? localizations.authEmailSendingCodeAction
                  : localizations.authEmailSendCodeAction,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailCode(AppLocalizations localizations) {
    final AuthEmailOtpState state = _emailOtpState;
    if (state case final AuthEmailOtpVerifiedState verified) {
      return Semantics(
        liveRegion: true,
        child: Column(
          key: const Key('auth.email.verified'),
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.md),
            Text(
              localizations.authEmailSigningInLabel,
              textAlign: TextAlign.center,
            ),
            if (verified.failure case final failure?) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _emailFailure(localizations, failure),
            ],
          ],
        ),
      );
    }
    final AuthEmailOtpCodeSent sent = state as AuthEmailOtpCodeSent;
    final bool busy = sent.actionInFlight;
    return AutofillGroup(
      child: Column(
        key: const Key('auth.email.code'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            liveRegion: true,
            child: Text(
              localizations.authEmailCodeSentBody(
                sent.challenge.email.maskedForDisplay,
              ),
              key: const Key('auth.email.sentStatus'),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            localizations.authEmailCodeLifetimeBody,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('auth.email.otp'),
            controller: _otpController,
            enabled: !busy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.oneTimeCode],
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            maxLength: 6,
            decoration: InputDecoration(
              labelText: localizations.authEmailCodeLabel,
              helperText: localizations.authEmailCodeHint,
              helperMaxLines: 100,
            ),
            onSubmitted: busy
                ? null
                : (_) => unawaited(
                    _emailOtpController.verifyCode(_otpController.text),
                  ),
          ),
          if (sent.failure case final failure?) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _emailFailure(localizations, failure),
          ],
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('auth.email.verify'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: busy
                ? null
                : () => unawaited(
                    _emailOtpController.verifyCode(_otpController.text),
                  ),
            icon: busy && !sent.resending
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(
              busy && !sent.resending
                  ? localizations.authEmailVerifyingAction
                  : localizations.authEmailVerifyAction,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            key: const Key('auth.email.resend'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: busy
                ? null
                : () => unawaited(_emailOtpController.resendCode()),
            icon: busy && sent.resending
                ? const SizedBox.square(
                    dimension: AppSpacing.md,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              busy && sent.resending
                  ? localizations.authEmailResendingAction
                  : localizations.authEmailResendAction,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            key: const Key('auth.email.change'),
            style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: busy
                ? null
                : () {
                    _otpController.clear();
                    _emailOtpController.changeEmail();
                  },
            icon: const Icon(Icons.edit_outlined),
            label: Text(localizations.authEmailChangeAction),
          ),
        ],
      ),
    );
  }

  Widget _emailFailure(
    AppLocalizations localizations,
    AuthEmailOtpFailure failure,
  ) {
    final String message = switch (failure.kind) {
      AuthEmailOtpFailureKind.invalidEmail =>
        localizations.authEmailInvalidEmailError,
      AuthEmailOtpFailureKind.invalidCode =>
        localizations.authEmailInvalidCodeError,
      AuthEmailOtpFailureKind.expired => localizations.authEmailExpiredError,
      AuthEmailOtpFailureKind.alreadyUsed =>
        localizations.authEmailAlreadyUsedError,
      AuthEmailOtpFailureKind.rateLimited =>
        localizations.authEmailRateLimitedError,
      AuthEmailOtpFailureKind.temporarilyUnavailable ||
      AuthEmailOtpFailureKind.providerUnavailable ||
      AuthEmailOtpFailureKind.invalidPayload ||
      AuthEmailOtpFailureKind.internal =>
        localizations.authEmailTemporarilyUnavailableError,
    };
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        key: const Key('auth.email.error'),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _identitySupportAction(AppLocalizations localizations) {
    return Column(
      children: <Widget>[
        OutlinedButton.icon(
          key: const Key('auth.identityConflict.support'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          onPressed: _supportOpening ? null : _openSupport,
          icon: _supportOpening
              ? const SizedBox.square(
                  dimension: AppSpacing.md,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.support_agent_outlined),
          label: Text(
            _supportOpening
                ? localizations.authIdentitySupportOpening
                : localizations.authIdentitySupportAction,
          ),
        ),
        if (_supportResult case final result?) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              result == _IdentitySupportResult.opened
                  ? localizations.authIdentitySupportOpened
                  : localizations.authIdentitySupportUnavailable,
              key: const Key('auth.identityConflict.supportResult'),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }

  Widget _identityConflictCard(AppLocalizations localizations) {
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        key: const Key('auth.identityConflict'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                localizations.authIdentityConflictTitle,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                localizations.authIdentityConflictBody,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSupport() async {
    if (_supportOpening) return;
    setState(() {
      _supportOpening = true;
      _supportResult = null;
    });
    LegalSupportResourceLaunchResult result;
    try {
      result = await ref
          .read(legalSupportResourceLauncherProvider)
          .launch(LegalSupportResource.support);
    } on Object {
      result = LegalSupportResourceLaunchResult.failed;
    }
    if (!mounted) return;
    setState(() {
      _supportOpening = false;
      _supportResult = result == LegalSupportResourceLaunchResult.opened
          ? _IdentitySupportResult.opened
          : _IdentitySupportResult.unavailable;
    });
  }

  String? _statusMessage(
    AppLocalizations localizations,
    AuthLifecycleState state, {
    required bool isSignInAvailable,
    required bool isEmailSignInAvailable,
  }) {
    if (state is AuthAuthenticating) {
      return localizations.authSigningInLabel;
    }
    final AuthFailure? failure = state.failure;
    if (failure == null) {
      return isSignInAvailable || isEmailSignInAvailable
          ? null
          : localizations.authProviderUnavailableBody;
    }
    return switch (failure.kind) {
      AuthFailureKind.identityConflict => null,
      AuthFailureKind.sessionExpired ||
      AuthFailureKind.sessionRevoked => localizations.authSessionExpiredBody,
      AuthFailureKind.localPurgeFailed =>
        localizations.authLocalStateLockedBody,
      _ => localizations.authProviderUnavailableBody,
    };
  }
}

class _KinFlowBrandMark extends StatelessWidget {
  const _KinFlowBrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('auth.brandMark'),
      width: 64,
      height: 64,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppBrandColors.familyBlue,
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.md)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _bar(constraints.maxHeight, 0.52, 1, AppBrandColors.markMint),
              const SizedBox(width: AppSpacing.xxs),
              _bar(constraints.maxHeight, 1, 2, Colors.white),
              const SizedBox(width: AppSpacing.xxs),
              _bar(constraints.maxHeight, 0.72, 3, AppBrandColors.markPeach),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(
    double availableHeight,
    double heightFactor,
    int index,
    Color color,
  ) {
    return Expanded(
      child: SizedBox(
        key: Key('auth.brandBar.$index'),
        height: availableHeight * heightFactor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadii.sm)),
          ),
        ),
      ),
    );
  }
}

enum _IdentitySupportResult { opened, unavailable }
