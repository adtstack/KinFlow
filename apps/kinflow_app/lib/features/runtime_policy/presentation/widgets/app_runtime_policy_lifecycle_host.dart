import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/features/runtime_policy/application/app_runtime_policy_state.dart';
import 'package:kinflow_app/features/runtime_policy/domain/entities/app_runtime_policy.dart';
import 'package:kinflow_app/features/runtime_policy/presentation/providers/app_runtime_policy_providers.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class AppRuntimePolicyLifecycleHost extends ConsumerStatefulWidget {
  const AppRuntimePolicyLifecycleHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppRuntimePolicyLifecycleHost> createState() =>
      _AppRuntimePolicyLifecycleHostState();
}

class _AppRuntimePolicyLifecycleHostState
    extends ConsumerState<AppRuntimePolicyLifecycleHost>
    with WidgetsBindingObserver {
  var _initialLoadScheduled = false;
  var _externalBusy = false;
  var _externalFailure = false;
  var _unavailableExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialLoadScheduled) return;
    _initialLoadScheduled = true;
    scheduleMicrotask(() {
      if (!mounted) return;
      unawaited(ref.read(appRuntimePolicyProvider.notifier).load());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(
      ref.read(appRuntimePolicyProvider.notifier).load(preserveContent: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppRuntimePolicyState state = ref.watch(appRuntimePolicyProvider);
    final _RuntimePolicyBannerModel? model = _modelFor(state);
    if (model == null) return widget.child;
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (model.key == 'runtimePolicy.unavailable') {
      return Column(
        key: const Key('runtimePolicy.host'),
        verticalDirection: VerticalDirection.up,
        children: <Widget>[
          Expanded(child: widget.child),
          _compactUnavailableBanner(localizations, state, model),
        ],
      );
    }
    return Column(
      key: const Key('runtimePolicy.host'),
      verticalDirection: VerticalDirection.up,
      children: <Widget>[
        Expanded(child: widget.child),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.6,
          ),
          child: Material(
            key: Key(model.key),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(model.icon),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                model.title(localizations),
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(model.body(localizations)),
                              if (_externalFailure && model.updateRequired)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    localizations
                                        .runtimePolicyUpdateUnavailable,
                                    key: const Key(
                                      'runtimePolicy.updateFailure',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 4,
                        runSpacing: 4,
                        children: <Widget>[
                          _bannerAction(
                            key: const Key('runtimePolicy.retry'),
                            onPressed:
                                state is AppRuntimePolicyReady &&
                                    state.isRefreshing
                                ? null
                                : () => unawaited(
                                    ref
                                        .read(appRuntimePolicyProvider.notifier)
                                        .load(
                                          preserveContent:
                                              state is AppRuntimePolicyReady,
                                        ),
                                  ),
                            label: localizations.retryAction,
                          ),
                          if (model.updateRequired)
                            _bannerAction(
                              key: const Key('runtimePolicy.update'),
                              onPressed: _externalBusy ? null : _launchUpdate,
                              label: localizations.runtimePolicyUpdateAction,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _compactUnavailableBanner(
    AppLocalizations localizations,
    AppRuntimePolicyState state,
    _RuntimePolicyBannerModel model,
  ) {
    final String body = model.body(localizations);
    final VoidCallback? retry =
        state is AppRuntimePolicyReady && state.isRefreshing
        ? null
        : () => unawaited(
            ref
                .read(appRuntimePolicyProvider.notifier)
                .load(preserveContent: state is AppRuntimePolicyReady),
          );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
      ),
      child: Material(
        key: Key(model.key),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
            ),
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(model.icon, size: AppIconSize.inline),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          model.title(localizations),
                          style: Theme.of(context).textTheme.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Semantics(
                        key: const Key('runtimePolicy.details.semantics'),
                        button: true,
                        enabled: true,
                        expanded: _unavailableExpanded,
                        label: MaterialLocalizations.of(
                          context,
                        ).moreButtonTooltip,
                        hint: body,
                        onTap: _toggleUnavailableDetails,
                        child: ExcludeSemantics(
                          child: IconButton(
                            key: const Key('runtimePolicy.details'),
                            onPressed: _toggleUnavailableDetails,
                            icon: Icon(
                              _unavailableExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        enabled: retry != null,
                        label: localizations.retryAction,
                        onTap: retry,
                        child: ExcludeSemantics(
                          child: IconButton(
                            key: const Key('runtimePolicy.retry'),
                            onPressed: retry,
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_unavailableExpanded)
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.xl,
                            0,
                            AppSpacing.sm,
                            AppSpacing.xs,
                          ),
                          child: Text(
                            body,
                            key: const Key('runtimePolicy.detailsBody'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleUnavailableDetails() {
    setState(() => _unavailableExpanded = !_unavailableExpanded);
  }

  Widget _bannerAction({
    required Key key,
    required VoidCallback? onPressed,
    required String label,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: TextButton(key: key, onPressed: onPressed, child: Text(label)),
    );
  }

  _RuntimePolicyBannerModel? _modelFor(AppRuntimePolicyState state) {
    if (state is AppRuntimePolicyLoadFailed) {
      return _RuntimePolicyBannerModel.unavailable;
    }
    if (state case AppRuntimePolicyReady(:final snapshot)) {
      return switch (snapshot.decision) {
        AppRuntimePolicyDecisionKind.allowed =>
          state.refreshFailure == null
              ? snapshot.disabledFeatures.isEmpty
                    ? null
                    : _RuntimePolicyBannerModel.forDisabledFeatures(
                        snapshot.disabledFeatures,
                      )
              : _RuntimePolicyBannerModel.unavailable,
        AppRuntimePolicyDecisionKind.readOnly =>
          _RuntimePolicyBannerModel.readOnly,
        AppRuntimePolicyDecisionKind.updateRequired =>
          _RuntimePolicyBannerModel.forUpdateRequired(
            snapshot.policy.minimumSupportedVersion,
          ),
      };
    }
    return null;
  }

  Future<void> _launchUpdate() async {
    if (_externalBusy) return;
    setState(() {
      _externalBusy = true;
      _externalFailure = false;
    });
    final bool launched = await ref
        .read(runtimePolicyExternalLinkLauncherProvider)
        .launchUpdate();
    if (!mounted) return;
    setState(() {
      _externalBusy = false;
      _externalFailure = !launched;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

final class _RuntimePolicyBannerModel {
  const _RuntimePolicyBannerModel({
    required this.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.updateRequired,
  });

  final String key;
  final IconData icon;
  final String Function(AppLocalizations localizations) title;
  final String Function(AppLocalizations localizations) body;
  final bool updateRequired;

  static final _RuntimePolicyBannerModel unavailable =
      _RuntimePolicyBannerModel(
        key: 'runtimePolicy.unavailable',
        icon: Icons.cloud_off_outlined,
        title: (AppLocalizations l10n) => l10n.runtimePolicyUnavailableTitle,
        body: (AppLocalizations l10n) => l10n.runtimePolicyUnavailableBody,
        updateRequired: false,
      );

  static final _RuntimePolicyBannerModel readOnly = _RuntimePolicyBannerModel(
    key: 'runtimePolicy.readOnly',
    icon: Icons.lock_clock_outlined,
    title: (AppLocalizations l10n) => l10n.runtimePolicyReadOnlyTitle,
    body: (AppLocalizations l10n) => l10n.runtimePolicyReadOnlyBody,
    updateRequired: false,
  );

  static _RuntimePolicyBannerModel forUpdateRequired(String version) {
    return _RuntimePolicyBannerModel(
      key: 'runtimePolicy.updateRequired',
      icon: Icons.system_update_alt,
      title: (AppLocalizations l10n) => l10n.runtimePolicyUpdateTitle,
      body: (AppLocalizations l10n) => l10n.runtimePolicyUpdateBody(version),
      updateRequired: true,
    );
  }

  static _RuntimePolicyBannerModel forDisabledFeatures(
    List<AppRuntimeFeature> features,
  ) {
    final List<AppRuntimeFeature> exactFeatures = List<AppRuntimeFeature>.of(
      features,
      growable: false,
    );
    return _RuntimePolicyBannerModel(
      key: 'runtimePolicy.featureDisabled',
      icon: Icons.tune_outlined,
      title: (AppLocalizations l10n) => l10n.runtimePolicyFeatureDisabledTitle,
      body: (AppLocalizations l10n) => l10n.runtimePolicyFeatureDisabledBody(
        exactFeatures
            .map((AppRuntimeFeature feature) => _featureLabel(l10n, feature))
            .join(' · '),
      ),
      updateRequired: false,
    );
  }

  static String _featureLabel(
    AppLocalizations l10n,
    AppRuntimeFeature feature,
  ) {
    return switch (feature) {
      AppRuntimeFeature.household => l10n.runtimePolicyFeatureHousehold,
      AppRuntimeFeature.chores => l10n.runtimePolicyFeatureChores,
      AppRuntimeFeature.calendar => l10n.runtimePolicyFeatureCalendar,
      AppRuntimeFeature.notifications => l10n.runtimePolicyFeatureNotifications,
      AppRuntimeFeature.profile => l10n.runtimePolicyFeatureProfile,
      AppRuntimeFeature.billing => l10n.runtimePolicyFeatureBilling,
    };
  }
}
