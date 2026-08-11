import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kinflow_app/app/presentation/widgets/responsive_scaffold.dart';
import 'package:kinflow_app/app/presentation/widgets/scrollable_status_layout.dart';
import 'package:kinflow_app/app/router/app_router.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/analytics/application/analytics_preference_state.dart';
import 'package:kinflow_app/features/analytics/domain/entities/analytics_governance.dart';
import 'package:kinflow_app/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class AnalyticsPrivacyScreen extends ConsumerStatefulWidget {
  const AnalyticsPrivacyScreen({super.key});

  @override
  ConsumerState<AnalyticsPrivacyScreen> createState() =>
      _AnalyticsPrivacyScreenState();
}

class _AnalyticsPrivacyScreenState
    extends ConsumerState<AnalyticsPrivacyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool hasContent =
          ref.read(analyticsPreferenceProvider) is AnalyticsPreferenceReady;
      unawaited(
        ref
            .read(analyticsPreferenceProvider.notifier)
            .load(preserveContent: hasContent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AnalyticsPreferenceState state = ref.watch(
      analyticsPreferenceProvider,
    );
    return AppResponsiveScaffold(
      key: const Key('analyticsPrivacy.screen'),
      title: localizations.analyticsPrivacyTitle,
      actions: <Widget>[
        IconButton(
          key: const Key('analyticsPrivacy.settings'),
          onPressed: () => context.go(AppRoutes.settings),
          tooltip: localizations.settingsTitle,
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: switch (state) {
        AnalyticsPreferenceInitial() ||
        AnalyticsPreferenceLoading() => _loading(localizations),
        AnalyticsPreferenceLoadFailed() => _loadFailed(localizations),
        AnalyticsPreferenceReady() => _ready(localizations, state),
      },
    );
  }

  Widget _loading(AppLocalizations localizations) {
    return ScrollableStatusLayout(
      child: Column(
        key: const Key('analyticsPrivacy.loading'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            localizations.analyticsPrivacyLoading,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _loadFailed(AppLocalizations localizations) {
    return ScrollableStatusLayout(
      child: Column(
        key: const Key('analyticsPrivacy.error'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.privacy_tip_outlined, size: AppIconSize.status),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              localizations.analyticsPrivacyLoadFailed,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            key: const Key('analyticsPrivacy.retry'),
            onPressed: () => unawaited(
              ref.read(analyticsPreferenceProvider.notifier).load(),
            ),
            icon: const Icon(Icons.refresh),
            label: Text(localizations.retryAction),
          ),
        ],
      ),
    );
  }

  Widget _ready(
    AppLocalizations localizations,
    AnalyticsPreferenceReady state,
  ) {
    final AnalyticsSinkAvailability sinkAvailability = ref
        .watch(analyticsSinkProvider)
        .availability;
    return ListView(
      key: const Key('analyticsPrivacy.content'),
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
                _textCard(
                  key: const Key('analyticsPrivacy.intro'),
                  icon: Icons.shield_outlined,
                  title: localizations.analyticsPrivacyIntroTitle,
                  body: localizations.analyticsPrivacyIntroBody,
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  key: const Key('analyticsPrivacy.preference'),
                  child: Column(
                    children: <Widget>[
                      SwitchListTile.adaptive(
                        key: const Key('analyticsPrivacy.preferenceToggle'),
                        value:
                            state.preference ==
                            AnalyticsUsagePreference.granted,
                        onChanged: state.busy
                            ? null
                            : (bool enabled) => unawaited(
                                ref
                                    .read(analyticsPreferenceProvider.notifier)
                                    .save(
                                      enabled
                                          ? AnalyticsUsagePreference.granted
                                          : AnalyticsUsagePreference.withdrawn,
                                    ),
                              ),
                        title: Text(
                          localizations.analyticsPrivacyPreferenceTitle,
                        ),
                        subtitle: Text(
                          localizations.analyticsPrivacyPreferenceBody,
                        ),
                        secondary: const Icon(Icons.insights_outlined),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _collectionStatus(
                              localizations,
                              state.preference,
                              sinkAvailability,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.isSaving) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(),
                  _liveStatus(
                    key: const Key('analyticsPrivacy.status.saving'),
                    message: localizations.analyticsPrivacySaving,
                  ),
                ] else if (state.failure != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _liveStatus(
                    key: const Key('analyticsPrivacy.status.saveFailed'),
                    message: localizations.analyticsPrivacySaveFailed,
                  ),
                ] else if (state.saveCount > 0) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _liveStatus(
                    key: const Key('analyticsPrivacy.status.saved'),
                    message: localizations.analyticsPrivacySaved,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _textCard(
                  key: const Key('analyticsPrivacy.allowlist'),
                  icon: Icons.rule_outlined,
                  title: localizations.analyticsPrivacyAllowlistTitle,
                  body: localizations.analyticsPrivacyAllowlistBody,
                ),
                const SizedBox(height: AppSpacing.md),
                _textCard(
                  key: const Key('analyticsPrivacy.childPolicy'),
                  icon: Icons.family_restroom_outlined,
                  title: localizations.analyticsPrivacyChildPolicyTitle,
                  body: localizations.analyticsPrivacyChildPolicyBody,
                ),
                const SizedBox(height: AppSpacing.md),
                _inventoryCard(localizations),
                const SizedBox(height: AppSpacing.md),
                _textCard(
                  key: const Key('analyticsPrivacy.neverCollected'),
                  icon: Icons.block_outlined,
                  title: localizations.analyticsPrivacyNeverCollectedTitle,
                  body: localizations.analyticsPrivacyNeverCollectedBody,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _collectionStatus(
    AppLocalizations localizations,
    AnalyticsUsagePreference preference,
    AnalyticsSinkAvailability sinkAvailability,
  ) {
    if (preference != AnalyticsUsagePreference.granted) {
      return localizations.analyticsPrivacyStatusOff;
    }
    return sinkAvailability == AnalyticsSinkAvailability.available
        ? localizations.analyticsPrivacyStatusAvailable
        : localizations.analyticsPrivacyStatusNoSink;
  }

  Widget _inventoryCard(AppLocalizations localizations) {
    return Card(
      key: const Key('analyticsPrivacy.inventory'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.inventory_2_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    localizations.analyticsPrivacyInventoryTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(localizations.analyticsPrivacyInventoryBehavioral),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.analyticsPrivacyInventoryOperational),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.analyticsPrivacyInventoryNotifications),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.analyticsPrivacyInventoryBilling),
            const SizedBox(height: AppSpacing.xs),
            Text(localizations.analyticsPrivacyInventoryIdentity),
          ],
        ),
      ),
    );
  }

  Widget _textCard({
    required Key key,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(body),
          ],
        ),
      ),
    );
  }

  Widget _liveStatus({required Key key, required String message}) {
    return Card(
      key: key,
      child: Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(message),
        ),
      ),
    );
  }
}
