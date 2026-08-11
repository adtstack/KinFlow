import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kinflow_app/app/router/app_primary_destination.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class AppResponsiveScaffold extends StatelessWidget {
  const AppResponsiveScaffold({
    this.allowPrimaryDestinationReselection = false,
    this.actions = const <Widget>[],
    required this.body,
    this.onPrimaryDestinationSelected,
    this.selectedPrimaryDestination,
    required this.title,
    super.key,
  }) : assert(
         (onPrimaryDestinationSelected == null) ==
             (selectedPrimaryDestination == null),
         'Primary destination and callback must be provided together.',
       );

  final List<Widget> actions;
  final bool allowPrimaryDestinationReselection;
  final Widget body;
  final ValueChanged<AppPrimaryDestination>? onPrimaryDestinationSelected;
  final AppPrimaryDestination? selectedPrimaryDestination;
  final String title;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppWindowSizeClass sizeClass = AppBreakpoints.sizeClassFor(
          constraints.maxWidth,
        );
        return switch (sizeClass) {
          AppWindowSizeClass.compact => _CompactScaffold(
            allowPrimaryDestinationReselection:
                allowPrimaryDestinationReselection,
            actions: actions,
            body: body,
            onPrimaryDestinationSelected: onPrimaryDestinationSelected,
            selectedPrimaryDestination: selectedPrimaryDestination,
            title: title,
          ),
          AppWindowSizeClass.medium => _RailScaffold(
            allowPrimaryDestinationReselection:
                allowPrimaryDestinationReselection,
            actions: actions,
            body: body,
            extended: false,
            onPrimaryDestinationSelected: onPrimaryDestinationSelected,
            selectedPrimaryDestination: selectedPrimaryDestination,
            sizeClass: sizeClass,
            title: title,
          ),
          AppWindowSizeClass.expanded => _RailScaffold(
            allowPrimaryDestinationReselection:
                allowPrimaryDestinationReselection,
            actions: actions,
            body: body,
            extended: true,
            onPrimaryDestinationSelected: onPrimaryDestinationSelected,
            selectedPrimaryDestination: selectedPrimaryDestination,
            sizeClass: sizeClass,
            title: title,
          ),
        };
      },
    );
  }
}

class _CompactScaffold extends StatelessWidget {
  const _CompactScaffold({
    required this.allowPrimaryDestinationReselection,
    required this.actions,
    required this.body,
    required this.onPrimaryDestinationSelected,
    required this.selectedPrimaryDestination,
    required this.title,
  });

  final List<Widget> actions;
  final bool allowPrimaryDestinationReselection;
  final Widget body;
  final ValueChanged<AppPrimaryDestination>? onPrimaryDestinationSelected;
  final AppPrimaryDestination? selectedPrimaryDestination;
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPrimaryDestination? selectedDestination =
        selectedPrimaryDestination;
    final ValueChanged<AppPrimaryDestination>? onDestinationSelected =
        onPrimaryDestinationSelected;

