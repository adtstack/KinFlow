import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/household/presentation/providers/household_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class InviteLinkCaptureScreen extends ConsumerStatefulWidget {
  const InviteLinkCaptureScreen({required this.rawToken, super.key});

  final String rawToken;

  @override
  ConsumerState<InviteLinkCaptureScreen> createState() =>
      _InviteLinkCaptureScreenState();
}

class _InviteLinkCaptureScreenState
    extends ConsumerState<InviteLinkCaptureScreen> {
  var _captured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_captured) {
      return;
    }
    _captured = true;
    ref.read(inviteFlowProvider.notifier).capture(widget.rawToken);
    scheduleMicrotask(() {
      if (mounted) {
        context.replace(AppRoutes.invite);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Scaffold(
      key: const Key('invite.capture.screen'),
      body: SafeArea(
        child: ScrollableStatusLayout(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.md),
              Text(
                localizations.inviteLoadingLabel,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
