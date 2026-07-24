import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';

abstract final class AppTheme {
  static const Color _seedColor = Color(0xFF4F46E5);

  static ThemeData get dark {
    return _theme(Brightness.dark);
  }

  static ThemeData get light {
    return _theme(Brightness.light);
  }

  static ThemeData _theme(Brightness brightness) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: _seedColor,
    );

    return ThemeData(
      colorScheme: colorScheme,
      extensions: <ThemeExtension<dynamic>>[
        AppSemanticColors.forBrightness(brightness),
      ],
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll<Size>(AppTouchTarget.minimumSize),
          padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: AppRadii.medium),
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll<Size>(AppTouchTarget.minimumSize),
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      navigationRailTheme: const NavigationRailThemeData(
        elevation: AppElevation.none,
        minExtendedWidth: AppLayoutTokens.extendedNavigationRailWidth,
        minWidth: AppLayoutTokens.navigationRailWidth,
      ),
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );
  }
}
