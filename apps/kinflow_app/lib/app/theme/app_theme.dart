import 'package:flutter/material.dart';
import 'package:kinflow_app/app/theme/app_tokens.dart';

abstract final class AppTheme {
  static ThemeData get dark {
    return _theme(Brightness.dark);
  }

  static ThemeData get light {
    return _theme(Brightness.light);
  }

  static ThemeData _theme(Brightness brightness) {
    final ColorScheme colorScheme = _colorScheme(brightness);
    final ThemeData baseTheme = ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
    );

    return baseTheme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: AppElevation.none,
        foregroundColor: colorScheme.onSurface,
        scrolledUnderElevation: AppElevation.none,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        dragHandleColor: colorScheme.outline,
        elevation: AppElevation.medium,
        modalBackgroundColor: colorScheme.surfaceContainerLow,
        modalElevation: AppElevation.medium,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        clipBehavior: Clip.antiAlias,
        color: colorScheme.surfaceContainerLow,
        elevation: AppElevation.none,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.medium,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        elevation: AppElevation.medium,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.large),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
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
      focusColor: colorScheme.primary.withValues(alpha: 0.24),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll<Size>(AppTouchTarget.minimumSize),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.medium,
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        elevation: AppElevation.none,
        indicatorColor: colorScheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        elevation: AppElevation.none,
        indicatorColor: colorScheme.primaryContainer,
        minExtendedWidth: AppLayoutTokens.extendedNavigationRailWidth,
        minWidth: AppLayoutTokens.navigationRailWidth,
        selectedIconTheme: IconThemeData(color: colorScheme.onPrimaryContainer),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: AppTypographyTokens.titleWeight,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            AppTouchTarget.minimumSize,
          ),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
          ),
          shape: const WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: AppRadii.medium),
          ),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: colorScheme.outline),
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        circularTrackColor: colorScheme.primaryContainer,
        linearTrackColor: colorScheme.primaryContainer,
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      snackBarTheme: SnackBarThemeData(
        actionTextColor: colorScheme.inversePrimary,
        backgroundColor: colorScheme.inverseSurface,
        behavior: SnackBarBehavior.fixed,
        closeIconColor: colorScheme.onInverseSurface,
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.small),
        showCloseIcon: true,
      ),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll<Size>(AppTouchTarget.minimumSize),
          padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: AppRadii.medium),
          ),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colorScheme.primary,
        selectionColor: colorScheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: colorScheme.primary,
      ),
      textTheme: _textTheme(baseTheme.textTheme),
    );
  }

  static ColorScheme _colorScheme(Brightness brightness) {
    final ColorScheme generated = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: AppBrandColors.familyBlue,
    );

    return switch (brightness) {
      Brightness.light => generated.copyWith(
        primary: AppBrandColors.familyBlue,
        onPrimary: Colors.white,
        primaryContainer: AppBrandColors.familyBlueSoft,
        onPrimaryContainer: AppBrandColors.familyBlueStrong,
        secondary: AppBrandColors.mintStrong,
        onSecondary: Colors.white,
        secondaryContainer: AppBrandColors.mintSoft,
        onSecondaryContainer: const Color(0xFF0A4F3E),
        tertiary: AppBrandColors.coralStrong,
        onTertiary: Colors.white,
        tertiaryContainer: AppBrandColors.coralSoft,
        onTertiaryContainer: const Color(0xFF7A2519),
        error: const Color(0xFFBA1A1A),
        onError: Colors.white,
        errorContainer: const Color(0xFFFFDAD6),
        onErrorContainer: const Color(0xFF410002),
        surface: AppBrandColors.canvas,
        onSurface: AppBrandColors.ink,
        surfaceDim: AppBrandColors.paperStrong,
        surfaceBright: AppBrandColors.canvas,
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: AppBrandColors.paper,
        surfaceContainer: AppBrandColors.surfaceMuted,
        surfaceContainerHigh: AppBrandColors.paperStrong,
        surfaceContainerHighest: AppBrandColors.surfaceHighest,
        onSurfaceVariant: AppBrandColors.inkMuted,
        outline: AppBrandColors.outline,
        outlineVariant: AppBrandColors.line,
        inverseSurface: AppBrandColors.ink,
        onInverseSurface: AppBrandColors.canvas,
        inversePrimary: AppBrandColors.darkPrimary,
        shadow: AppBrandColors.ink,
        scrim: AppBrandColors.ink,
        surfaceTint: AppBrandColors.familyBlue,
      ),
      Brightness.dark => generated.copyWith(
        primary: AppBrandColors.darkPrimary,
        onPrimary: AppBrandColors.darkOnPrimary,
        primaryContainer: AppBrandColors.darkPrimaryContainer,
        onPrimaryContainer: AppBrandColors.darkOnPrimaryContainer,
        secondary: AppBrandColors.darkMint,
        onSecondary: AppBrandColors.darkOnMint,
        secondaryContainer: AppBrandColors.darkMintContainer,
        onSecondaryContainer: AppBrandColors.darkOnMintContainer,
        tertiary: AppBrandColors.darkCoral,
        onTertiary: AppBrandColors.darkOnCoral,
        tertiaryContainer: AppBrandColors.darkCoralContainer,
        onTertiaryContainer: AppBrandColors.darkOnCoralContainer,
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
        errorContainer: const Color(0xFF93000A),
        onErrorContainer: const Color(0xFFFFDAD6),
        surface: AppBrandColors.darkCanvas,
        onSurface: AppBrandColors.darkInk,
        surfaceDim: AppBrandColors.darkCanvas,
        surfaceBright: AppBrandColors.darkSurfaceBright,
        surfaceContainerLowest: AppBrandColors.darkSurfaceLowest,
        surfaceContainerLow: AppBrandColors.darkSurfaceLow,
        surfaceContainer: AppBrandColors.darkSurface,
        surfaceContainerHigh: AppBrandColors.darkSurfaceHigh,
        surfaceContainerHighest: AppBrandColors.darkSurfaceHighest,
        onSurfaceVariant: AppBrandColors.darkInkMuted,
        outline: AppBrandColors.darkOutline,
        outlineVariant: AppBrandColors.darkLine,
        inverseSurface: AppBrandColors.paper,
        onInverseSurface: AppBrandColors.ink,
        inversePrimary: AppBrandColors.familyBlueStrong,
        shadow: Colors.black,
        scrim: Colors.black,
        surfaceTint: AppBrandColors.darkPrimary,
      ),
    };
  }

  static TextTheme _textTheme(TextTheme textTheme) {
    return textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontWeight: AppTypographyTokens.headingWeight,
        letterSpacing: AppTypographyTokens.headingLetterSpacing,
      ),
      displayMedium: textTheme.displayMedium?.copyWith(
        fontWeight: AppTypographyTokens.headingWeight,
        letterSpacing: AppTypographyTokens.headingLetterSpacing,
      ),
      displaySmall: textTheme.displaySmall?.copyWith(
        fontWeight: AppTypographyTokens.headingWeight,
        letterSpacing: AppTypographyTokens.headingLetterSpacing,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontWeight: AppTypographyTokens.headingWeight,
        letterSpacing: AppTypographyTokens.headingLetterSpacing,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontWeight: AppTypographyTokens.headingWeight,
        letterSpacing: AppTypographyTokens.headingLetterSpacing,
      ),
      headlineSmall: textTheme.headlineSmall?.copyWith(
        fontWeight: AppTypographyTokens.headingWeight,
        letterSpacing: AppTypographyTokens.headingLetterSpacing,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: AppTypographyTokens.titleWeight,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontWeight: AppTypographyTokens.titleWeight,
      ),
      labelLarge: textTheme.labelLarge?.copyWith(
        fontWeight: AppTypographyTokens.titleWeight,
      ),
    );
  }
}
