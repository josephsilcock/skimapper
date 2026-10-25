import 'package:flutter/material.dart';

/// SkiMapper's look: a glacier-teal scheme, white cards raised off a tinted background, and
/// snackbars that float clear of the screen's edges.
ThemeData appTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00687A));
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainer,
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 1,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.all(12),
    ),
  );
}
