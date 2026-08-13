import 'package:flutter/material.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';

/// The product's type system.
///
/// ## Why typography is language-dependent here
///
/// A bilingual product cannot use one type scale for both of its languages.
/// Persian and Latin script differ in vertical proportion: at an identical
/// point size Persian sits optically smaller and its ascenders and descenders
/// need more room, so a scale tuned on English produces cramped, undersized
/// Persian. [AppTypography.forLanguage] therefore builds the scale from the
/// language, applying a modest size lift and a more generous leading to
/// Persian rather than shipping one compromise scale for both.
///
/// Content is set in a serif and interface chrome in a sans, so that reading
/// and operating the app feel like different activities — the way they do in a
/// well-made book with a well-made index.
abstract final class AppTypography {
  /// The English reading face.
  static const String serifFamily = 'Spectral';

  /// The Persian face, used for both content and chrome.
  static const String persianFamily = 'Vazirmatn';

  /// Point-size multiplier applied to Persian text so it reads at the same
  /// optical size as the Latin scale.
  static const double persianSizeFactor = 1.06;

  /// Extra leading added to Persian, whose diacritics and descenders need more
  /// vertical room than Latin at the same size.
  static const double persianLeadingBonus = 0.14;

  /// The font family used for body and heading content in [language].
  static String contentFamily(AppLanguage language) =>
      language == AppLanguage.fa ? persianFamily : serifFamily;

  /// The sans-serif used for English interface chrome.
  ///
  /// Named explicitly rather than left `null`. A `TextStyle` with no family
  /// inherits one from the ambient `DefaultTextStyle`, which inside a `Material`
  /// is the content serif — so leaving it unset silently set the whole interface
  /// in Spectral and lost the distinction between reading and operating the app.
  static const String sansFamily = 'Roboto';

  /// The font family used for buttons, labels, tabs and other chrome.
  ///
  /// Persian chrome uses Vazirmatn for both roles, because the Persian type
  /// landscape has no serif companion to Vazirmatn worth pairing it with, and a
  /// mismatched pairing reads worse than a single well-drawn family.
  static String chromeFamily(AppLanguage language) =>
      language == AppLanguage.fa ? persianFamily : sansFamily;

  static double _size(AppLanguage language, double base) =>
      language == AppLanguage.fa ? base * persianSizeFactor : base;

  static double _height(AppLanguage language, double base) =>
      language == AppLanguage.fa ? base + persianLeadingBonus : base;

  /// Builds the full Material text theme for [language].
  static TextTheme forLanguage(AppLanguage language) {
    final content = contentFamily(language);
    final chrome = chromeFamily(language);

    TextStyle contentStyle({
      required double size,
      required double height,
      required FontWeight weight,
      double letterSpacing = 0,
    }) => TextStyle(
      fontFamily: content,
      fontSize: _size(language, size),
      height: _height(language, height),
      fontWeight: weight,
      letterSpacing: language == AppLanguage.fa ? 0 : letterSpacing,
    );

    TextStyle chromeStyle({
      required double size,
      required double height,
      required FontWeight weight,
      double letterSpacing = 0,
    }) => TextStyle(
      fontFamily: chrome,
      fontSize: _size(language, size),
      height: _height(language, height),
      fontWeight: weight,
      // Letter-spacing on Persian breaks the cursive joins between letters and
      // must always be zero, whatever the Latin scale asks for.
      letterSpacing: language == AppLanguage.fa ? 0 : letterSpacing,
    );

    return TextTheme(
      // Display — reserved for a screen's single emotional focal point.
      displayLarge: contentStyle(
        size: 52,
        height: 1.12,
        weight: FontWeight.w600,
        letterSpacing: -0.5,
      ),
      displayMedium: contentStyle(
        size: 42,
        height: 1.16,
        weight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      displaySmall: contentStyle(
        size: 34,
        height: 1.2,
        weight: FontWeight.w600,
        letterSpacing: -0.2,
      ),

      // Headline — section and entity titles.
      headlineLarge: contentStyle(
        size: 30,
        height: 1.24,
        weight: FontWeight.w600,
      ),
      headlineMedium: contentStyle(
        size: 25,
        height: 1.28,
        weight: FontWeight.w600,
      ),
      headlineSmall: contentStyle(
        size: 21,
        height: 1.32,
        weight: FontWeight.w600,
      ),

      // Title — card headings and list leaders.
      titleLarge: contentStyle(size: 19, height: 1.36, weight: FontWeight.w600),
      titleMedium: contentStyle(
        size: 16.5,
        height: 1.4,
        weight: FontWeight.w600,
      ),
      titleSmall: contentStyle(
        size: 14.5,
        height: 1.42,
        weight: FontWeight.w600,
      ),

      // Body — prose. bodyLarge is the default reading size.
      bodyLarge: contentStyle(size: 17, height: 1.62, weight: FontWeight.w400),
      bodyMedium: contentStyle(size: 15, height: 1.58, weight: FontWeight.w400),
      bodySmall: contentStyle(size: 13.5, height: 1.5, weight: FontWeight.w400),

      // Label — chrome. Set in the sans so controls read as controls.
      labelLarge: chromeStyle(
        size: 15,
        height: 1.3,
        weight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: chromeStyle(
        size: 13,
        height: 1.3,
        weight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      labelSmall: chromeStyle(
        size: 11.5,
        height: 1.3,
        weight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }

  /// The style for a displayed quotation.
  static TextStyle quote(AppLanguage language) => TextStyle(
    fontFamily: contentFamily(language),
    fontSize: _size(language, 20),
    height: _height(language, 1.56),
    fontWeight: FontWeight.w400,
    // Latin quotations are set in italic by convention; Persian has no italic
    // and slanting it is a typographic error, so Persian stays upright.
    fontStyle: language == AppLanguage.fa ? FontStyle.normal : FontStyle.italic,
  );

  /// The style for a source citation beneath a quotation or claim.
  static TextStyle citation(AppLanguage language) => TextStyle(
    fontFamily: contentFamily(language),
    fontSize: _size(language, 13),
    height: _height(language, 1.45),
    fontWeight: FontWeight.w400,
  );

  /// The style for long-form reading text, at the reader's chosen [scale].
  ///
  /// The reader controls size in the reading view, so this takes an explicit
  /// multiplier rather than reading from the ambient text scaler.
  static TextStyle reading(AppLanguage language, {double scale = 1.0}) =>
      TextStyle(
        fontFamily: contentFamily(language),
        fontSize: _size(language, 17.5) * scale,
        height: _height(language, 1.72),
        fontWeight: FontWeight.w400,
      );
}
