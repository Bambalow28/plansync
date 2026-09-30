import 'package:flutter/material.dart';

/// PlanSync design language.
///
/// Shares the DNA of TravelSync — dark, premium, with a serif display face
/// (Crimson Text) paired against a mono label face (Anonymous Pro) — but
/// swaps the blue→purple accent for a fresh teal→emerald to make it its own
/// app in the same family.
class AppColors {
  AppColors._();

  // Base surfaces (a touch deeper / warmer than TravelSync's navy).
  static const Color background = Color(0xFF0A0E14);
  static const Color surface = Color(0xFF121821);
  static const Color surfaceHigh = Color(0xFF1A222E);
  static const Color surfaceLow = Color(0xFF0F141C);

  // Accent — teal → emerald.
  static const Color accent = Color(0xFF2DD4BF);
  static const Color accentAlt = Color(0xFF34D399);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentAlt],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surfaceHigh, surfaceLow],
  );

  /// A trip's backdrop before its destination photo (or a network) is
  /// available — no per-trip color choice, just the app's own surface tone.
  static const List<Color> tripPhotoFallback = [surfaceHigh, surfaceLow];

  // Text.
  static const Color textPrimary = Colors.white;
  static Color textSecondary = Colors.white.withValues(alpha: 0.55);
  static Color textMuted = Colors.white.withValues(alpha: 0.35);

  static Color hairline = accent.withValues(alpha: 0.14);
  static Color warning = const Color(0xFFE8614A);
}

class AppText {
  AppText._();

  /// Smallest type the app sets — the iOS floor for legible text. Anything
  /// asked for below it (mono captions, badges) is raised to it.
  static const double minSize = 11;
  static double _floor(double size) => size < minSize ? minSize : size;

  // Font families bundled under assets/fonts (declared in pubspec).
  static const String serif = 'CrimsonText';
  static const String mono = 'AnonymousPro';
  static const String sans = 'Inter';

  /// Big serif numerals / display headings.
  static TextStyle display(double size, {Color? color}) => TextStyle(
        fontFamily: serif,
        fontSize: size,
        fontWeight: FontWeight.bold,
        color: color ?? AppColors.textPrimary,
        height: 1.05,
      );

  /// Mono labels — small, uppercase, tracked.
  static TextStyle label(double size, {Color? color, double tracking = 1.2}) => TextStyle(
        fontFamily: mono,
        fontSize: _floor(size),
        color: color ?? AppColors.textMuted,
        letterSpacing: tracking,
      );

  /// Default body.
  static TextStyle body(double size, {Color? color, FontWeight? weight}) => TextStyle(
        fontFamily: sans,
        fontSize: _floor(size),
        color: color ?? AppColors.textPrimary,
        fontWeight: weight ?? FontWeight.w500,
      );
}

ThemeData buildPlanSyncTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(surface: AppColors.background),
    scaffoldBackgroundColor: AppColors.background,
    useMaterial3: true,
    fontFamily: AppText.sans,
  );
}
