import 'package:flutter/material.dart';

/// The product's colour palette.
///
/// ## Why these colours
///
/// The identity is built from lapis lazuli and gold — the two pigments that
/// illuminated both European medieval manuscripts and Persian miniatures. That
/// gives a bilingual product covering many traditions a visual centre that
/// belongs to none of them exclusively, and it reads as intellectual and
/// durable rather than fashionable.
///
/// Neither theme uses pure white or pure black. Light mode is warm paper,
/// because a page of sustained reading set on #FFFFFF glares; dark mode is a
/// blue-black with warm off-white text, because pure white on pure black
/// produces halation that makes long passages tiring.
///
/// Every foreground/background pair used by [AppColors.light] and
/// [AppColors.dark] is asserted against WCAG AA in
/// `test/core/design/contrast_test.dart`. Changing a value here without
/// re-running that test is how an accessible palette silently stops being one.
abstract final class AppColors {
  // ---------------------------------------------------------------------
  // Light theme — "paper"
  // ---------------------------------------------------------------------

  /// Warm paper. The base reading surface in light mode.
  static const Color paper = Color(0xFFFBF8F3);

  /// A slightly recessed paper tone for grouped content.
  static const Color paperContainer = Color(0xFFF4EFE7);

  /// The most recessed paper tone, for nested surfaces.
  static const Color paperContainerHigh = Color(0xFFEBE4D8);

  /// Near-black warm ink. Primary text in light mode.
  static const Color ink = Color(0xFF1C1A17);

  /// Softer ink for secondary text and metadata.
  static const Color inkMuted = Color(0xFF4F4A43);

  /// Borders and dividers that need to be seen.
  static const Color outlineLight = Color(0xFF7A736A);

  /// Hairline dividers that should recede.
  static const Color outlineVariantLight = Color(0xFFD5CCBE);

  /// Lapis. The primary accent in light mode.
  static const Color lapis = Color(0xFF23407D);

  /// A lapis-tinted fill for selected and highlighted states.
  static const Color lapisContainer = Color(0xFFDCE3F6);

  /// Text and icons drawn on [lapisContainer].
  static const Color onLapisContainer = Color(0xFF152547);

  /// Gold. The secondary accent in light mode, dark enough to carry text.
  static const Color gold = Color(0xFF7A5B14);

  /// A gold-tinted fill, used for quotations and editorial highlights.
  static const Color goldContainer = Color(0xFFF5E7C6);

  /// Text and icons drawn on [goldContainer].
  static const Color onGoldContainer = Color(0xFF3D2C00);

  /// Error red for light mode.
  static const Color errorLight = Color(0xFF9B2318);

  /// A red-tinted fill for error surfaces in light mode.
  static const Color errorContainerLight = Color(0xFFF9DEDC);

  /// Text and icons drawn on [errorContainerLight].
  static const Color onErrorContainerLight = Color(0xFF410E0B);

  // ---------------------------------------------------------------------
  // Dark theme — "lamplight"
  // ---------------------------------------------------------------------

  /// Deep blue-black. The base reading surface in dark mode.
  static const Color night = Color(0xFF101319);

  /// A raised night tone for grouped content.
  static const Color nightContainer = Color(0xFF191D26);

  /// The most raised night tone, for nested surfaces.
  static const Color nightContainerHigh = Color(0xFF232833);

  /// Warm off-white. Primary text in dark mode; deliberately not #FFFFFF.
  static const Color lamplight = Color(0xFFE9E4DB);

  /// Softer lamplight for secondary text and metadata.
  static const Color lamplightMuted = Color(0xFFB6B0A5);

  /// Borders and dividers that need to be seen in dark mode.
  static const Color outlineDark = Color(0xFF8A8479);

  /// Hairline dividers that should recede in dark mode.
  static const Color outlineVariantDark = Color(0xFF3B404B);

  /// Lapis lifted for legibility against [night].
  static const Color lapisLight = Color(0xFFA8BEF2);

  /// Text and icons drawn on [lapisLight] when it is used as a fill.
  static const Color onLapisLight = Color(0xFF0E1D3C);

  /// A lapis fill for selected states in dark mode.
  static const Color lapisContainerDark = Color(0xFF2A3F6C);

  /// Text and icons drawn on [lapisContainerDark].
  static const Color onLapisContainerDark = Color(0xFFD9E2FB);

  /// Gold lifted for legibility against [night].
  static const Color goldLight = Color(0xFFE3C47E);

  /// Text and icons drawn on [goldLight] when it is used as a fill.
  static const Color onGoldLight = Color(0xFF3A2A00);

  /// A gold fill for quotations in dark mode.
  static const Color goldContainerDark = Color(0xFF524012);

  /// Text and icons drawn on [goldContainerDark].
  static const Color onGoldContainerDark = Color(0xFFF6E4BC);

  /// Error red for dark mode.
  static const Color errorDark = Color(0xFFF2B8B5);

  /// A red fill for error surfaces in dark mode.
  static const Color errorContainerDark = Color(0xFF8C1D18);

  /// Text and icons drawn on [errorContainerDark].
  static const Color onErrorContainerDark = Color(0xFFF9DEDC);

  // ---------------------------------------------------------------------
  // Schemes
  // ---------------------------------------------------------------------

  /// The light colour scheme.
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: lapis,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: lapisContainer,
    onPrimaryContainer: onLapisContainer,
    secondary: gold,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: goldContainer,
    onSecondaryContainer: onGoldContainer,
    tertiary: Color(0xFF4A5F52),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD6E5DA),
    onTertiaryContainer: Color(0xFF15291D),
    error: errorLight,
    onError: Color(0xFFFFFFFF),
    errorContainer: errorContainerLight,
    onErrorContainer: onErrorContainerLight,
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: inkMuted,
    surfaceContainerLowest: Color(0xFFFFFDF9),
    surfaceContainerLow: Color(0xFFF8F4ED),
    surfaceContainer: paperContainer,
    surfaceContainerHigh: paperContainerHigh,
    surfaceContainerHighest: Color(0xFFE3DBCC),
    outline: outlineLight,
    outlineVariant: outlineVariantLight,
    inverseSurface: Color(0xFF32302C),
    onInverseSurface: Color(0xFFF5F0E8),
    inversePrimary: lapisLight,
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );

  /// The dark colour scheme.
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: lapisLight,
    onPrimary: onLapisLight,
    primaryContainer: lapisContainerDark,
    onPrimaryContainer: onLapisContainerDark,
    secondary: goldLight,
    onSecondary: onGoldLight,
    secondaryContainer: goldContainerDark,
    onSecondaryContainer: onGoldContainerDark,
    tertiary: Color(0xFFA8C7B4),
    onTertiary: Color(0xFF13301F),
    tertiaryContainer: Color(0xFF2C4636),
    onTertiaryContainer: Color(0xFFC4E3D0),
    error: errorDark,
    onError: Color(0xFF601410),
    errorContainer: errorContainerDark,
    onErrorContainer: onErrorContainerDark,
    surface: night,
    onSurface: lamplight,
    onSurfaceVariant: lamplightMuted,
    surfaceContainerLowest: Color(0xFF0B0D12),
    surfaceContainerLow: Color(0xFF14181F),
    surfaceContainer: nightContainer,
    surfaceContainerHigh: nightContainerHigh,
    surfaceContainerHighest: Color(0xFF2D323E),
    outline: outlineDark,
    outlineVariant: outlineVariantDark,
    inverseSurface: lamplight,
    onInverseSurface: Color(0xFF1C1A17),
    inversePrimary: lapis,
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );
}
