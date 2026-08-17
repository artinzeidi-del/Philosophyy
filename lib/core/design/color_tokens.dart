import 'package:flutter/material.dart';

/// The product's colour palette.
///
/// ## Why these colours
///
/// The identity is an ember against deep water: a warm coral that carries every
/// action, on cool teal-slate surfaces, over a canvas that runs from warm light
/// in one corner to deep green-blue in the other. It reads as a lit instrument
/// in a dim room, which is the register a reference work wants — attentive
/// rather than clinical, and belonging to no single tradition's palette.
///
/// Dark is the primary form of the theme and light is its daylight variant, in
/// the same two hues rather than a different scheme wearing the same name. The
/// coral has to darken considerably in light mode: a coral light enough to glow
/// on slate cannot carry text on paper, and the palette would rather change the
/// value than fail the ratio.
///
/// Neither theme uses pure white or pure black. Light mode is warm blush paper,
/// because a page of sustained reading set on #FFFFFF glares; dark mode is a
/// deep teal-slate with warm off-white text, because pure white on pure black
/// produces halation that makes long passages tiring.
///
/// Every foreground/background pair used by [AppColors.light] and
/// [AppColors.dark] is asserted against WCAG AA in
/// `test/core/design/contrast_test.dart`. Changing a value here without
/// re-running that test is how an accessible palette silently stops being one.
abstract final class AppColors {
  // ---------------------------------------------------------------------
  // Light theme — "daylight"
  // ---------------------------------------------------------------------

  /// Warm blush paper. The base reading surface in light mode.
  static const Color blush = Color(0xFFFBF2ED);

  /// A slightly recessed blush tone for grouped content.
  static const Color blushContainer = Color(0xFFF3E7E1);

  /// The most recessed blush tone, for nested surfaces.
  static const Color blushContainerHigh = Color(0xFFEADAD3);

  /// Deep teal ink. Primary text in light mode.
  static const Color ink = Color(0xFF17242A);

  /// Softer ink for secondary text and metadata.
  static const Color inkMuted = Color(0xFF48595F);

  /// Borders and dividers that need to be seen.
  static const Color outlineLight = Color(0xFF6E7E83);

  /// Hairline dividers that should recede.
  static const Color outlineVariantLight = Color(0xFFD8C7C0);

  /// Ember, darkened until it can carry text on paper.
  static const Color emberDeep = Color(0xFFAE3A26);

  /// An ember-tinted fill for selected and highlighted states.
  static const Color emberContainerLight = Color(0xFFFBDDD4);

  /// Text and icons drawn on [emberContainerLight].
  static const Color onEmberContainerLight = Color(0xFF48130A);

  /// Verdigris, the cool counterpart, dark enough to carry text on paper.
  static const Color verdigrisDeep = Color(0xFF1C5F55);

  /// A verdigris-tinted fill, used for quotations and editorial highlights.
  static const Color verdigrisContainerLight = Color(0xFFCFE9E2);

  /// Text and icons drawn on [verdigrisContainerLight].
  static const Color onVerdigrisContainerLight = Color(0xFF00201B);

  /// Error red for light mode.
  static const Color errorLight = Color(0xFF9B2318);

  /// A red-tinted fill for error surfaces in light mode.
  static const Color errorContainerLight = Color(0xFFF9DEDC);

  /// Text and icons drawn on [errorContainerLight].
  static const Color onErrorContainerLight = Color(0xFF410E0B);

  // ---------------------------------------------------------------------
  // Dark theme — "ember"
  // ---------------------------------------------------------------------

  /// Deep teal-slate. The base reading surface in dark mode.
  static const Color slate = Color(0xFF121E24);

  /// A raised slate tone for grouped content.
  static const Color slateContainer = Color(0xFF1B2A32);

  /// The most raised slate tone, for nested surfaces.
  static const Color slateContainerHigh = Color(0xFF243740);

  /// Warm off-white. Primary text in dark mode; deliberately not #FFFFFF.
  static const Color daylight = Color(0xFFE6EDEE);

  /// Softer daylight for secondary text and metadata.
  static const Color daylightMuted = Color(0xFFAABDC4);

  /// Borders and dividers that need to be seen in dark mode.
  static const Color outlineDark = Color(0xFF7C949C);

  /// Hairline dividers that should recede in dark mode.
  static const Color outlineVariantDark = Color(0xFF354A54);

