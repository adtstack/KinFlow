import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kinflow_app/app/theme/app_theme.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';

void main() {
  test('window size class boundaries are exact', () {
    expect(AppBreakpoints.sizeClassFor(0), AppWindowSizeClass.compact);
    expect(AppBreakpoints.sizeClassFor(599), AppWindowSizeClass.compact);
    expect(AppBreakpoints.sizeClassFor(600), AppWindowSizeClass.medium);
    expect(AppBreakpoints.sizeClassFor(839), AppWindowSizeClass.medium);
    expect(AppBreakpoints.sizeClassFor(840), AppWindowSizeClass.expanded);
  });

  test('light and dark themes materialize accessible semantic tokens', () {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final AppSemanticColors colors = theme.extension<AppSemanticColors>()!;
      final Color surface = theme.colorScheme.surface;

      expect(theme.useMaterial3, isTrue);
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
      expect(_contrastRatio(colors.ready, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(colors.info, surface), greaterThanOrEqualTo(4.5));
      expect(
        _contrastRatio(colors.warning, surface),
        greaterThanOrEqualTo(4.5),
      );

      final Size? minimumButtonSize = theme.filledButtonTheme.style?.minimumSize
          ?.resolve(<WidgetState>{});
      expect(minimumButtonSize?.width, AppTouchTarget.minimum);
      expect(minimumButtonSize?.height, AppTouchTarget.minimum);
    }
  });

  testWidgets('motion token respects reduced-motion platform setting', (
    WidgetTester tester,
  ) async {
    late Duration effectiveDuration;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (BuildContext context) {
            effectiveDuration = AppMotion.effectiveDuration(
              context,
              AppMotion.standard,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(effectiveDuration, Duration.zero);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (BuildContext context) {
            effectiveDuration = AppMotion.effectiveDuration(
              context,
              AppMotion.standard,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(effectiveDuration, AppMotion.standard);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final double foregroundLuminance = foreground.computeLuminance();
  final double backgroundLuminance = background.computeLuminance();
  final double lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final double darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
