import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';

class ScrollableStatusLayout extends StatelessWidget {
  const ScrollableStatusLayout({
    required this.child,
    this.maxWidth = AppLayoutTokens.statusContentMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final AppWindowSizeClass sizeClass = AppBreakpoints.sizeClassFor(
          constraints.maxWidth,
        );
        final double padding = switch (sizeClass) {
          AppWindowSizeClass.compact => AppSpacing.lg,
          AppWindowSizeClass.medium => AppSpacing.xl,
          AppWindowSizeClass.expanded => AppSpacing.xxl,
        };
        final double minimumHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - (padding * 2))
                  .clamp(0, double.infinity)
                  .toDouble()
            : 0;

        return SingleChildScrollView(
          key: const Key('layout.scrollableStatus'),
          padding: EdgeInsets.all(padding),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minimumHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
