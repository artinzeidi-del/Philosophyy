import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/search/text_normalizer.dart';

/// Every case here is a query a real reader would plausibly type.
///
/// The point of the normaliser is that all the ways of writing one name collapse
/// to a single key, so the tests are written as "these different inputs must
/// produce the same output" rather than as assertions about implementation.
void main() {
  group('Persian and Arabic folding', () {
    test('Arabic and Persian yeh fold together', () {
      // The same name typed on an Arabic keyboard and a Persian one.
      expect(
        TextNormalizer.normalize('ابن سينا'),
        TextNormalizer.normalize('ابن سینا'),
      );
    });

    test('Arabic kaf folds to Persian keheh', () {
      expect(
        TextNormalizer.normalize('كتاب'),
        TextNormalizer.normalize('کتاب'),
      );
    });

    test('vowel marks are ignored', () {
      expect(
        TextNormalizer.normalize('مُحَمَّد'),
        TextNormalizer.normalize('محمد'),
      );
    });

    test('alef with hamza or madda folds to plain alef', () {
      final plain = TextNormalizer.normalize('اسلام');
      expect(TextNormalizer.normalize('أسلام'), plain);
      expect(TextNormalizer.normalize('إسلام'), plain);
      expect(TextNormalizer.normalize('آسلام'), plain);
    });

    test('the zero-width non-joiner reads as a space', () {
      // A reader types the space; the content is authored with the ZWNJ.
      expect(
        TextNormalizer.normalize('ابن\u{200C}سینا'),
        TextNormalizer.normalize('ابن سینا'),
      );
    });

    test('teh marbuta folds to heh', () {
      expect(
        TextNormalizer.normalize('فلسفة'),
        TextNormalizer.normalize('فلسفه'),
      );
    });

    test('the kashida used to stretch a line is ignored', () {
      expect(
        TextNormalizer.normalize('فلســـفه'),
        TextNormalizer.normalize('فلسفه'),
      );
    });

    test('Persian and Arabic-Indic digits become Latin numerals', () {
      expect(TextNormalizer.normalize('۱۳۹۹'), '1399');
      expect(TextNormalizer.normalize('١٣٩٩'), '1399');
    });
  });

  group('Latin transliteration folding', () {
    test('macrons and under-dots fold to plain letters', () {
      expect(TextNormalizer.normalize('Ibn Sīnā'), 'ibn sina');
      expect(TextNormalizer.normalize('Muḥammad'), 'muhammad');
      expect(TextNormalizer.normalize('Śaṅkara'), 'sankara');
      expect(TextNormalizer.normalize('Mullā Ṣadrā'), 'mulla sadra');
    });

    test('the transliteration apostrophes disappear rather than splitting', () {
      // ʿayn and hamza are transliteration marks, not word boundaries.
      expect(TextNormalizer.normalize('Farabi'), 'farabi');
      expect(TextNormalizer.normalize('al-Fārābī'), 'al-farabi');
      expect(TextNormalizer.tokenize('Ashʿarī'), <String>['ashari']);
    });

    test('European diacritics fold', () {
      expect(TextNormalizer.normalize('Kierkegaard'), 'kierkegaard');
      expect(TextNormalizer.normalize('Zoë'), 'zoe');
      expect(TextNormalizer.normalize('Gödel'), 'godel');
      expect(TextNormalizer.normalize('Łukasiewicz'), 'lukasiewicz');
    });

    test('ligatures expand', () {
      expect(TextNormalizer.normalize('Æsthetics'), 'aesthetics');
      expect(TextNormalizer.normalize('Straße'), 'strasse');
    });
  });

  group('Greek folding', () {
    test('accented Greek folds to unaccented', () {
      expect(TextNormalizer.normalize('εὐδαιμονία'), 'ευδαιμονια');
      expect(TextNormalizer.normalize('ἀρετή'), 'αρετη');
      expect(TextNormalizer.normalize('ψυχή'), 'ψυχη');
    });

    test('final sigma matches medial sigma', () {
      expect(TextNormalizer.normalize('λόγος'), 'λογοσ');
      expect(
        TextNormalizer.normalize('λόγος'),
        TextNormalizer.normalize('λογοσ'),
      );
    });
  });

  group('Tokenisation', () {
    test('splits on punctuation and collapses whitespace', () {
      expect(TextNormalizer.tokenize('Plato, Republic  514a'), <String>[
        'plato',
        'republic',
        '514a',
      ]);
    });

    test('produces no empty tokens from stray punctuation', () {
      expect(TextNormalizer.tokenize('  ...,  '), isEmpty);
      expect(TextNormalizer.tokenize(''), isEmpty);
      expect(TextNormalizer.tokenize('—— what is justice? ——'), <String>[
        'what',
        'is',
        'justice',
      ]);
    });

    test('keeps Persian words intact', () {
      expect(TextNormalizer.tokenize('فلسفه اسلامی'), <String>[
        'فلسفه',
        'اسلامی',
      ]);
    });

    test('splits mixed-script text correctly', () {
      expect(TextNormalizer.tokenize('Avicenna / ابن‌سینا'), <String>[
        'avicenna',
        'ابن',
        'سینا',
      ]);
    });
  });

  group('Script detection', () {
    test('recognises Arabic script', () {
      expect(TextNormalizer.containsArabicScript('ابن سینا'), isTrue);
      expect(TextNormalizer.containsArabicScript('فلسفه'), isTrue);
    });

    test('does not misfire on Latin or Greek', () {
      expect(TextNormalizer.containsArabicScript('Avicenna'), isFalse);
      expect(TextNormalizer.containsArabicScript('εὐδαιμονία'), isFalse);
      expect(TextNormalizer.containsArabicScript(''), isFalse);
    });
  });

  group('Robustness', () {
    test('empty and whitespace-only input normalise to empty', () {
      expect(TextNormalizer.normalize(''), '');
      expect(TextNormalizer.normalize('   '), '');
      expect(TextNormalizer.normalize('\n\t'), '');
    });

    test('normalisation is idempotent', () {
      const inputs = <String>[
        'Ibn Sīnā',
        'ابن‌سینا',
        'εὐδαιμονία',
        'Mullā Ṣadrā',
        '۱۳۹۹',
      ];
      for (final input in inputs) {
        final once = TextNormalizer.normalize(input);
        expect(
          TextNormalizer.normalize(once),
          once,
          reason: 'normalising "$input" twice changed the result',
        );
      }
    });
  });

  group('Every Latin name in the corpus reaches plain letters', () {
    test('a name written in Latin script folds to ASCII', () {
      // The folding table is written by hand, so it covers the diacritics
      // somebody thought of. Three families had been missed. The pinyin third
      // tone was there for «ě» and not for «ǎ ǐ ǒ ǔ», so Lǎozǐ, Kǒngzǐ and Lǐ
      // could not be found by typing Laozi, Kongzi or Li. Vietnamese stacks a
      // tone on a vowel that already carries a mark and Unicode gives each
      // combination its own code point, so nothing in Trần Nhân Tông
      // decomposed to anything in the table. And the schwa of Zärʾa Yaʿəqob
      // was not there at all.
      //
      // The rule is the test: whatever alphabet a transliteration borrows
      // from, a reader with an English keyboard has to be able to type it.
      // A name in its own script — Greek, Cyrillic, Arabic, CJK — is
      // deliberately left alone, because a reader searching in that script
      // should find it there.
      final latin = RegExp(
        r'^[\p{Script=Latin}\p{M}\p{N}\p{P}\p{Z}]+$',
        unicode: true,
      );
      final letterOrMark = RegExp(r'[\p{L}\p{M}]', unicode: true);
      final unreachable = <String>{};

      void walk(Object? node) {
        if (node is Map) {
          for (final entry in node.entries) {
            walk(entry.value);
          }
        } else if (node is List) {
          for (final value in node) {
            walk(value);
          }
        } else if (node is String && node.length < 80 && latin.hasMatch(node)) {
          final folded = TextNormalizer.normalize(node);
          for (final rune in folded.runes) {
            // Letters only. Punctuation survives normalize by design and is
            // removed a step later, by tokenize, so a section sign in a
            // locator is not a name a reader cannot type.
            if (rune > 127 &&
                letterOrMark.hasMatch(String.fromCharCode(rune))) {
              unreachable.add(
                '"$node" still holds U+${rune.toRadixString(16).toUpperCase()} '
                '"${String.fromCharCode(rune)}" after folding',
              );
            }
          }
        }
      }

      for (final file in Directory(
        'assets/content',
      ).listSync().whereType<File>()) {
        walk(jsonDecode(file.readAsStringSync()));
      }

      expect(unreachable, isEmpty, reason: unreachable.join('\n'));
    });
  });
}
