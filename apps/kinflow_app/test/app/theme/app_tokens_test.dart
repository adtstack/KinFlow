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

  test('theme roles preserve the bright KinFlow family identity', () {
    final ColorScheme light = AppTheme.light.colorScheme;
    final ColorScheme dark = AppTheme.dark.colorScheme;

    expect(light.primary, AppBrandColors.familyBlue);
    expect(light.primaryContainer, AppBrandColors.familyBlueSoft);
    expect(light.secondary, AppBrandColors.mintStrong);
    expect(light.tertiary, AppBrandColors.coralStrong);
    expect(light.surface, AppBrandColors.canvas);
    expect(light.onSurface, AppBrandColors.ink);

    expect(dark.primary, AppBrandColors.darkPrimary);
    expect(dark.primaryContainer, AppBrandColors.darkPrimaryContainer);
    expect(dark.secondary, AppBrandColors.darkMint);
    expect(dark.tertiary, AppBrandColors.darkCoral);
    expect(dark.surface, AppBrandColors.darkCanvas);
    expect(dark.onSurface, AppBrandColors.darkInk);
  });

  test('content-bearing color pairs meet WCAG AA contrast', () {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final ColorScheme scheme = theme.colorScheme;
      final List<(Color, Color)> pairs = <(Color, Color)>[
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onTertiary, scheme.tertiary),
        (scheme.onTertiaryContainer, scheme.tertiaryContainer),
        (scheme.onError, scheme.error),
        (scheme.onErrorContainer, scheme.errorContainer),
        (scheme.onSurface, scheme.surface),
        (scheme.onSurfaceVariant, scheme.surface),
        (scheme.onInverseSurface, scheme.inverseSurface),
        (scheme.inversePrimary, scheme.inverseSurface),
      ];

      for (final (Color foreground, Color background) in pairs) {
        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$foreground on $background',
        );
      }
    }
  });

  test('surface hierarchy preserves text and control boundary contrast', () {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final ColorScheme scheme = theme.colorScheme;
      final List<Color> surfaces = <Color>[
        scheme.surface,
        scheme.surfaceDim,
        scheme.surfaceBright,
        scheme.surfaceContainerLowest,
        scheme.surfaceContainerLow,
        scheme.surfaceContainer,
        scheme.surfaceContainerHigh,
        scheme.surfaceContainerHighest,
      ];

      for (final Color surface in surfaces) {
        expect(
          _contrastRatio(scheme.onSurface, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'onSurface $surface',
        );
        expect(
          _contrastRatio(scheme.onSurfaceVariant, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'onSurfaceVariant $surface',
        );
        expect(
          _contrastRatio(scheme.outline, surface),
          greaterThanOrEqualTo(3),
          reason: 'outline $surface',
        );
      }

      expect(
        _contrastRatio(scheme.primary, scheme.surfaceContainerLow),
        greaterThanOrEqualTo(3),
        reason: 'focused control boundary',
      );
      expect(
        _contrastRatio(scheme.error, scheme.surfaceContainerLow),
        greaterThanOrEqualTo(3),
        reason: 'error control boundary',
      );
    }
  });

  test('interactive component themes retain 48dp minimum targets', () {
    for (final ThemeData theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
      final List<ButtonStyle?> styles = <ButtonStyle?>[
        theme.filledButtonTheme.style,
        theme.outlinedButtonTheme.style,
        theme.textButtonTheme.style,
        theme.iconButtonTheme.style,
      ];

      for (final ButtonStyle? style in styles) {
        final Size? minimumSize = style?.minimumSize?.resolve(<WidgetState>{});
        expect(minimumSize?.width, AppTouchTarget.minimum);
        expect(minimumSize?.height, AppTouchTarget.minimum);
      }
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
