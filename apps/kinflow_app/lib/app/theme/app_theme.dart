import 'package:flutter/material.dart';

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

    return ThemeData(colorScheme: colorScheme, useMaterial3: true);
  }
}
