import 'package:flutter/material.dart';

/// Shows an application-owned dialog with a closed keyboard focus loop and
/// restores focus to the control that opened it when the route closes.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  RouteSettings? routeSettings,
}) {
  return _showWithFocusReturn<T>(
    () => showDialog<T>(
      context: context,
      builder: builder,
      barrierDismissible: barrierDismissible,
      requestFocus: true,
      routeSettings: routeSettings,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      useRootNavigator: useRootNavigator,
      useSafeArea: useSafeArea,
    ),
  );
}

/// Shows an application-owned modal sheet with a closed keyboard focus loop and
/// restores focus to the control that opened it when the route closes.
Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  BoxConstraints? constraints,
  bool enableDrag = true,
  bool isDismissible = true,
  bool isScrollControlled = false,
  bool? showDragHandle,
  bool useRootNavigator = false,
  bool useSafeArea = false,
}) {
  return _showWithFocusReturn<T>(
    () => showModalBottomSheet<T>(
      context: context,
      builder: (BuildContext sheetContext) {
        return _ClosedLoopFocusScope(child: Builder(builder: builder));
      },
      constraints: constraints,
      enableDrag: enableDrag,
      isDismissible: isDismissible,
      isScrollControlled: isScrollControlled,
      requestFocus: true,
      showDragHandle: showDragHandle,
      useRootNavigator: useRootNavigator,
      useSafeArea: useSafeArea,
    ),
  );
}

Future<T?> _showWithFocusReturn<T>(Future<T?> Function() showRoute) async {
  final FocusNode? source = FocusManager.instance.primaryFocus;
  try {
    return await showRoute();
  } finally {
    _restoreFocusAfterRoute(source);
  }
}

void _restoreFocusAfterRoute(FocusNode? source) {
  if (source == null) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (source.context != null && source.canRequestFocus && !source.hasFocus) {
      source.requestFocus();
    }
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}

class _ClosedLoopFocusScope extends StatefulWidget {
  const _ClosedLoopFocusScope({required this.child});

  final Widget child;

  @override
  State<_ClosedLoopFocusScope> createState() => _ClosedLoopFocusScopeState();
}

class _ClosedLoopFocusScopeState extends State<_ClosedLoopFocusScope> {
  late final FocusScopeNode _focusScopeNode = FocusScopeNode(
    debugLabel: 'KinFlow modal sheet',
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
  );

  @override
  void dispose() {
    _focusScopeNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope.withExternalFocusNode(
      focusScopeNode: _focusScopeNode,
      child: widget.child,
    );
  }
}
