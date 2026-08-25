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
          // Alef maqsura is the third of the three, and the one this rule
          // missed: it is not the Arabic yeh, it carries no dots at all, and
          // in a Persian font it renders identically to ی at the end of a
          // word. «ترامواى» and «تارى» shipped that way.
          ('ى', 'alef maqsura ى instead of Persian ی'),
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

  group('Spelling of fixed forms', () {
    test('a preposition that ends in ه carries its ezafe', () {
      // «دربارهٔ» is written 996 times and «درباره» 177 times, all of them in
      // works.json, all of them the preposition. Without the hamza the reader
      // has to supply the ezafe from the sense of the sentence, and «درباره
      // معنای» reads for a moment as two nouns side by side.
      final problems = <String>[
        for (final entry in strings)
          if (RegExp(
            r'(?<![\p{L}\p{M}‌])درباره (?=[\p{L}«])',
            unicode: true,
          ).hasMatch(entry.text))
            '${entry.file} ${entry.path}: "درباره" needs its ezafe: دربارهٔ',
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a noun that ends in ه carries the ezafe it needs', () {
      // The same defect as «درباره», one layer in: an ezafe on a word ending
      // in ه is written with a hamza, and 106 noun phrases across the corpus
      // had none — «فلسفه اخلاق», «سده بیستم», «مدینه فاضله», «قاعده
      // شناسایی». Each was found by asking whether the corpus writes that
      // exact pair with the hamza somewhere else, so every one listed here is
      // a phrase the corpus itself spells both ways.
      //
      // The rule cannot be a pattern: «نکته این است» and «همه چنین‌اند» end
      // in ه and take no ezafe at all, and nine of the first hundred
      // candidates were sentences like those. So the pairs are named.
      const bare = <String>[
        'سده بیستم',
        'سده نوزدهم',
        'سده شانزدهم',
        'سده پانزدهم',
        'فلسفه اخلاق',
        'فلسفه ذهن',
        'فلسفه اسلامی',
        'فلسفه یونانی',
        'فلسفه غربی',
        'فلسفه آفریقایی',
        'فلسفه اروپایی',
        'فلسفه تطبیقی',
        'فلسفه رهایی',
        'فلسفه اولی',
        'نظریه ارزش',
        'نظریه اوصاف',
        'نظریه خطا',
        'نظریه سیاسی',
        'نظریه خودش',
        'برنامه درسی',
        'برنامه هیلبرت',
        'نیمه دوم',
        'نیمه نخست',
        'قاعده شناسایی',
        'پرونده اصلی',
        'پرونده دشوار',
        'جوینده حقیقت',
        'مسئله شر',
        'مسئله بومیان',
        'مسئله فلسفی',
        'کارنامه سیاسی',
        'اندیشه هند',
        'اندیشه آفریقایی',
        'اندیشه اوست',
        'اندیشه بومیان',
        'اندیشه بومی',
        'مقاله کوتاه',
        'مقاله همراه',
        'مقوله سامان‌دهنده',
        'آموزه رواقی',
        'آموزه سامان‌دهنده',
        'دوره کامل',
        'دوره استعمار',
        'همه آدمیان',
        'همه آن‌ها',
        'همه حالت‌ها',
        'همه اتهام‌ها',
        'واژه یونانی',
        'واژه بنیادی',
        'اراده آزاد',
        'هندسه نااقلیدسی',
        'ترجمه لاتین',
        'ترجمه فلسفه',
        'مدینه فاضله',
        'مراقبه بی‌تحلیل',
        'اندازه عملی',
        'قضیه دوم',
        'نمونه مشهور',
        'نمونه الگویی',
        'جامعه یوروبا',
        'جامعه خودش',
        'فرآورده آن',
        'وهله نخست',
        'طبقه متوسط',
        'مرتبه ذهن',
        'فاصله میان',
        'حمله مغول',
        'حمله او',
        'خانه پدرم',
        'بیمه اجتماعی',
        'ایده عدالت',
        'ایده اوست',
        'توسعه انسانی',
        'عهده خدا',
        'مایه خودش',
        'نتیجه سیاسی',
        'رساله دکتری',
        'شیوه اندیشیدن',
        'شیوه سخن',
        'پس‌زمینه آن',
        'افسانه اینکه',
        'استحاله امر',
        'نقطه آغاز',
        'وارونه آن',
        'نکته کلی',
        'حلقه وین',
        'جامعه آندی',
        'کتابخانه سلطنتی',
        'رصدخانه مراغه',
        'گزینه موجود',
        'مغالطه طبیعت‌گرایانه',
      ];
      final problems = <String>[];
      for (final entry in strings) {
        for (final phrase in bare) {
          if (RegExp(
            '(?<![\\p{L}\\p{M}‌])$phrase(?![\\p{L}\\p{M}‌])',
            unicode: true,
          ).hasMatch(entry.text)) {
            problems.add(
              '${entry.file} ${entry.path}: "$phrase" is missing its ezafe',
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('an Arabic adverb keeps its tanwin', () {
      // «تقریباً» 117 times and «تقریبا» 14, «اصلاً» 94 and «اصلا» 13. The
      // tanwin is what makes the word an adverb; without it «دقیقا» is not a
      // Persian word at all.
      const adverbs = <String>[
        'تقریبا',
        'عمدا',
        'اصلا',
        'ازلا',
        'دقیقا',
        'کاملا',
        'صرفا',
        'رسما',
        'بعدا',
        'طبیعتا',
        'عموما',
        'ذاتا',
        'صریحا',
        'واقعا',
        'نسبتا',
        'مستقیما',
        'عملا',
        'ظاهرا',
        'حتما',
        'قطعا',
        'مطلقا',
        'مشخصا',
        'ضرورتا',
        'لزوما',
        'منطقا',
        // Found the other way round: every word that carries a tanwin
        // somewhere in the corpus, looked for bare somewhere else.
        'احتمالا',
        'اصولا',
        'قانونا',
        'موقتا',
      ];
      final pattern = RegExp(
        '(?<![\\p{L}\\p{M}‌])(${adverbs.join('|')})(?![\\p{L}\\p{M}‌])',
        unicode: true,
      );
      final problems = <String>[
        for (final entry in strings)
          for (final match in pattern.allMatches(entry.text))
            '${entry.file} ${entry.path}: "${match.group(0)}" has lost its tanwin',
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('one spelling for the words that come up on every page', () {
      // Each of these was written both ways, and the count says which way the
      // corpus had already settled: «ابن‌سینا» 43 against «ابن سینا» 5,
      // «هیچ‌کس» 75 against none, «به دست» 149 against «به‌دست» 9. The one
      // that changes the sense is the last: «به‌دستِ کسی» is by someone's
      // hand, «به دست آوردن» is to obtain, and the corpus used the bound
      // form for both.
      const wrong = <String, String>{
        'ابن سینا': 'ابن‌سینا',
        'ابن رشد': 'ابن‌رشد',
        'ابن میمون': 'ابن‌میمون',
        'ابن عربی': 'ابن‌عربی',
        'ابن خلدون': 'ابن‌خلدون',
        'ابن هیثم': 'ابن‌هیثم',
        'ابن طفیل': 'ابن‌طفیل',
        'ابن باجه': 'ابن‌باجه',
        'ابن تیمیه': 'ابن‌تیمیه',
        'به‌دست': 'به دست',
        'دست کم': 'دست‌کم',
        'همه چیز': 'همه‌چیز',
        'هیچ چیز': 'هیچ‌چیز',
        'هیچ کس': 'هیچ‌کس',
        'هر کس': 'هرکس',
        'هر کسی': 'هرکسی',
        // «هرچند» meaning although is written bound, but «هر چند تا هم که
        // باشند» is three words doing something else, so the pair is left out
        // rather than guarded wrongly.
      };
      final problems = <String>[];
      for (final entry in strings) {
        for (final pair in wrong.entries) {
          final pattern = RegExp(
            '(?<![\\p{L}\\p{M}‌])${pair.key}(?![\\p{L}\\p{M}‌])',
            unicode: true,
          );
          if (pattern.hasMatch(entry.text)) {
            problems.add(
              '${entry.file} ${entry.path}: "${pair.key}" — the corpus writes '
              '"${pair.value}"',
            );
          }
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
          if (RegExp(
            '(?<![\\p{L}\\p{M}‌])${RegExp.escape(word)}',
            unicode: true,
          ).hasMatch(entry.text)) {
            problems.add('${entry.file} ${entry.path}: "$word" needs a space');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a verb is not welded to the word before it', () {
      // The list above names the forms that were wrong; this asks the
      // question the other way round and names the forms that are right.
      // Persian does weld a preverb to its verb — «برداشتن», «وانهادن»,
      // «پذیرفتن» — and welds nothing else, so an infinitive with a word
      // stuck to its front is either one of those or a mistake.
      //
      // Thirteen were mistakes: «دردکشیدن», «بالارفتن», «بنیادنهادن»,
      // «تمایزنهادن», «هم‌راستاکردن», «دست‌وپازدن», «جابه‌جاشدن».
      const welded = <String>[
        'بازآمدن',
        'بازآوردن',
        'بازداشتن',
        'بازساختن',
        'بازشدن',
        'بازکشیدن',
        'بازگذاشتن',
        'بازگفتن',
        'بازیافتن',
        'برآمدن',
        'برآوردن',
        'برداشتن',
        'برنداشتن',
        'برنهادن',
        'برگرفتن',
        'بنانهادن',
        'درآمدن',
        'درآوردن',
        'دریافتن',
        'فرودآمدن',
        'نپذیرفتن',
        'نپنداشتن',
        'نگرفتن',
        'واداشتن',
        'وانهادن',
        'واگذاشتن',
        'پانهادن',
        'پدیدآمدن',
        'پذیرفتن',
        'پنداشتن',
        'گردیدن',
      ];
      const verbs = <String>[
        'کردن',
        'شدن',
        'دادن',
        'گرفتن',
        'آوردن',
        'زدن',
        'بردن',
        'داشتن',
        'ساختن',
        'یافتن',
        'خوردن',
        'کشیدن',
        'نهادن',
        'گذاشتن',
        'ماندن',
        'دیدن',
        'گفتن',
        'رفتن',
        'آمدن',
        'رساندن',
        'بستن',
      ];
      final pattern = RegExp(
        '([\\p{L}\\p{M}]{2,})(${verbs.join('|')})(?![\\p{L}\\p{M}])',
        unicode: true,
      );
      final problems = <String>[];
      for (final entry in strings) {
        for (final match in pattern.allMatches(entry.text)) {
          if (welded.contains(match.group(0))) continue;
          problems.add(
            '${entry.file} ${entry.path}: "${match.group(0)}" needs a space',
          );
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
        // The Chinese names had three endings between them — ‌زی, ‌دزه and
        // ‌تزه — and each entry carries the last.
        'شون‌دزه': 'شون‌تزه',
        'شون‌زی': 'شون‌تزه',
        'شونزی': 'شون‌تزه',
        'جوانگ‌زی': 'جوانگ‌تزه',
        'جوانگ‌دزه': 'جوانگ‌تزه',
        'فی‌زی': 'فی‌تزه',
        'فی‌دزه': 'فی‌تزه',
        // Mozi had four: «مو تزه» as his own name, «موزی» as the title of
        // his book, «مو‌دزه» in the source record for that same book, and
        // «مو‌دزه» again in the article body.
        'مو تزه': 'مو‌تزه',
        'مو زی': 'مو‌تزه',
        'موزی': 'مو‌تزه',
        'مو‌دزه': 'مو‌تزه',
        'منگ‌دزه': 'منگ‌تزه',
        // Found by asking, for every bilingual passage, whether a philosopher
        // the English names is named in the Persian too. Most of what that
        // turns up is ordinary prose using «او» instead of repeating a name;
        // these five were two spellings of one person.
        'آکویناس': 'آکوئیناس',
        'پلوتینوس': 'افلوطین',
        'نوسبام': 'نوسباوم',
        'اوکام': 'اکام',
        'ناگارجونه': 'ناگارجونا',
        // Her entry is «سیمون دوبووار» and thirteen passages called her
        // «بووار», which drops the particle the name is built on.
        'بووار': 'دوبووار',
        // Philoponus was «یوحنای نحوی» as the entry's name and «فیلوپونوس»
        // four times in the prose; Gi Daeseung was «کی دِسونگ» in Yi Hwang's
        // entry and «گی دائه‌سونگ» in the entry for the book they argued in.
        'کی دِسونگ': 'گی دائه‌سونگ',
        // Found by measuring every word in the corpus against every entry's
        // own name and reading what came back close but not equal. Twenty
        // were second spellings of someone who already had one, and three of
        // them were Vasubandhu: «واسوباندو», «واسوباندهو», «وسوبندهو».
        'واسوباندهو': 'واسوباندو',
        'وسوبندهو': 'واسوباندو',
        'ماکیاوللی': 'ماکیاولی',
        'گورگیاس': 'گرگیاس',
        'مهاویرا': 'مهاویره',
        'نیکولاس': 'نیکلاس',
        'فلوطین': 'افلوطین',
        'ونهیو': 'وونهیو',
        'واینتر': 'وینتر',
        'بارکلی': 'برکلی',
        'ماریاته‌گی': 'ماریاتگی',
        'راولز': 'رالز',
        'کی‌یرکگور': 'کیرکگور',
        'کروسیپوس': 'کریسیپوس',
        'آبیناواگوپتا': 'ابهیناواگوپتا',
        'هیپاتیا': 'هوپاتیا',
        'لونجینو': 'لانجینو',
        'آئوروبیندو': 'آروبیندو',
      };
      final problems = <String>[];
      for (final entry in strings) {
        for (final pair in wrong.entries) {
          if (RegExp(
            '(?<![\\p{L}\\p{M}‌])${RegExp.escape(pair.key)}'
            '(?![\\p{L}\\p{M}‌])',
            unicode: true,
          ).hasMatch(entry.text)) {
            problems.add(
              '${entry.file} ${entry.path}: "${pair.key}" — the entry says '
              '"${pair.value}"',
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a term of art is spelled one way in Persian too', () {
      // The same rule as for names, for the words that name an idea. Pyrrho
      // came out three ways — «پیرون» in his own entry, «پیرهون» in its own
      // article body, «پورون» in the source record for the very work that
      // works.json titled «طرح‌های پیرهونی» — so one book had two Persian
      // titles. Embodiment was «تن‌مندی» three times and «بدنمندی» once,
      // written closed up as well. Coloniality was «استعمارمندی» as a title,
      // «استعماریت» in its own article and «استعماری‌بودن» in the two book
      // titles that use it; «-مند» attaches to a noun to say it has something,
      // and «استعمارمند» says nothing anyone means.
      //
      // «موقعیت‌گرایی» is the one that changes the sense rather than the
      // spelling: it is the word for situationism, and it stood in a list of
      // answers to Descartes' mind-body problem where occasionalism belongs —
      // «موقع‌گرایی», the word the Ghazali entry already used.
      const wrong = <String, String>{
        'پیرهون': 'پیرون',
        'پورون': 'پیرون',
        'بدنمندی': 'تن‌مندی',
        'بدن‌مندی': 'تن‌مندی',
        'استعمارمند': 'استعماری‌بودن',
        'استعماریت': 'استعماری‌بودن',
        'موقعیت‌گرای': 'موقع‌گرای',
        // A book named one way as an entry and another way in the prose that
        // sends the reader to it. Zeami's 花 was «گل» as a concept and
        // «شکوفه» in ten passages including his own quotation; Nkrumah's book
        // was «ضمیرگرایی» as a work and «کانشِنسیسم» in his entry; Cusa's was
        // «نادانی آموخته» and «جهل عالمانه»; Wollstonecraft's was «دفاع از
        // حقوق زن» and «استیفای حقوق»; Lucretius' was «طبیعتِ چیزها» and
        // «طبیعت اشیا»; Benjamin's was «دربارهٔ مفهوم تاریخ» and «تزهایی
        // دربارهٔ تاریخ».
        'شکوفه': 'گل',
        'کانشِنسیسم': 'ضمیرگرایی',
        'جهل عالمانه': 'نادانی آموخته',
        'استیفای حقوق': 'دفاع از حقوق زن',
        'دربارهٔ طبیعت اشیا': 'دربارهٔ طبیعتِ چیزها',
        'تزهایی دربارهٔ تاریخ': 'دربارهٔ مفهوم تاریخ',
      };
      final problems = <String>[];
      for (final entry in strings) {
        for (final pair in wrong.entries) {
          if (RegExp(
            '(?<![\\p{L}\\p{M}‌])${RegExp.escape(pair.key)}',
            unicode: true,
          ).hasMatch(entry.text)) {
            problems.add(
              '${entry.file} ${entry.path}: "${pair.key}" — the corpus says '
              '"${pair.value}"',
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('the verb of a compound verb stands on its own', () {
      // The other half of the compound-verb rule. «ردکردن» run together was
      // already caught; «رد‌کردن» with a half-space between the parts was not,
      // and the corpus was split almost evenly — 430 written with the joiner
      // against 540 with a space, and forty-seven verbs spelled both ways in
      // different entries. «پاسخ دادن» twice and «پاسخ‌دادن» twelve times is
      // not a distinction anyone was drawing.
      //
      // The rule the Academy gives is the simple one: the verbal part of a
      // compound verb is written separately, so nothing that is only an
      // infinitive may be bound to the word before it.
      const verbs = <String>[
        'کردن',
        'شدن',
        'دادن',
        'گرفتن',
        'زدن',
        'آوردن',
        'بردن',
        'داشتن',
        'ساختن',
        'یافتن',
        'خوردن',
        'کشیدن',
        'بستن',
        'انداختن',
        'رساندن',
        'نهادن',
        'گذاشتن',
        'ماندن',
        'دیدن',
        'گفتن',
        'خواستن',
        'رفتن',
        'آمدن',
        'گشتن',
        'نمودن',
        'جستن',
        'بودن',
        'شنیدن',
        'خواندن',
        'نوشتن',
        'گردیدن',
        'ورزیدن',
        'سپردن',
        'پرداختن',
      ];
      final pattern = RegExp(
        '([\\p{L}\\p{M}]+)‌(${verbs.join('|')})(?![\\p{L}\\p{M}])',
        unicode: true,
      );
      final problems = <String>[];
      for (final entry in strings) {
        for (final match in pattern.allMatches(entry.text)) {
          // «برمی‌آوردن», «درمی‌آورند»: the joiner belongs to the «می» prefix,
          // which is part of the verb rather than a word before it.
          if (match.group(1)!.endsWith('می')) continue;
          problems.add(
            '${entry.file} ${entry.path}: "${match.group(0)}" needs a space',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a compound number is written the way the Academy writes it', () {
      // «سی‌وپنج» four times and «سی و پنج» three times, twelve numbers
      // spelled both ways. Compound numerals take spaces.
      const tens = <String>[
        'بیست',
        'سی',
        'چهل',
        'پنجاه',
        'شصت',
        'هفتاد',
        'هشتاد',
        'نود',
        'صد',
        'دویست',
        'سیصد',
        'چهارصد',
        'پانصد',
      ];
      const units = <String>[
        'یک',
        'دو',
        'سه',
        'چهار',
        'پنج',
        'شش',
        'هفت',
        'هشت',
        'نه',
        'ده',
        'یازده',
        'دوازده',
        'سیزده',
      ];
      // An age is the same rule one word further on. «هفتادسالگی» ran the
      // two together, «شصت‌سالگی» bound them, «چهل سالگی» and «نوزده سالگی»
      // spaced them, and the compounds came out «بیست و چهارسالگی» with the
      // space in the wrong place of the three.
      final numbers = <String>[
        ...tens,
        ...units,
        'چهارده',
        'پانزده',
        'شانزده',
        'هفده',
        'هجده',
        'نوزده',
        'چند',
      ];
      final pattern = RegExp(
        '(${tens.join('|')})‌و(${units.join('|')})'
        '|(${numbers.join('|')})‌?سالگی',
      );
      final problems = <String>[
        for (final entry in strings)
          for (final match in pattern.allMatches(entry.text))
            '${entry.file} ${entry.path}: "${match.group(0)}" takes spaces',
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a decade is named in a calendar the reader can tell', () {
      // «دههٔ شصت» means the nineteen-sixties to the writer and the thirteen-
      // sixties of the Solar Hijri calendar to a reader in Iran — the
      // nineteen-eighties. Five passages named a decade in words that way,
      // while eighteen others wrote «دههٔ ۱۹۵۰» and left nothing to guess.
      //
      // The bare noun is fine: «یک دهه بعد», «دههٔ بعد». What has to carry
      // digits is a decade called by its number.
      const spelled = <String>[
        'دههٔ بیست',
        'دههٔ سی',
        'دههٔ چهل',
        'دههٔ پنجاه',
        'دههٔ شصت',
        'دههٔ هفتاد',
        'دههٔ هشتاد',
        'دههٔ نود',
        'دهه‌های هفتاد',
        'دهه‌های شصت',
        'دهه‌های هشتاد',
      ];
      final problems = <String>[
        for (final entry in strings)
          for (final decade in spelled)
            if (entry.text.contains(decade))
              '${entry.file} ${entry.path}: "$decade" — which century?',
      ];
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
