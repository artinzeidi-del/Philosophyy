import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/format/date_format.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Every date the corpus can print, printed in both languages.
///
/// The date formatter is the one piece of pure logic every screen depends on
/// and nothing tested directly. It is also where a bug is quietest: a lifespan
/// that renders a Persian year in Latin digits, or drops the "c." off an
/// estimate, still looks like a date, and no screenshot sweep would flag it.
///
/// So rather than pick examples, this runs the formatter over every year,
/// lifespan and composition range that actually ships and holds the invariants
/// that must be true of all of them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;
  late AppL10n english;
  late AppL10n persian;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
    english = await AppL10n.delegate.load(const Locale('en'));
    persian = await AppL10n.delegate.load(const Locale('fa'));
  });

  final latinDigit = RegExp(r'[0-9]');
  final persianDigit = RegExp(r'[۰-۹]');

  void checkPair(String what, String? en, String? fa) {
    if (en == null && fa == null) return;
    expect(en, isNotNull, reason: '$what renders in Persian but not English');
    expect(fa, isNotNull, reason: '$what renders in English but not Persian');
    expect(en!.trim(), isNotEmpty, reason: '$what is blank in English');
    expect(fa!.trim(), isNotEmpty, reason: '$what is blank in Persian');
    expect(
      latinDigit.hasMatch(fa),
      isFalse,
      reason: '$what shows Latin digits in Persian: "$fa"',
    );
    expect(
      persianDigit.hasMatch(en),
      isFalse,
      reason: '$what shows Persian digits in English: "$en"',
    );
    // A range that lost one of its ends renders a dash with nothing beside it.
    expect(
      en.trim(),
      isNot(anyOf('–', '-', '– ', ' –')),
      reason: '$what is a bare dash in English',
    );
    expect(
      fa.trim(),
      isNot(anyOf('–', '-', '– ', ' –')),
      reason: '$what is a bare dash in Persian',
    );
  }

  test('every philosopher lifespan renders in both languages', () {
    for (final philosopher in corpus.philosophers) {
      checkPair(
        'philosopher:${philosopher.id}',
        AppDates.lifeSpan(philosopher.life, AppLanguage.en, english),
        AppDates.lifeSpan(philosopher.life, AppLanguage.fa, persian),
      );
    }
  });

  test('every composition and period renders in both languages', () {
    for (final work in corpus.works) {
      checkPair(
        'work:${work.id}',
        AppDates.range(work.composed, AppLanguage.en, english),
        AppDates.range(work.composed, AppLanguage.fa, persian),
      );
    }
    for (final school in corpus.schools) {
      checkPair(
        'school:${school.id}',
        AppDates.range(school.period, AppLanguage.en, english),
        AppDates.range(school.period, AppLanguage.fa, persian),
      );
    }
  });

  test('an estimate never renders as a settled date', () {
    for (final philosopher in corpus.philosophers) {
      final birth = philosopher.life.birth;
      if (birth == null || !birth.isApproximate) continue;
      final line = AppDates.lifeSpan(philosopher.life, AppLanguage.en, english);
      expect(
        line,
        contains('c.'),
        reason:
            '${philosopher.id} has an estimated birth year and the line does '
            'not say so: "$line"',
      );
    }
  });

  test('a year keeps its digits in Persian at every magnitude', () {
    // The formatter substitutes Persian digits by finding the Latin number in
    // the localized string, which works only while the message is a bare
    // interpolation. A four-digit year is the case that would break first if a
    // thousands separator ever appeared.
    for (final value in <int>[1, 9, 10, 99, 100, 470, 1000, 1957, 2100]) {
      for (final era in <bool>[true, false]) {
        final rendered = AppDates.year(
          HistoricalYear(era ? -value : value),
          AppLanguage.fa,
          persian,
        );
        expect(
          latinDigit.hasMatch(rendered),
          isFalse,
          reason: 'year $value renders as "$rendered" in Persian',
        );
      }
    }
  });
}
