import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';

/// Guards the type system against the two ways it silently breaks.
///
/// The first is a missing glyph. This product sets Greek names in English
/// sentences and Arabic names in both languages, and no bundled face covers
/// Latin, Arabic and polytonic Greek at once. A style without a fallback chain
/// renders an empty box — which analysis, the type checker and every widget
/// test will happily accept.
///
/// The second is Persian typography being treated as English typography with
/// different words in it.
void main() {
  /// Every style in the Material text theme, named for useful failures.
  Map<String, TextStyle> stylesOf(AppLanguage language) {
    final theme = AppTypography.forLanguage(language);
    return <String, TextStyle>{
      'displayLarge': theme.displayLarge!,
      'displayMedium': theme.displayMedium!,
      'displaySmall': theme.displaySmall!,
      'headlineLarge': theme.headlineLarge!,
      'headlineMedium': theme.headlineMedium!,
      'headlineSmall': theme.headlineSmall!,
      'titleLarge': theme.titleLarge!,
      'titleMedium': theme.titleMedium!,
      'titleSmall': theme.titleSmall!,
      'bodyLarge': theme.bodyLarge!,
      'bodyMedium': theme.bodyMedium!,
      'bodySmall': theme.bodySmall!,
      'labelLarge': theme.labelLarge!,
      'labelMedium': theme.labelMedium!,
      'labelSmall': theme.labelSmall!,
    };
  }

  group('Script coverage', () {
    test('every style in every language declares a fallback chain', () {
      for (final language in AppLanguage.values) {
        stylesOf(language).forEach((name, style) {
          expect(
            style.fontFamilyFallback,
            isNotEmpty,
            reason:
                '$name in ${language.code} has no fallback, so any character '
                'missing from ${style.fontFamily} will render as an empty box',
          );
        });
      }
    });

    test('the standalone styles declare one too', () {
      for (final language in AppLanguage.values) {
        expect(AppTypography.quote(language).fontFamilyFallback, isNotEmpty);
        expect(AppTypography.citation(language).fontFamilyFallback, isNotEmpty);
        expect(AppTypography.reading(language).fontFamilyFallback, isNotEmpty);
      }
    });

    test('English can reach Greek and Arabic glyphs', () {
      final fallbacks = AppTypography.fallbacksFor(AppLanguage.en);
      expect(
        fallbacks,
        contains(AppTypography.greekFamily),
        reason: 'Ἐπίκτητος appears in the English interface',
      );
      expect(
        fallbacks,
        contains(AppTypography.persianFamily),
        reason: 'ابن سينا appears in the English interface',
      );
    });

    test('Persian can reach Latin and Greek glyphs', () {
      final fallbacks = AppTypography.fallbacksFor(AppLanguage.fa);
      expect(fallbacks, contains(AppTypography.serifFamily));
      expect(fallbacks, contains(AppTypography.greekFamily));
    });

    test('a fallback chain never begins with the family it backs up', () {
      // Stated per chain, because there are two of them. Chrome and content
      // name different primaries and share one fallback list, so a family can
      // be the primary of one chain and a necessary fallback for the other:
      // Spectral is the English content face and is in the list because
      // English chrome is Roboto, which has no ʻokina, no ṣ and no ḥ.
      //
      // What is actually wasted is a chain whose first fallback is the face it
      // just tried, which is the shape this was written for.
      for (final language in AppLanguage.values) {
        final fallbacks = AppTypography.fallbacksFor(language);
        for (final primary in <String>{
          AppTypography.chromeFamily(language),
          AppTypography.contentFamily(language),
        }) {
          expect(
            fallbacks.first,
            isNot(primary),
            reason:
                'the ${language.code} chain tries $primary and then falls '
                'back to it',
          );
        }
      }
    });

    test('no face is listed twice in one chain', () {
      // The other half of the same waste: a duplicate later in the list is a
      // lookup that can never succeed, because the first copy already failed.
      for (final language in AppLanguage.values) {
        final fallbacks = AppTypography.fallbacksFor(language);
        expect(
          fallbacks.toSet(),
          hasLength(fallbacks.length),
          reason: 'the ${language.code} chain repeats a face: $fallbacks',
        );
      }
    });
  });

  group('Persian typography', () {
    test('is set larger than the Latin scale at the same step', () {
      final english = stylesOf(AppLanguage.en);
      final persian = stylesOf(AppLanguage.fa);
      for (final name in english.keys) {
        expect(
          persian[name]!.fontSize,
          greaterThan(english[name]!.fontSize!),
          reason: '$name is not lifted for Persian',
        );
      }
    });

    test('is given more leading than the Latin scale', () {
      final english = stylesOf(AppLanguage.en);
      final persian = stylesOf(AppLanguage.fa);
      for (final name in english.keys) {
        expect(
          persian[name]!.height,
          greaterThan(english[name]!.height!),
          reason: '$name has no extra leading for Persian',
        );
      }
    });

    test('never carries letter-spacing', () {
      // Letter-spacing breaks the cursive joins between Persian letters, so it
      // must be zero even where the Latin scale asks for it.
      for (final entry in stylesOf(AppLanguage.fa).entries) {
        expect(
          entry.value.letterSpacing ?? 0,
          0,
          reason: '${entry.key} would break Persian letter joins',
        );
      }
    });

    test('quotations are not slanted', () {
      // Persian has no italic; slanting it is a typographic error rather than
      // an emphasis.
      expect(
        AppTypography.quote(AppLanguage.fa).fontStyle,
        isNot(FontStyle.italic),
      );
      expect(AppTypography.quote(AppLanguage.en).fontStyle, FontStyle.italic);
    });
  });

  group('Reading and chrome are visibly different', () {
    test('English chrome is a sans and English content is a serif', () {
      expect(
        AppTypography.chromeFamily(AppLanguage.en),
        isNot(AppTypography.contentFamily(AppLanguage.en)),
      );
    });

    test('chrome never resolves to null, which would inherit the serif', () {
      // A null family inherits from the ambient DefaultTextStyle — inside a
      // Material, that is the content serif, which silently sets the whole
      // interface in it.
      for (final language in AppLanguage.values) {
        expect(AppTypography.chromeFamily(language), isNotEmpty);
      }
    });

    test('the reading style scales with the reader\'s chosen size', () {
      final base = AppTypography.reading(AppLanguage.en).fontSize!;
      final larger = AppTypography.reading(
        AppLanguage.en,
        scale: 1.5,
      ).fontSize!;
      expect(larger, closeTo(base * 1.5, 0.001));
    });
  });
}
