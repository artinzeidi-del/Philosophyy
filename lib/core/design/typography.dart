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

  /// The Persian interface face.
  ///
  /// Vazirmatn is a screen-drawn geometric sans and is the right thing for
  /// chrome. It is not the right thing for a page of philosophy.
  static const String persianFamily = 'Vazirmatn';

  /// The Persian reading face.
  ///
  /// Vazirmatn, the same face as the chrome — deliberately, and against the
  /// symmetry with the English side.
  ///
  /// The argument for naskh was that Persian books are set in naskh and that
  /// content and chrome should not feel like the same activity. That is a real
  /// argument about texture, and it lost to a measurement. Set beside each
  /// other at the same point size, Noto Naskh Arabic renders visibly smaller,
  /// thinner and tighter than Vazirmatn: on a phone the metadata line at 13
  /// went grey and the body ran together. Persian readers are this product's
  /// primary audience, and a bookish texture is not worth paying for in
  /// legibility.
  ///
  /// The split between reading and operating survives in weight, size and
  /// leading rather than in the family. Amiri was already rejected for the
  /// harder reason — it applies Arabic conventions to Persian, dotting the
  /// final yeh in آتنی‌ای where Persian writes it bare — and letterforms that
  /// are wrong for the language are not a style choice.
  ///
  /// Naskh stays in the fallback chain, where it sets Arabic-script text that
  /// Vazirmatn has no glyph for.
  static const String persianReadingFamily = 'Vazirmatn';

  /// The naskh face, kept for fallback and for Arabic set inside English.
  static const String naskhFamily = 'NotoNaskhArabic';

  /// The polytonic Greek face.
  ///
  /// Only ever reached through [fallbacksFor]; nothing is set in it directly.
  static const String greekFamily = 'GFSDidot';

  /// The Chinese face.
  ///
  /// Three CJK faces rather than one: Han unification gives Chinese, Japanese
  /// and Korean the same codepoint for characters they draw differently, and a
  /// single face would set every Japanese name in Chinese letterforms.
  static const String chineseFamily = 'NotoSerifSC';

  /// The Japanese face, which also supplies kana.
  static const String japaneseFamily = 'NotoSerifJP';

  /// The Korean face, which supplies hangul and Korean hanja forms.
  static const String koreanFamily = 'NotoSerifKR';

  /// The Devanagari face, for Sanskrit and the Indian traditions.
  static const String devanagariFamily = 'NotoSerifDevanagari';

  /// The Hebrew face, for the Jewish tradition.
  static const String hebrewFamily = 'NotoSerifHebrew';

  /// The Ethiopic face, for the Ethiopian tradition.
  static const String ethiopicFamily = 'NotoSerifEthiopic';

  /// The Tibetan face, for the Tibetan Buddhist tradition.
  static const String tibetanFamily = 'NotoSerifTibetan';

  /// The Bengali face, which Devanagari does not cover.
  static const String bengaliFamily = 'NotoSerifBengali';

  /// The hieroglyphic face, for the ancient Egyptian tradition.
  static const String hieroglyphFamily = 'NotoSansEgyptianHieroglyphs';

  /// The faces that exist only to print names in their own script.
  ///
  /// Grouped because they are always reached the same way — through the
  /// fallback chain, never set directly — and because the list of scripts the
  /// corpus can print should be one thing to add to rather than four.
  static const List<String> scriptFamilies = <String>[
    devanagariFamily,
    bengaliFamily,
    hebrewFamily,
    ethiopicFamily,
    tibetanFamily,
    hieroglyphFamily,
  ];

  /// The CJK faces in fallback order.
  ///
  /// Ordered by how much content each currently serves, which is the only
  /// honest basis available: a fallback chain resolves a shared codepoint to
  /// whichever face comes first, so for Han characters the three cannot all
  /// win. Kana and hangul are unambiguous whatever the order, because only one
  /// face carries them.
  static const List<String> cjkFamilies = <String>[
    chineseFamily,
    japaneseFamily,
    koreanFamily,
  ];

  /// Point-size multiplier applied to Persian text so it reads at the same
  /// optical size as the Latin scale.
  ///
  /// The number belongs to the face, not to the language: 1.06 was measured
  /// against naskh, and carried over to Vazirmatn it overshot, because
  /// Vazirmatn is the optically larger of the two. Set against Spectral at the
  /// same nominal size, 1.03 is the match. Changing [persianReadingFamily]
  /// means measuring this again.
  static const double persianSizeFactor = 1.03;

  /// Extra leading added to Persian, whose diacritics and descenders need more
  /// vertical room than Latin at the same size.
  static const double persianLeadingBonus = 0.14;

  /// The font family used for body and heading content in [language].
  static String contentFamily(AppLanguage language) =>
      language == AppLanguage.fa ? persianReadingFamily : serifFamily;

  /// The sans-serif used for English interface chrome.
  ///
  /// Named explicitly rather than left `null`. A `TextStyle` with no family
  /// inherits one from the ambient `DefaultTextStyle`, which inside a `Material`
  /// is the content serif — so leaving it unset silently set the whole interface
  /// in Spectral and lost the distinction between reading and operating the app.
  static const String sansFamily = 'Roboto';

  /// The font family used for buttons, labels, tabs and other chrome.
  ///
  /// English splits chrome from content by family, Roboto against Spectral.
  /// Persian uses one face for both — see [persianReadingFamily] — and makes
  /// the same distinction with weight and leading instead.
  static String chromeFamily(AppLanguage language) =>
      language == AppLanguage.fa ? persianFamily : sansFamily;

  /// The faces to fall back to when the primary one has no glyph.
  ///
  /// This product routinely sets one script inside another: a Greek name in an
  /// English sentence, an Arabic name in a Persian one, a Chinese name in
  /// either, a Sanskrit transliteration anywhere. No single bundled face covers
  /// Latin, Arabic, polytonic Greek and CJK, so without an explicit chain the
  /// reader gets empty boxes — and a reference work that cannot print the name
  /// it is describing has failed at its first job.
  static List<String> fallbacksFor(AppLanguage language) =>
      language == AppLanguage.fa
      ? const <String>[
          // Naskh behind Vazirmatn: it carries the Arabic-script letters and
          // vowel marks Vazirmatn has no glyph for, which is what a fallback
          // is for now that it is no longer the primary face.
          naskhFamily,
          serifFamily,
          greekFamily,
          ...scriptFamilies,
          ...cjkFamilies,
        ]
      : const <String>[
          greekFamily,
          // Naskh ahead of the UI sans, so an Arabic-script name inside an
          // English sentence is set in a face that belongs next to a serif.
          naskhFamily,
          persianFamily,
          ...scriptFamilies,
          ...cjkFamilies,
        ];

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
      fontFamilyFallback: fallbacksFor(language),
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
      fontFamilyFallback: fallbacksFor(language),
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
    fontFamilyFallback: fallbacksFor(language),
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
    fontFamilyFallback: fallbacksFor(language),
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
        fontFamilyFallback: fallbacksFor(language),
        fontSize: _size(language, 17.5) * scale,
        height: _height(language, 1.72),
        fontWeight: FontWeight.w400,
      );
}
