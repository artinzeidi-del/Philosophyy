import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds the Persian text to the standard a reader actually needs.
///
/// This product is meant for anyone, not only for people who already read
/// philosophy. Persian makes that easy to get wrong in two ways, and both are
/// invisible unless something checks.
///
/// The first is orthography. A missing or misplaced zero-width non-joiner is
/// not a typo a spell-checker catches — the words still render, they just
/// render wrong, and only a Persian reader notices.
///
/// The second is register. Persian has a literary layer that is perfectly
/// correct and quietly excludes people: `برهان آورد` where `استدلال کرد` says
/// the same thing, `واپسین` where `آخرین` does. Depth belongs in what the
/// sentence claims, not in how ornate the vocabulary is.
void main() {
  /// Every string of authored **Persian** that ships, with the field it came
  /// from.
  ///
  /// Scoped by field name rather than by "does it contain Arabic-script
  /// characters", because the corpus deliberately carries Arabic — original
  /// titles, and now an `ar` translation alongside the Persian one. Arabic
  /// spelled by Persian rules would be simply wrong, so the first version of
  /// this test, which checked every Arabic-script string it could find,
  /// reported the Arabic originals as errors.
  final strings = <({String file, String path, String text})>[];

  setUpAll(() {
    void walk(Object? node, String file, String path, String? key) {
      if (node is Map<String, Object?>) {
        for (final entry in node.entries) {
          walk(entry.value, file, '$path.${entry.key}', entry.key);
        }
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) {
          walk(node[i], file, '$path[$i]', key);
        }
      } else if (node is String && _isPersianField(file, key)) {
        strings.add((file: file, path: path, text: node));
      }
    }

    for (final directory in <String>['assets/content', 'lib/l10n']) {
      for (final file in Directory(directory).listSync().whereType<File>()) {
        if (!file.path.endsWith('.json') && !file.path.endsWith('.arb')) {
          continue;
        }
        walk(jsonDecode(file.readAsStringSync()), file.path, r'$', null);
      }
    }
    expect(strings, isNotEmpty, reason: 'no Persian text was found to check');
  });

  group('Orthography', () {
    test('the zero-width non-joiner is used correctly', () {
      // A doubled ZWNJ, or one adjacent to a space or a full stop, is always a
      // mistake: it does nothing there except widen the gap by a hair, so it
      // survives proofreading and misaligns the text forever.
      final problems = <String>[];
      for (final entry in strings) {
        for (final rule in const <(String, String)>[
          ('‌‌', 'two zero-width non-joiners in a row'),
          ('‌ ', 'a zero-width non-joiner before a space'),
          (' ‌', 'a zero-width non-joiner after a space'),
          ('‌.', 'a zero-width non-joiner before a full stop'),
          ('‌،', 'a zero-width non-joiner before a comma'),
        ]) {
          if (entry.text.contains(rule.$1)) {
            problems.add('${entry.file} ${entry.path}: ${rule.$2}');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('spacing and punctuation are clean', () {
      final problems = <String>[];
      for (final entry in strings) {
        if (entry.text.contains('  ')) {
          problems.add('${entry.file} ${entry.path}: a double space');
        }
        if (RegExp('[؀-ۿ] +[،؛.]').hasMatch(entry.text)) {
          problems.add(
            '${entry.file} ${entry.path}: a space before punctuation',
          );
        }
        if (entry.text.trim() != entry.text) {
          problems.add(
            '${entry.file} ${entry.path}: leading or trailing space',
          );
        }
        // The kashida is a letter-joining character, not a dash and not a
        // hyphen. Seven of them had crept in doing both jobs — «ناـدوگانگی»
        // for a prefixed word, «من ـ تو» for Buber's pair — and it is close
        // to invisible on screen while breaking search, sorting and copy.
        if (entry.text.contains('\u0640')) {
          problems.add(
            '${entry.file} ${entry.path}: a kashida. It joins letters; it is '
            'not a hyphen and not a dash.',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('Persian text uses Persian letters and digits', () {
      // Arabic yeh and kaf look almost identical to their Persian counterparts
      // and sort, search and line-break differently. They are correct inside a
      // name or title quoted in Arabic, which is why only running Persian prose
      // is checked here.
      final problems = <String>[];
      for (final entry in strings) {
        for (final rule in const <(String, String)>[
          ('ي', 'Arabic yeh ي instead of Persian ی'),
          ('ك', 'Arabic kaf ك instead of Persian ک'),
          ('ة', 'teh marbuta ة, which Persian writes as ه or ت'),
        ]) {
          if (entry.text.contains(rule.$1)) {
            problems.add('${entry.file} ${entry.path}: ${rule.$2}');
          }
        }
        if (RegExp('[٠-٩]').hasMatch(entry.text)) {
          problems.add(
            '${entry.file} ${entry.path}: Arabic-Indic digits ٠١٢ instead of '
            'Persian ۰۱۲',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('Word formation', () {
    test('a compound verb is written as two words', () {
      // Persian writes the parts of a compound verb separately: «رد کردن»,
      // «کنار گذاشتن», «جدا کردن». Fifty-two of them had been run together,
      // and the corpus did not even do it consistently — «سر باز زد» appeared
      // beside «سر باززدن» beside «سرباززدن», three spellings of one phrase.
      //
      // The check is narrow on purpose. Plenty of real single words end in
      // these same letters — «باشد», «فرزند», «قرارداد», «کارکرد», «رویداد»,
      // «عملکرد» — so only the exact forms that were wrong are named, rather
      // than a pattern that would have to guess.
      const joined = <String>[
        'ردکردن',
        'کنارگذاشتن',
        'جداکردن',
        'جداشدن',
        'سرباززدن',
        'کارکردن',
        'پرکردن',
        'تصویرکردن',
        'آغازکردن',
        'رفتارکردن',
        'پدیدارشدن',
        'وانمودکردن',
        'واردکردن',
        'واردشدن',
        'پیرشدن',
        'ناپدیدکردن',
        'خطاکردن',
        'محدودکردن',
        'رهاکردن',
        'تصورکردن',
        'فاسدکردن',
        'زورآوردن',
        'فشاردادن',
        'مهارکردن',
        'باورآوردن',
        'تماشاکردن',
        'فخرکردن',
        'بنیادگذاشتن',
        'بلندکردن',
        'بلندشدن',
        'وادارکردن',
        'تولیدکردن',
        'ابزارکردن',
        'اثرگذاشتن',
        'قرارگرفتن',
        'بهترکردن',
        'اعتمادکردن',
        'طردکردن',
        'امتیازدادن',
        'جورشدن',
        'انکارکردن',
        'متقاعدشدن',
        'کاریکاتورکردن',
        'زهرآلودکردن',
        'دشوارکردن',
        'بدکردن',
        'بدشدن',
        'بیدارشدن',
        'حاضرکردن',
        'جلوزدن',
        'پدیدآوردن',
        'آزادشدن',
        'فقیرترشدن',
        'دشوارترشدن',
        'بدکاربردن',
      ];
      final problems = <String>[];
      for (final entry in strings) {
        for (final word in joined) {
          if (RegExp('(?<![؀-ۿ])${RegExp.escape(word)}').hasMatch(entry.text)) {
            problems.add('${entry.file} ${entry.path}: "$word" needs a space');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no invented verb stands in for an ordinary word', () {
      // «وا می‌رمانند» — Derrida's summary said the texts of philosophy drove
      // their oppositions off, using a verb that does not exist in the form it
      // was put in. «فلسفیدن» was a verb coined from «فلسفه» where Persian has
      // «فلسفه‌ورزی». Neither is a typo: both read as words and both survived
      // every other check, because a made-up word is spelled however it is
      // written.
      const invented = <String>[
        'رمانند',
        'وارمان',
        'فلسفیدن',
        'فلسفید',
        'ناباورکردنی',
      ];
      final problems = <String>[];
      for (final entry in strings) {
        for (final word in invented) {
          if (entry.text.contains(word)) {
            problems.add('${entry.file} ${entry.path}: "$word" is not a word');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a philosopher is spelled one way in Persian too', () {
      // The English rule about one spelling per person had a Persian half that
      // nothing checked. Leibniz was «لایبنیتس» and «لایب‌نیتس», Tsongkhapa was
      // «تسونگ‌کاپا» and «تسونگ‌خاپا», Anscombe was «انسکوم» and «آنسکوم», and
      // Du Bois had three: «دوبویز», «دوبویس», «دوبوا».
      //
      // These are transliterations, so the rule cannot be derived — «پوپر» and
      // «بوبر» are Popper and Buber, and «بیرون» and «پیرون» are an ordinary
      // word and Pyrrho. Each spelling that was wrong is named, against the
      // form the entry itself carries.
      const wrong = <String, String>{
        'آنسکوم': 'انسکوم',
        'تسونگ‌خاپا': 'تسونگ‌کاپا',
        'دوبویس': 'دوبویز',
        'دوبوا': 'دوبویز',
        'لایبنیتس': 'لایب‌نیتس',
      };
      final problems = <String>[];
      for (final entry in strings) {
        for (final pair in wrong.entries) {
          if (RegExp('(?<![؀-ۿ])${RegExp.escape(pair.key)}(?![؀-ۿ])')
              .hasMatch(entry.text)) {
            problems.add(
              '${entry.file} ${entry.path}: "${pair.key}" — the entry says '
              '"${pair.value}"',
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a citation locator keeps the letter that makes it findable', () {
      // A Stephanus number is «21d», and the digit localisation had turned
      // three of them into «۲۱د» and «۲۷۵د» — references that cannot be looked
      // up in any edition, because the section letter is half the reference.
      final problems = <String>[
        for (final entry in strings)
          // `\p{L}` rather than a code-point range: the Arabic block puts the
          // decimal separator ٫ and the thousands separator ٬ between the
          // letters, and «۱٫۲» and «۱٬۲۰۰» are correctly written Persian.
          for (final match in RegExp(
            r'[۰-۹]+\p{L}',
            unicode: true,
          ).allMatches(entry.text))
            '${entry.file} ${entry.path}: "${match.group(0)}"',
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('Script', () {
    test('no Persian word has Latin letters inside it', () {
      // A word that is half Persian and half Latin is not a loanword and not a
      // transliteration; it is a slip made while typing in two scripts. It
      // renders as a broken word whose halves run in opposite directions, and
      // it survives every other check here because both halves are legal.
      //
      // Written after «برauwer» — Brouwer's name, half typed and half not —
      // shipped in an article and was found by grep rather than by the suite.
      //
      // Matched by script rather than by code-point range. The Arabic block
      // also holds the punctuation Persian shares with every other language
      // written in that script \u2014 \u00AB\u060C\u00BB \u00AB\u061B\u00BB \u00AB\u061F\u00BB \u2014 so a range spanning the block
      // reported `percipi\u060C` as a word in two scripts. That is a Latin word
      // followed by a Persian comma, which is what a Latin word at the end of
      // a Persian clause is supposed to look like. Twice this was worked
      // around by rewriting the prose; the fault was here.
      final offences = <String>[
        for (final entry in strings)
          for (final match in RegExp(
            r'\p{Script=Arabic}+[A-Za-z]+|[A-Za-z]+\p{Script=Arabic}+',
            unicode: true,
          ).allMatches(entry.text))
            '${entry.file} ${entry.path}: "${match.group(0)}"',
      ];

      expect(
        offences,
        isEmpty,
        reason:
            'a word is written in two scripts at once:\n  '
            '${offences.join('\n  ')}',
      );
    });
  });

  group('Register', () {
    test('plain words are used where a plain word exists', () {
      // Not a ban on difficult ideas — a ban on making an ordinary idea sound
      // difficult. Each of these has an everyday synonym that means exactly the
      // same thing, and the entry is no shallower for using it.
      const literary = <String, String>{
        'برهان آورد': 'استدلال کرد',
        'برهان می‌آورد': 'استدلال می‌کند',
        'واپسین': 'آخرین',
        'می‌آغازد': 'آغاز می‌شود',
        'درمی‌گذشت': 'رد می‌شد',
        'درمی‌گذرد': 'رد می‌شود',
      };
      final problems = <String>[];
      for (final entry in strings) {
        for (final swap in literary.entries) {
          if (entry.text.contains(swap.key)) {
            problems.add(
              '${entry.file} ${entry.path}: "${swap.key}" — say '
              '"${swap.value}" instead',
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a philosophical objection is always called اعتراض', () {
      // The domain model has an Objection type and the corpus reconstructs
      // arguments with named objections. Drifting between اعتراض and ایراد for
      // the same thing — which happened once, inside a single sentence — makes
      // the vocabulary of the reconstruction unreliable.
      final objections = strings.where(
        (entry) => entry.path.contains('objections'),
      );
      expect(objections, isNotEmpty);
      for (final entry in objections) {
        expect(
          entry.text.contains('ایراد'),
          isFalse,
          reason:
              '${entry.file} ${entry.path} calls an objection ایراد; the term '
              'used everywhere else is اعتراض',
        );
      }
    });
  });
}

/// Whether a leaf holds authored Persian.
///
/// In content, that is exactly the `fa` fields: `en` is English, `ar` is
/// Arabic, and `nativeName`, `originalTitle` and `transliteration` are quoted in
/// whatever language the thing is actually named in. In `app_fa.arb` every value
/// is Persian by definition.
bool _isPersianField(String file, String? key) =>
    file.endsWith('app_fa.arb') ? true : key == 'fa';
