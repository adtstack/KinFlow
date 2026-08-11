import 'package:flutter/material.dart';

enum AppWindowSizeClass { compact, medium, expanded }

abstract final class AppBreakpoints {
  static const double medium = 600;
  static const double expanded = 840;

  static AppWindowSizeClass sizeClassFor(double width) {
    assert(width >= 0, 'Available width must not be negative.');
    if (width < medium) {
      return AppWindowSizeClass.compact;
    }
    if (width < expanded) {
      return AppWindowSizeClass.medium;
    }
    return AppWindowSizeClass.expanded;
  }
}

abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// KinFlow's shared product identity.
///
/// These values mirror the public-site palette. Material role colors are
/// assembled from them by the application theme. Clear blue provides a modern
/// foundation, while mint and coral keep family moments warm and playful.
abstract final class AppBrandColors {
  static const Color familyBlue = Color(0xFF3568DC);
  static const Color familyBlueStrong = Color(0xFF2048A8);
  static const Color familyBlueSoft = Color(0xFFE6EEFF);

  static const Color mint = Color(0xFF42C7A5);
  static const Color mintStrong = Color(0xFF17775E);
  static const Color mintSoft = Color(0xFFDDF8F0);

  static const Color coral = Color(0xFFF47D6A);
  static const Color coralStrong = Color(0xFFC84E3D);
  static const Color coralSoft = Color(0xFFFFE5DF);

  static const Color markMint = Color(0xFF8BE0C6);
  static const Color markPeach = Color(0xFFFFB8A8);

  static const Color canvas = Color(0xFFFCFDFF);
  static const Color paper = Colors.white;
  static const Color paperStrong = Color(0xFFEDF1F8);
  static const Color surfaceMuted = Color(0xFFF5F7FC);
  static const Color surfaceHighest = Color(0xFFE3E9F3);

  static const Color ink = Color(0xFF172033);
  static const Color inkMuted = Color(0xFF566176);
  static const Color line = Color(0xFFD8DFEA);
  static const Color outline = Color(0xFF68758A);

  static const Color darkCanvas = Color(0xFF101522);
  static const Color darkSurfaceLowest = Color(0xFF0B0F19);
  static const Color darkSurfaceLow = Color(0xFF141A27);
  static const Color darkSurface = Color(0xFF192131);
  static const Color darkSurfaceBright = Color(0xFF364159);
  static const Color darkSurfaceHigh = Color(0xFF222C40);
  static const Color darkSurfaceHighest = Color(0xFF2D3950);
  static const Color darkInk = Color(0xFFF1F4FC);
  static const Color darkInkMuted = Color(0xFFBCC6D9);
  static const Color darkOutline = Color(0xFF8995AA);
  static const Color darkLine = Color(0xFF3E4960);
  static const Color darkPrimary = Color(0xFFAFC6FF);
  static const Color darkOnPrimary = Color(0xFF08295F);
  static const Color darkPrimaryContainer = Color(0xFF264D9E);
  static const Color darkOnPrimaryContainer = Color(0xFFDCE7FF);
  static const Color darkMint = Color(0xFF72DDBB);
  static const Color darkOnMint = Color(0xFF00382B);
  static const Color darkMintContainer = Color(0xFF0B5B46);
  static const Color darkOnMintContainer = Color(0xFFA1F2D3);
  static const Color darkCoral = Color(0xFFFFB4A8);
  static const Color darkOnCoral = Color(0xFF5D160B);
  static const Color darkCoralContainer = Color(0xFF7B2F22);
  static const Color darkOnCoralContainer = Color(0xFFFFDAD4);
}

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const BorderRadius small = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
  static const BorderRadius large = BorderRadius.all(Radius.circular(lg));
}

abstract final class AppElevation {
  static const double none = 0;
  static const double low = 1;
  static const double medium = 3;
}

abstract final class AppTouchTarget {
  static const double minimum = 48;
  static const Size minimumSize = Size.square(minimum);
}

abstract final class AppTypographyTokens {
  static const double maximumTestedTextScale = 2;
  static const FontWeight headingWeight = FontWeight.w700;
  static const FontWeight titleWeight = FontWeight.w600;
  static const double headingLetterSpacing = -0.3;
}

abstract final class AppLayoutTokens {
  static const double dialogContentMaxWidth = 480;
  static const double statusContentMaxWidth = 640;
  static const double pageContentMaxWidth = 960;
  static const double navigationRailWidth = 72;
  static const double extendedNavigationRailWidth = 224;
  static const double navigationRailLabelWidth = 128;
}

abstract final class AppIconSize {
  static const double inline = 20;
  static const double status = 56;
}

abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration standard = Duration(milliseconds: 250);
  static const Curve standardCurve = Curves.easeInOutCubic;

  static Duration effectiveDuration(BuildContext context, Duration requested) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : requested;
  }
}

@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.info,
    required this.ready,
    required this.warning,
  });

  factory AppSemanticColors.forBrightness(Brightness brightness) {
    return switch (brightness) {
      Brightness.light => const AppSemanticColors(
        info: Color(0xFF075985),
        ready: Color(0xFF146C2E),
        warning: Color(0xFF8A4F00),
      ),
      Brightness.dark => const AppSemanticColors(
        info: Color(0xFF7DD3FC),
        ready: Color(0xFF6DD58C),
        warning: Color(0xFFFFB95C),
      ),
    };
  }

  final Color info;
  final Color ready;
  final Color warning;

  @override
  AppSemanticColors copyWith({Color? info, Color? ready, Color? warning}) {
    return AppSemanticColors(
      info: info ?? this.info,
      ready: ready ?? this.ready,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) {
      return this;
    }
    return AppSemanticColors(
      info: Color.lerp(info, other.info, t)!,
      ready: Color.lerp(ready, other.ready, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}
