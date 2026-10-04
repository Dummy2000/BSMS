import 'package:flutter/material.dart';

/// Retro NES-style theme used while the Konami easter egg is unlocked.
///
/// Press Start 2P font + a chunky NES palette + square (zero-radius) shapes.
/// Press Start 2P is very wide/tall, so the text sizes are scaled down hard and
/// the system text scaler is clamped (see app.dart) to limit layout overflow.
ThemeData pixelTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  // NES-ish palette.
  const nesBlue   = Color(0xFF3CBCFC);
  const nesRed    = Color(0xFFE03030);
  const nesYellow = Color(0xFFFCD000);
  const nesBg     = Color(0xFF0B0B1A);
  const nesSurface = Color(0xFF161628);

  final scheme = ColorScheme.fromSeed(
    seedColor: nesBlue,
    brightness: brightness,
  ).copyWith(
    primary: nesBlue,
    onPrimary: Colors.black,
    secondary: nesRed,
    onSecondary: Colors.white,
    tertiary: nesYellow,
    onTertiary: Colors.black,
    error: nesRed,
    surface: isDark ? nesSurface : Colors.white,
    onSurface: isDark ? Colors.white : Colors.black,
    surfaceContainerHighest: isDark ? const Color(0xFF22223A) : const Color(0xFFE6E6F0),
  );

  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);

  // Press Start 2P, shrunk substantially (it renders ~2x larger than normal).
  // NOTE: do NOT use TextTheme.apply(fontSizeFactor:) — it asserts when any
  // style has a null fontSize (which both the Material base and the GoogleFonts
  // theme can have). Scale manually with a null-safe copyWith instead.
  const f = 0.55;
  TextStyle? sc(TextStyle? s) =>
      s?.copyWith(fontSize: (s.fontSize ?? 14) * f, letterSpacing: 0);
  // Bundled font (works offline) — see pubspec.yaml fonts: PressStart2P.
  final gf = base.textTheme.apply(fontFamily: 'PressStart2P');
  final pixelText = TextTheme(
    displayLarge:  sc(gf.displayLarge),
    displayMedium: sc(gf.displayMedium),
    displaySmall:  sc(gf.displaySmall),
    headlineLarge: sc(gf.headlineLarge),
    headlineMedium: sc(gf.headlineMedium),
    headlineSmall: sc(gf.headlineSmall),
    titleLarge:    sc(gf.titleLarge),
    titleMedium:   sc(gf.titleMedium),
    titleSmall:    sc(gf.titleSmall),
    bodyLarge:     sc(gf.bodyLarge),
    bodyMedium:    sc(gf.bodyMedium),
    bodySmall:     sc(gf.bodySmall),
    labelLarge:    sc(gf.labelLarge),
    labelMedium:   sc(gf.labelMedium),
    labelSmall:    sc(gf.labelSmall),
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  const squareBorder = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
  final thickSide = BorderSide(color: scheme.primary, width: 2);

  ButtonStyle blockyButton(Color bg, Color fg) => ButtonStyle(
        shape: const WidgetStatePropertyAll(squareBorder),
        backgroundColor: WidgetStatePropertyAll(bg),
        foregroundColor: WidgetStatePropertyAll(fg),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.onSurface, width: 2)),
        elevation: const WidgetStatePropertyAll(0),
      );

  return base.copyWith(
    scaffoldBackgroundColor: isDark ? nesBg : scheme.surface,
    textTheme: pixelText,
    primaryTextTheme: pixelText,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: isDark ? nesBg : scheme.primary,
      foregroundColor: isDark ? scheme.primary : Colors.black,
      titleTextStyle: pixelText.titleMedium,
    ),
    cardTheme: const CardThemeData(
      shape: squareBorder,
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: blockyButton(scheme.primary, scheme.onPrimary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: blockyButton(scheme.primary, scheme.onPrimary),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(squareBorder),
        side: WidgetStatePropertyAll(thickSide),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: const ButtonStyle(shape: WidgetStatePropertyAll(squareBorder)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
          borderRadius: BorderRadius.zero, borderSide: thickSide),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: scheme.onSurface, width: 2)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero, borderSide: thickSide),
    ),
    dialogTheme: const DialogThemeData(shape: squareBorder),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: squareBorder,
      showDragHandle: true,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: scheme.onSurface, width: 1)),
    ),
    snackBarTheme: const SnackBarThemeData(
      shape: squareBorder,
      behavior: SnackBarBehavior.fixed,
    ),
    popupMenuTheme: const PopupMenuThemeData(shape: squareBorder),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? nesSurface : scheme.surface,
      indicatorShape: squareBorder,
      indicatorColor: scheme.primary.withAlpha(60),
      labelTextStyle: WidgetStatePropertyAll(pixelText.labelSmall),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
    ),
  );
}
