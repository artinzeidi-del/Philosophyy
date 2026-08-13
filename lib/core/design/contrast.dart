import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.1 contrast mathematics.
///
/// Accessibility is part of the definition of done, which means contrast has to
/// be something the build can check rather than something a designer eyeballs.
/// These functions implement the published formulas so the palette can be
/// asserted against them in tests.
abstract final class Contrast {
  /// The minimum ratio WCAG 2.1 requires of normal-size body text at level AA.
  static const double aaNormalText = 4.5;

  /// The minimum ratio required of large text (>=18pt, or >=14pt bold) at AA.
  static const double aaLargeText = 3.0;

  /// The minimum ratio required of user-interface components and graphical
  /// objects that convey meaning, at AA.
  static const double aaNonText = 3.0;

  /// The minimum ratio required of normal-size body text at level AAA.
  static const double aaaNormalText = 7.0;

  /// Relative luminance of [color] per WCAG 2.1, in the range 0.0–1.0.
  ///
  /// The colour is treated as fully opaque; composite translucent colours onto
  /// their background with [composite] before measuring them.
  static double relativeLuminance(Color color) {
    double channel(double component) => component <= 0.03928
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4).toDouble();

    return 0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);
  }

  /// The contrast ratio between two opaque colours, from 1.0 (identical) to
  /// 21.0 (black against white). Order does not matter.
  static double ratio(Color a, Color b) {
    final luminanceA = relativeLuminance(a);
    final luminanceB = relativeLuminance(b);
    final lighter = math.max(luminanceA, luminanceB);
    final darker = math.min(luminanceA, luminanceB);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Flattens a possibly translucent [foreground] onto an opaque [background],
  /// which is what the eye actually sees and therefore what must be measured.
  static Color composite(Color foreground, Color background) {
    final alpha = foreground.a;
    if (alpha >= 1.0) return foreground;
    return Color.from(
      alpha: 1.0,
      red: foreground.r * alpha + background.r * (1 - alpha),
      green: foreground.g * alpha + background.g * (1 - alpha),
      blue: foreground.b * alpha + background.b * (1 - alpha),
    );
  }

  /// Whether [foreground] on [background] satisfies AA for body text.
  static bool meetsAaNormalText(Color foreground, Color background) =>
      ratio(composite(foreground, background), background) >= aaNormalText;

  /// Whether [foreground] on [background] satisfies AA for large text.
  static bool meetsAaLargeText(Color foreground, Color background) =>
      ratio(composite(foreground, background), background) >= aaLargeText;
}
