import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/router/app_primary_destination.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kinflow_app/features/notifications/presentation/widgets/notification_app_shell_action.dart';
import 'package:kinflow_app/features/settings/presentation/providers/household_privacy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final bool showHouseholdPrivacy =
        ref.watch(householdPrivacyOwnerVisibilityProvider).value ?? false;
    return AppResponsiveScaffold(
      key: const Key('settings.screen'),
      selectedPrimaryDestination: AppPrimaryDestination.settings,
      onPrimaryDestinationSelected: (AppPrimaryDestination destination) =>
          context.go(AppRoutes.primaryLocation(destination)),
      title: localizations.settingsTitle,
      actions: const <Widget>[
        NotificationAppShellAction(buttonKey: Key('settings.notifications')),
      ],
      body: ListView(
        key: const Key('settings.list'),
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
                  _section(
                    context,
                    title: localizations.settingsAccountSection,
                    children: <Widget>[
                      _routeTile(
                        context,
                        key: const Key('settings.profilePreferences'),
                        icon: Icons.manage_accounts_outlined,
                        title: localizations.settingsProfilePreferencesTitle,
                        subtitle:
                            localizations.settingsProfilePreferencesSummary,
                        route: AppRoutes.profilePreferences,
                      ),
                      _routeTile(
                        context,
                        key: const Key('settings.dataExport'),
                        icon: Icons.download_outlined,
                        title: localizations.settingsDataExportTitle,
                        subtitle: localizations.settingsDataExportSummary,
                        route: AppRoutes.dataExport,
                      ),
                      ListTile(
                        key: const Key('settings.logout'),
                        leading: const Icon(Icons.logout),
                        title: Text(localizations.authLogoutAction),
                        onTap: () => unawaited(
                          ref.read(authLifecycleProvider.notifier).logout(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _section(
                    context,
                    title: localizations.membersTitle,
                    children: <Widget>[
                      _routeTile(
                        context,
                        key: const Key('settings.householdSwitch'),
                        icon: Icons.swap_horiz,
                        title: localizations.settingsHouseholdSwitchTitle,
                        subtitle: localizations.settingsHouseholdSwitchSummary,
                        route: AppRoutes.householdSwitch,
                      ),
                      _routeTile(
                        context,
                        key: const Key('settings.subscription'),
                        icon: Icons.workspace_premium_outlined,
                        title: localizations.settingsSubscriptionTitle,
                        subtitle: localizations.settingsSubscriptionSummary,
                        route: AppRoutes.subscription,
                      ),
                      if (showHouseholdPrivacy)
                        _routeTile(
                          context,
                          key: const Key('settings.householdPrivacy'),
                          icon: Icons.family_restroom_outlined,
                          title: localizations.settingsHouseholdPrivacyTitle,
                          subtitle:
                              localizations.settingsHouseholdPrivacySummary,
                          route: AppRoutes.householdPrivacy,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _section(
                    context,
                    title: localizations.settingsHelpSection,
                    children: <Widget>[
                      _routeTile(
                        context,
                        key: const Key('settings.legalSupport'),
                        icon: Icons.policy_outlined,
                        title: localizations.settingsLegalSupportTitle,
                        subtitle: localizations.settingsLegalSupportSummary,
                        route: AppRoutes.legalSupport,
                      ),
                      _routeTile(
                        context,
                        key: const Key('settings.analyticsPrivacy'),
                        icon: Icons.analytics_outlined,
                        title: localizations.settingsAnalyticsPrivacyTitle,
                        subtitle: localizations.settingsAnalyticsPrivacySummary,
                        route: AppRoutes.analyticsPrivacy,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _section(
                    context,
                    title: localizations.settingsDiagnosticsTitle,
                    children: <Widget>[
                      _routeTile(
                        context,
                        key: const Key('settings.deviceCapabilities'),
                        icon: Icons.devices_other_outlined,
                        title: localizations.settingsDeviceCapabilitiesTitle,
                        subtitle:
                            localizations.settingsDeviceCapabilitiesSummary,
                        route: AppRoutes.deviceCapabilities,
                      ),
                      _routeTile(
                        context,
                        key: const Key('settings.diagnostics'),
                        icon: Icons.info_outline,
                        title: localizations.settingsDiagnosticsTitle,
                        subtitle: localizations.settingsDiagnosticsSummary,
                        route: AppRoutes.diagnostics,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _dangerSection(context, localizations),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
        ),
        Card(child: Column(children: _withDividers(children))),
      ],
    );
  }

  Widget _dangerSection(BuildContext context, AppLocalizations localizations) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              localizations.settingsDeleteAccountTitle,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: colors.error),
            ),
          ),
        ),
        Card(
          color: colors.errorContainer.withValues(alpha: 0.36),
          child: ListTile(
            key: const Key('settings.accountDeletion'),
            leading: Icon(Icons.person_remove_outlined, color: colors.error),
            title: Text(localizations.settingsDeleteAccountTitle),
            subtitle: Text(localizations.settingsDeleteAccountSummary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                unawaited(context.push<void>(AppRoutes.accountDeletion)),
          ),
        ),
      ],
    );
  }

  Widget _routeTile(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return ListTile(
      key: key,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(context.push<void>(route)),
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    return <Widget>[
      for (int index = 0; index < children.length; index++) ...<Widget>[
        if (index > 0) const Divider(height: 1),
        children[index],
      ],
    ];
  }
}