    return Scaffold(
      key: const Key('layout.compact'),
      appBar: AppBar(
        actions: actions,
        title: Semantics(
          header: true,
          child: Text(title, key: const Key('layout.pageHeading')),
        ),
      ),
      body: SafeArea(child: body),
      bottomNavigationBar:
          selectedDestination == null || onDestinationSelected == null
          ? null
          : Semantics(
              key: const Key('layout.primaryNavigation'),
              container: true,
              label: localizations.primaryNavigationLabel,
              child: NavigationBar(
                selectedIndex: selectedDestination.index,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (int index) {
                  final AppPrimaryDestination destination =
                      AppPrimaryDestination.values[index];
                  if (allowPrimaryDestinationReselection ||
                      destination != selectedDestination) {
                    onDestinationSelected(destination);
                  }
                },
                destinations: _primaryDestinationSpecs(localizations)
                    .map(
                      (_PrimaryDestinationSpec spec) => NavigationDestination(
                        icon: SizedBox.square(
                          key: Key(
                            'layout.primaryNavigation.'
                            '${spec.destination.name}',
                          ),
                          dimension: AppTouchTarget.minimum,
                          child: Icon(spec.icon),
                        ),
                        selectedIcon: SizedBox.square(
                          key: Key(
                            'layout.primaryNavigation.'
                            '${spec.destination.name}',
                          ),
                          dimension: AppTouchTarget.minimum,
                          child: Icon(spec.selectedIcon),
                        ),
                        label: spec.label,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
    );
  }
}

class _RailScaffold extends StatelessWidget {
  const _RailScaffold({
    required this.allowPrimaryDestinationReselection,
    required this.actions,
    required this.body,
    required this.extended,
    required this.onPrimaryDestinationSelected,
    required this.selectedPrimaryDestination,
    required this.sizeClass,
    required this.title,
  });

  final List<Widget> actions;
  final bool allowPrimaryDestinationReselection;
  final Widget body;
  final bool extended;
  final ValueChanged<AppPrimaryDestination>? onPrimaryDestinationSelected;
  final AppPrimaryDestination? selectedPrimaryDestination;
  final AppWindowSizeClass sizeClass;
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPrimaryDestination? selectedDestination =
        selectedPrimaryDestination;
    final ValueChanged<AppPrimaryDestination>? onDestinationSelected =
        onPrimaryDestinationSelected;
    final bool showPrimaryNavigation =
        selectedDestination != null && onDestinationSelected != null;

    return Scaffold(
      key: Key('layout.${sizeClass.name}'),
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            children: <Widget>[
              if (showPrimaryNavigation) ...<Widget>[
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: Semantics(
                    key: const Key('layout.primaryNavigation'),
                    container: true,
                    label: localizations.primaryNavigationLabel,
                    child: NavigationRail(
                      extended: extended,
                      labelType: NavigationRailLabelType.none,
                      onDestinationSelected: (int index) {
                        final AppPrimaryDestination destination =
                            AppPrimaryDestination.values[index];
                        if (allowPrimaryDestinationReselection ||
                            destination != selectedDestination) {
                          onDestinationSelected(destination);
                        }
                      },
                      selectedIndex: selectedDestination.index,
                      useIndicator: true,
                      destinations: _primaryDestinationSpecs(localizations)
                          .map(
                            (
                              _PrimaryDestinationSpec spec,
                            ) => NavigationRailDestination(
                              icon: SizedBox.square(
                                key: Key(
                                  'layout.primaryNavigation.'
                                  '${spec.destination.name}',
                                ),
                                dimension: AppTouchTarget.minimum,
                                child: Icon(spec.icon),
                              ),
                              selectedIcon: SizedBox.square(
                                key: Key(
                                  'layout.primaryNavigation.'
                                  '${spec.destination.name}',
                                ),
                                dimension: AppTouchTarget.minimum,
                                child: Icon(spec.selectedIcon),
                              ),
                              label: SizedBox(
                                width: AppLayoutTokens.navigationRailLabelWidth,
                                child: Text(
                                  spec.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                key: const Key('layout.content'),
                child: FocusTraversalOrder(
                  order: NumericFocusOrder(showPrimaryNavigation ? 2 : 1),
                  child: Column(
                    children: <Widget>[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.md,
                          ),
                          child: Row(
                            children: <Widget>[
                              if (!showPrimaryNavigation &&
                                  Navigator.of(context).canPop())
                                BackButton(
                                  key: const Key('layout.back'),
                                  onPressed: () => unawaited(
                                    Navigator.of(context).maybePop(),
                                  ),
                                ),
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    title,
                                    key: const Key('layout.pageHeading'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                ),
                              ),
                              ...actions,
                            ],
                          ),
                        ),
                      ),
                      Expanded(child: body),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _PrimaryDestinationSpec {
  const _PrimaryDestinationSpec({
    required this.destination,
    required this.icon,
    required this.label,
    required this.selectedIcon,
  });

  final AppPrimaryDestination destination;
  final IconData icon;
  final String label;
  final IconData selectedIcon;
}

List<_PrimaryDestinationSpec> _primaryDestinationSpecs(
  AppLocalizations localizations,
) => <_PrimaryDestinationSpec>[
  _PrimaryDestinationSpec(
    destination: AppPrimaryDestination.today,
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
    label: localizations.todayNavigationLabel,
  ),
  _PrimaryDestinationSpec(
    destination: AppPrimaryDestination.calendar,
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month,
    label: localizations.calendarNavigationLabel,
  ),
  _PrimaryDestinationSpec(
    destination: AppPrimaryDestination.family,
    icon: Icons.group_outlined,
    selectedIcon: Icons.group,
    label: localizations.familyNavigationLabel,
  ),
  _PrimaryDestinationSpec(
    destination: AppPrimaryDestination.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: localizations.settingsNavigationLabel,
  ),
];
