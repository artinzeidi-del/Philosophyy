import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/data/content/content_mappers.dart';
import 'package:philosophyy/data/content/json_reader.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// Holds the authored-string type to the two things it exists to guarantee.
///
/// The first is honesty: a Persian reader must never be shown English text
/// dressed up as a translation, so a missing or blank translation has to be
/// distinguishable from a real one at every point that asks.
///
/// The second is that the type does not cap what content can say. It used to:
/// two named fields meant an entry could not carry a third language at all,
/// even as data waiting for an interface to catch up.
void main() {
  group('Resolving', () {
    const bilingual = LocalizedText(en: 'Ethics', fa: 'اخلاق');
    const englishOnly = LocalizedText(en: 'Ethics');

    test('returns the requested language when it has been authored', () {
      expect(bilingual.resolve(AppLanguage.en), 'Ethics');
      expect(bilingual.resolve(AppLanguage.fa), 'اخلاق');
    });

    test('falls back to English when a translation is missing', () {
      expect(englishOnly.resolve(AppLanguage.fa), 'Ethics');
    });

    test('reports which language the resolved text is actually in', () {
      // The interface needs this to set the right font and direction. Rendering
      // English text in a right-to-left Persian style is how a fallback turns
      // into a visual mess.
      expect(bilingual.resolvedLanguage(AppLanguage.fa), AppLanguage.fa);
      expect(englishOnly.resolvedLanguage(AppLanguage.fa), AppLanguage.en);
    });

    test('a blank translation counts as no translation', () {
      // An empty string is an untranslated entry. Treating it as translated is
      // how a reader ends up staring at an empty heading.
      const blank = LocalizedText(en: 'Ethics', fa: '   ');
      expect(blank.isTranslated, isFalse);
      expect(blank.resolve(AppLanguage.fa), 'Ethics');
      expect(blank.hasTranslationFor(AppLanguage.fa), isFalse);
    });
  });

  group('Languages beyond the two the interface ships', () {
    const withArabic = LocalizedText(
      en: 'Emptiness',
      fa: 'تهیت',
      translations: <String, String>{'ar': 'الخلاء', 'fr': 'Vacuité'},
    );

    test('are carried rather than dropped', () {
      expect(withArabic.forCode('ar'), 'الخلاء');
      expect(withArabic.forCode('fr'), 'Vacuité');
    });

    test('are listed among the authored languages', () {
      expect(
        withArabic.languages,
        containsAll(<String>['en', 'fa', 'ar', 'fr']),
      );
    });

    test('are indexed for search', () {
      // A reader who types a name in a language the app cannot yet display is
      // still looking for exactly this entry.
      expect(
        withArabic.allVariants,
        containsAll(<String>['Emptiness', 'تهیت', 'الخلاء', 'Vacuité']),
      );
    });

    test('an unauthored language reports nothing rather than empty text', () {
      expect(withArabic.forCode('de'), isNull);
    });
  });

  group('Reading from content', () {
    LocalizedText read(Map<String, Object?> json) =>
        ContentMappers.localizedText(JsonReader.root(json, file: 'test'));

    test('takes every subtag the file offers', () {
      // The claim this refactor rests on: authoring a third language is a
      // content change, with no Dart to edit.
      final text = read(<String, Object?>{
        'en': 'Emptiness',
        'fa': 'تهیت',
        'ar': 'الخلاء',
      });
      expect(text.forCode('ar'), 'الخلاء');
      expect(text.resolve(AppLanguage.en), 'Emptiness');
    });

    test('requires English', () {
      expect(
        () => read(<String, Object?>{'fa': 'تهیت'}),
        throwsA(isA<Object>()),
      );
    });

    test('rejects a blank translation instead of storing it', () {
      // Blank fields in authored content are always a mistake, and the mapper
      // is where a mistake should stop.
      expect(
        () => read(<String, Object?>{'en': 'Emptiness', 'ar': '  '}),
        throwsA(isA<Object>()),
      );
    });

    test('accepts a script or region subtag', () {
      final text = read(<String, Object?>{
        'en': 'Emptiness',
        'zh-Hant': '空性',
        'pt-BR': 'Vacuidade',
      });
      expect(text.forCode('zh-Hant'), '空性');
      expect(text.forCode('pt-BR'), 'Vacuidade');
    });

    test('rejects a field that is not a language subtag', () {
      // A mistyped or misplaced field inside a localized object would otherwise
      // be stored as a translation into a language that does not exist.
      expect(
        () => read(<String, Object?>{'en': 'Emptiness', 'note': 'oops'}),
        throwsA(isA<Object>()),
      );
    });

    test('rejects a non-string translation', () {
      expect(
        () => read(<String, Object?>{'en': 'Emptiness', 'ar': 42}),
        throwsA(isA<Object>()),
      );
    });
  });

  group('Equality', () {
    test('two identically authored strings are equal', () {
      expect(
        const LocalizedText(
          en: 'Ethics',
          fa: 'اخلاق',
          translations: <String, String>{'ar': 'أخلاق'},
        ),
        const LocalizedText(
          en: 'Ethics',
          fa: 'اخلاق',
          translations: <String, String>{'ar': 'أخلاق'},
        ),
      );
    });

    test('an extra translation makes them different', () {
      // Equality is used to detect content changes; a translation added and not
      // noticed would be a silent loss.
      expect(
        const LocalizedText(en: 'Ethics', fa: 'اخلاق'),
        isNot(
          const LocalizedText(
            en: 'Ethics',
            fa: 'اخلاق',
            translations: <String, String>{'ar': 'أخلاق'},
          ),
        ),
      );
    });

    test('equal strings hash together', () {
      expect(
        const LocalizedText(
          en: 'Ethics',
          translations: <String, String>{'ar': 'أخلاق'},
        ).hashCode,
        const LocalizedText(
          en: 'Ethics',
          translations: <String, String>{'ar': 'أخلاق'},
        ).hashCode,
      );
    });
  });
}
