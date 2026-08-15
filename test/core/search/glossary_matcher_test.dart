import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/search/glossary_matcher.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// Holds the in-article glossary links to the standard a reader needs.
///
/// The point of the feature is that a reader who meets a word they do not know
/// can tap it without leaving the sentence. Two things would make it worse
/// than not having it: marking a fragment inside a longer word, so the reader
/// taps "canon" and is shown a definition that has nothing to do with the
/// "canonical" they were reading; and marking so much that the paragraph stops
/// looking like prose.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  GlossaryTerm term(
    String id,
    String en,
    String fa, {
    List<String> aliases = const [],
  }) => GlossaryTerm(
    id: id,
    term: LocalizedText(en: en, fa: fa),
    shortDefinition: const LocalizedText(en: 'x', fa: 'x'),
    aliases: aliases,
  );

  group('What gets marked', () {
    test('a whole word is marked', () {
      final matches = GlossaryMatcher.findIn(
        'This is a claim about substance and nothing else.',
        <GlossaryTerm>[term('substance', 'Substance', 'جوهر')],
        AppLanguage.en,
      );
      expect(matches, hasLength(1));
      expect(matches.first.start, 22);
      expect(matches.first.end, 31);
    });

    test('a fragment inside a longer word is not marked', () {
      // "canon" inside "canonical" is the case that would send a reader to the
      // wrong definition.
      final matches = GlossaryMatcher.findIn(
        'The canonical reading is disputed.',
        <GlossaryTerm>[term('canon', 'Canon', 'کانن')],
        AppLanguage.en,
      );
      expect(matches, isEmpty);
    });

    test(
      'a later standalone occurrence is found when the first is embedded',
      () {
        final matches = GlossaryMatcher.findIn(
          'The canonical reading, and the canon behind it.',
          <GlossaryTerm>[term('canon', 'Canon', 'کانن')],
          AppLanguage.en,
        );
        expect(matches, hasLength(1));
        expect(matches.first.start, 31);
      },
    );

    test('a term is marked once, however often it occurs', () {
      // The first occurrence is the one the reader meets before they know the
      // word; the fifth is noise.
      final matches = GlossaryMatcher.findIn(
        'Substance and substance and substance again.',
        <GlossaryTerm>[term('substance', 'Substance', 'جوهر')],
        AppLanguage.en,
      );
      expect(matches, hasLength(1));
    });

    test('overlapping terms do not both mark the same words', () {
      final matches = GlossaryMatcher.findIn(
        'A thought experiment settles it.',
        <GlossaryTerm>[
          term('thought-experiment', 'Thought experiment', 'آزمایش ذهنی'),
          term('experiment', 'Experiment', 'آزمایش'),
        ],
        AppLanguage.en,
      );
      expect(matches, hasLength(1));
      expect(matches.first.term.id, 'thought-experiment');
    });
  });

  group('Persian', () {
    test('a Persian term is matched in Persian prose', () {
      final matches = GlossaryMatcher.findIn(
        'این ادعا دربارهٔ جوهر است.',
        <GlossaryTerm>[term('substance', 'Substance', 'جوهر')],
        AppLanguage.fa,
      );
      expect(matches, hasLength(1));
    });

    test('a term joined by a zero-width non-joiner is not marked', () {
      // «معرفت‌شناسی» contains «معرفت» before a ZWNJ: it is one word, and
      // marking the first half would put a link in the middle of it.
      final matches = GlossaryMatcher.findIn(
        'معرفت‌شناسی چیست؟',
        <GlossaryTerm>[term('knowledge', 'Knowledge', 'معرفت')],
        AppLanguage.fa,
      );
      expect(matches, isEmpty);
    });

    test('the English form is not matched in Persian prose', () {
      final matches = GlossaryMatcher.findIn(
        'این متن دربارهٔ substance نیست.',
        <GlossaryTerm>[term('substance', 'Substance', 'جوهر')],
        AppLanguage.fa,
      );
      expect(matches, isEmpty);
    });
  });

  group('Against the corpus that ships', () {
    test('the glossary finds terms in real articles', () {
      var found = 0;
      for (final entity in corpus.allEntities) {
        for (final section in entity.article.sections) {
          found += GlossaryMatcher.findIn(
            section.body.en,
            corpus.glossary,
            AppLanguage.en,
          ).length;
        }
      }
      expect(
        found,
        greaterThan(50),
        reason: 'the glossary barely matches the prose it was written for',
      );
    });

    test('no paragraph is turned into a field of links', () {
      // A limit found by measuring rather than chosen: the densest section in
      // the corpus is well under this, and a section that crosses it is a
      // signal that the glossary has started marking ordinary words.
      for (final entity in corpus.allEntities) {
        for (final section in entity.article.sections) {
          final words = section.body.en.split(RegExp(r'\s+')).length;
          final marks = GlossaryMatcher.findIn(
            section.body.en,
            corpus.glossary,
            AppLanguage.en,
          ).length;
          expect(
            marks / words,
            lessThan(0.12),
            reason: '${entity.ref}/${section.id} marks $marks of $words words',
          );
        }
      }
    });
  });
}
