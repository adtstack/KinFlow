import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/settings/application/ports/legal_support_resource_launcher.dart';
import 'package:kinflow_app/features/settings/presentation/providers/legal_support_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class LegalSupportScreen extends ConsumerStatefulWidget {
  const LegalSupportScreen({super.key});

  @override
  ConsumerState<LegalSupportScreen> createState() => _LegalSupportScreenState();
}

class _LegalSupportScreenState extends ConsumerState<LegalSupportScreen> {
  LegalSupportResource? _openingResource;
  LegalSupportResource? _openedResource;
  var _externalFailure = false;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AppResponsiveScaffold(
      key: const Key('legalSupport.screen'),
      title: localizations.legalSupportTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('legalSupport.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: ListView(
        key: const Key('legalSupport.content'),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayoutTokens.statusContentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(localizations.legalSupportIntro),
                  if (_statusCard(localizations)
                      case final status?) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    status,
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _documentAuthorityCard(localizations),
                  const SizedBox(height: AppSpacing.md),
                  _resourceCard(
                    key: const Key('legalSupport.terms'),
                    icon: Icons.description_outlined,
                    title: localizations.legalSupportTermsTitle,
                    body: localizations.legalSupportTermsBody,
                    note: localizations.legalSupportTermsVersionNote,
                    actionKey: const Key('legalSupport.terms.open'),
                    actionLabel: localizations.legalSupportTermsOpenAction,
                    resource: LegalSupportResource.terms,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _privacyCard(localizations),
                  const SizedBox(height: AppSpacing.md),
                  _resourceCard(
                    key: const Key('legalSupport.support'),
                    icon: Icons.support_agent_outlined,
                    title: localizations.legalSupportSupportTitle,
                    body: localizations.legalSupportSupportBody,
                    note: localizations.legalSupportSupportPrivacyNote,
                    actionKey: const Key('legalSupport.support.open'),
                    actionLabel: localizations.legalSupportSupportOpenAction,
                    resource: LegalSupportResource.support,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _consentCard(localizations),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _statusCard(AppLocalizations localizations) {
    final LegalSupportResource? opening = _openingResource;
    if (opening != null) {
      return _messageCard(
        key: const Key('legalSupport.status.opening'),
        icon: Icons.open_in_browser_outlined,
        message: localizations.legalSupportOpening(
          _resourceName(localizations, opening),
        ),
      );
    }
    if (_externalFailure) {
      return _messageCard(
        key: const Key('legalSupport.status.failure'),
        icon: Icons.open_in_new_off,
        message: localizations.legalSupportExternalUnavailable,
      );
    }
    final LegalSupportResource? opened = _openedResource;
    if (opened != null) {
      return _messageCard(
        key: const Key('legalSupport.status.opened'),
        icon: Icons.check_circle_outline,
        message: localizations.legalSupportOpened(
          _resourceName(localizations, opened),
        ),
      );
    }
    return null;
  }

  Widget _documentAuthorityCard(AppLocalizations localizations) {
    return Card(
      key: const Key('legalSupport.documentAuthority'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.legalSupportDocumentVersionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.legalSupportDocumentVersionBody),
          ],
        ),
      ),
    );
  }

  Widget _privacyCard(AppLocalizations localizations) {
    return Card(
      key: const Key('legalSupport.privacy'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _resourceHeading(
              Icons.privacy_tip_outlined,
              localizations.legalSupportPrivacyTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.legalSupportPrivacyBody),
            const SizedBox(height: AppSpacing.sm),
            Text(
              localizations.legalSupportPrivacyVersionNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('legalSupport.privacy.open'),
              onPressed: _openingResource == null
                  ? () => unawaited(_open(LegalSupportResource.privacy))
                  : null,
              icon: const Icon(Icons.open_in_new),
              label: Text(localizations.legalSupportPrivacyOpenAction),
            ),
            const Divider(height: AppSpacing.xl),
            Text(
              localizations.legalSupportPrivacyControlsTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.legalSupportPrivacyControlsBody),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              key: const Key('legalSupport.privacy.export'),
              onPressed: () => context.go(AppRoutes.dataExport),
              icon: const Icon(Icons.download_outlined),
              label: Text(localizations.settingsDataExportTitle),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              key: const Key('legalSupport.privacy.delete'),
              onPressed: () => context.go(AppRoutes.accountDeletion),
              icon: const Icon(Icons.person_remove_outlined),
              label: Text(localizations.settingsDeleteAccountTitle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resourceCard({
    required Key key,
    required IconData icon,
    required String title,
    required String body,
    required String note,
    required Key actionKey,
    required String actionLabel,
    required LegalSupportResource resource,
  }) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _resourceHeading(icon, title),
            const SizedBox(height: AppSpacing.sm),
            Text(body),
            const SizedBox(height: AppSpacing.sm),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: actionKey,
              onPressed: _openingResource == null
                  ? () => unawaited(_open(resource))
                  : null,
              icon: const Icon(Icons.open_in_new),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resourceHeading(IconData icon, String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
      ],
    );
  }

  Widget _consentCard(AppLocalizations localizations) {
    return Card(
      key: const Key('legalSupport.consent'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              localizations.legalSupportConsentTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.legalSupportConsentBody),
          ],
        ),
      ),
    );
  }

  Widget _messageCard({
    required Key key,
    required IconData icon,
    required String message,
  }) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Semantics(
          liveRegion: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(LegalSupportResource resource) async {
    if (_openingResource != null) return;
    setState(() {
      _openingResource = resource;
      _openedResource = null;
      _externalFailure = false;
    });
    final LegalSupportResourceLaunchResult result = await ref
        .read(legalSupportResourceLauncherProvider)
        .launch(resource);
    if (!mounted) return;
    setState(() {
      _openingResource = null;
      if (result == LegalSupportResourceLaunchResult.opened) {
        _openedResource = resource;
      } else {
        _externalFailure = true;
      }
    });
  }

  String _resourceName(
    AppLocalizations localizations,
    LegalSupportResource resource,
  ) {
    return switch (resource) {
      LegalSupportResource.terms => localizations.legalSupportTermsResourceName,
      LegalSupportResource.privacy =>
        localizations.legalSupportPrivacyResourceName,
      LegalSupportResource.support =>
        localizations.legalSupportSupportResourceName,
    };
  }
}