  /// Ember. The primary accent, and the colour every action is drawn in.
  static const Color ember = Color(0xFFFF9E8A);

  /// Text and icons drawn on [ember] when it is used as a fill.
  static const Color onEmber = Color(0xFF3E120A);

  /// An ember fill for selected states in dark mode.
  static const Color emberContainerDark = Color(0xFF6B2A1D);

  /// Text and icons drawn on [emberContainerDark].
  static const Color onEmberContainerDark = Color(0xFFFFDBD2);

  /// Verdigris lifted for legibility against [slate].
  static const Color verdigris = Color(0xFF86D8C4);

  /// Text and icons drawn on [verdigris] when it is used as a fill.
  static const Color onVerdigris = Color(0xFF00352C);

  /// A verdigris fill for quotations in dark mode.
  static const Color verdigrisContainerDark = Color(0xFF1D4E45);

  /// Text and icons drawn on [verdigrisContainerDark].
  static const Color onVerdigrisContainerDark = Color(0xFFB8ECDF);

  /// Error red for dark mode.
  static const Color errorDark = Color(0xFFF2B8B5);

  /// A red fill for error surfaces in dark mode.
  static const Color errorContainerDark = Color(0xFF8C1D18);

  /// Text and icons drawn on [errorContainerDark].
  static const Color onErrorContainerDark = Color(0xFFF9DEDC);

  // ---------------------------------------------------------------------
  // The canvas
  // ---------------------------------------------------------------------

  /// The warm corner of the ambient wash.
  static const Color auroraWarm = Color(0xFFF0A88C);

  /// The cool corner of the ambient wash.
  static const Color auroraCool = Color(0xFF2E6E68);

  /// The deep corner the wash settles into.
  static const Color auroraDeep = Color(0xFF10333A);

  // ---------------------------------------------------------------------
  // Schemes
  // ---------------------------------------------------------------------

  /// The light colour scheme.
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: emberDeep,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: emberContainerLight,
    onPrimaryContainer: onEmberContainerLight,
    secondary: verdigrisDeep,
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: verdigrisContainerLight,
    onSecondaryContainer: onVerdigrisContainerLight,
    tertiary: Color(0xFF2F5C86),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD4E4F5),
    onTertiaryContainer: Color(0xFF0C2237),
    error: errorLight,
    onError: Color(0xFFFFFFFF),
    errorContainer: errorContainerLight,
    onErrorContainer: onErrorContainerLight,
    surface: blush,
    onSurface: ink,
    onSurfaceVariant: inkMuted,
    surfaceContainerLowest: Color(0xFFFFFAF7),
    surfaceContainerLow: Color(0xFFF8EDE8),
    surfaceContainer: blushContainer,
    surfaceContainerHigh: blushContainerHigh,
    surfaceContainerHighest: Color(0xFFE1CFC7),
    outline: outlineLight,
    outlineVariant: outlineVariantLight,
    inverseSurface: Color(0xFF2B3A3F),
    onInverseSurface: Color(0xFFF1F5F5),
    inversePrimary: ember,
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );

  /// The dark colour scheme.
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: ember,
    onPrimary: onEmber,
    primaryContainer: emberContainerDark,
    onPrimaryContainer: onEmberContainerDark,
    secondary: verdigris,
    onSecondary: onVerdigris,
    secondaryContainer: verdigrisContainerDark,
    onSecondaryContainer: onVerdigrisContainerDark,
    tertiary: Color(0xFF9DC3EE),
    onTertiary: Color(0xFF0B2338),
    tertiaryContainer: Color(0xFF2B4B6B),
    onTertiaryContainer: Color(0xFFD3E4F7),
    error: errorDark,
    onError: Color(0xFF601410),
    errorContainer: errorContainerDark,
    onErrorContainer: onErrorContainerDark,
    surface: slate,
    onSurface: daylight,
    onSurfaceVariant: daylightMuted,
    surfaceContainerLowest: Color(0xFF0C161B),
    surfaceContainerLow: Color(0xFF16232A),
    surfaceContainer: slateContainer,
    surfaceContainerHigh: slateContainerHigh,
    surfaceContainerHighest: Color(0xFF2D444E),
    outline: outlineDark,
    outlineVariant: outlineVariantDark,
    inverseSurface: daylight,
    onInverseSurface: Color(0xFF17242A),
    inversePrimary: emberDeep,
    scrim: Color(0xFF000000),
    shadow: Color(0xFF000000),
  );
}
