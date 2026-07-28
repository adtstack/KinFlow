import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';
import 'package:kinflow_app/l10n/app_localizations.dart';

class AppResponsiveScaffold extends StatelessWidget {
  const AppResponsiveScaffold({
    this.actions = const <Widget>[],
    required this.body,
    required this.title,
    super.key,
  });

  final List<Widget> actions;
  final Widget body;
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
            actions: actions,
            body: body,
            title: title,
          ),
          AppWindowSizeClass.medium => _RailScaffold(
            actions: actions,
            body: body,
            extended: false,
            sizeClass: sizeClass,
            title: title,
          ),
          AppWindowSizeClass.expanded => _RailScaffold(
            actions: actions,
            body: body,
            extended: true,
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
    required this.actions,
    required this.body,
    required this.title,
  });

  final List<Widget> actions;
  final Widget body;
  final String title;

  @override
  Widget build(BuildContext context) {
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
    );
  }
}

class _RailScaffold extends StatelessWidget {
  const _RailScaffold({
    required this.actions,
    required this.body,
    required this.extended,
    required this.sizeClass,
    required this.title,
  });

  final List<Widget> actions;
  final Widget body;
  final bool extended;
  final AppWindowSizeClass sizeClass;
  final String title;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);

    return Scaffold(
      key: Key('layout.${sizeClass.name}'),
      body: SafeArea(
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            children: <Widget>[
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: Semantics(
                  key: const Key('layout.primaryNavigation'),
                  container: true,
                  label: localizations.primaryNavigationLabel,
                  child: NavigationRail(
                    extended: extended,
                    labelType: NavigationRailLabelType.none,
                    onDestinationSelected: (_) {},
                    selectedIndex: 0,
                    useIndicator: true,
                    destinations: <NavigationRailDestination>[
                      NavigationRailDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home),
                        label: SizedBox(
                          width: AppLayoutTokens.navigationRailLabelWidth,
                          child: Text(
                            localizations.todayNavigationLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                key: const Key('layout.content'),
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
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
