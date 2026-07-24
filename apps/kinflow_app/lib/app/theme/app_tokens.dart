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

abstract final class AppRadii {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const BorderRadius medium = BorderRadius.all(Radius.circular(md));
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
}

abstract final class AppLayoutTokens {
  static const double dialogContentMaxWidth = 480;
  static const double statusContentMaxWidth = 640;
  static const double pageContentMaxWidth = 960;
  static const double navigationRailWidth = 72;
  static const double extendedNavigationRailWidth = 224;
}

abstract final class AppIconSize {
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
