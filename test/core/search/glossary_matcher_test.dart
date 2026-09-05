import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/search/glossary_matcher.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
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
  group('A term of art does not gloss an ordinary word', () {
    test('a form tied to one tradition does not fire across the corpus', () {
      // The matcher was doing exactly what it was told; what it was told was
      // wrong. Ātman carried the alias "self", so 44 passages offered the
      // Hindu term to a reader tapping the word in Descartes' cogito, in
      // Hume denying that inspection finds one, in Foucault's care of the
      // self. Dukkha carried "suffering", and fired on Weil distinguishing
      // suffering from affliction and on Eriugena's account of punishment.
      // Mokṣa carried "liberation", and reached liberation theology. Qiyās
      // was named "Analogy", and fired on Plato's city-and-soul, on
      // Plotinus' fire, and on Angela Davis saying she does not mean an
      // analogy. Validity carried "sound", and three of its first four hits
      // were the noise.
      //
      // In Persian the same shape, from the names rather than the aliases:
      // a priori was «پیشین», which is the ordinary word for previous, so it
      // marked a previous ruler and an earlier tradition; nous was «عقل»,
      // kalām was «کلام», which is also simply speech, and commentary was
      // «شرح», which is any account of anything.
      //
      // The rule is not "no common words" — metaphysics, premise, substance,
      // essence and virtue are general on purpose and belong wherever they
      // appear. It is that a term belonging to one tradition must be named
      // by a form that belongs to it too.
      //
      // Named here are the terms that are general by intent. Anything else
      // reaching this many entries across this many traditions is a word
      // doing duty for something it does not mean.
      const general = <String>{
        'metaphysics',
        'epistemology',
        'aesthetics',
        'premise',
        'substance',
        'essence',
        'universals',
        'virtue-ethics',
        'empiricism',
        'normative',
        'commentary-tradition',
        'canon',
        'nous',
        // A school and a method, and general in the second sense wherever it
        // appears: Sartre's argument is a piece of phenomenology, and so is
        // Merleau-Ponty's and Nishida's. It crossed the line when arguments
        // joined the entities this scans, which widened the pool rather than
        // changing what the word means.
        'phenomenology',
        // A position rather than a school's property, and held under that name
        // in Cārvāka, in Epicurus and in the philosophy of mind alike. It
        // crossed the line for the same reason phenomenology did: the pool of
        // entities being scanned grew, not the reach of the word.
        'materialism',
      };

      String boundary(String form, AppLanguage language) {
        final escaped = RegExp.escape(form);
        return language == AppLanguage.fa
            ? '(?<![\\p{L}\\p{N}\u200c])$escaped(?![\\p{L}\\p{N}\u200c])'
            : '(?<![\\p{L}\\p{N}-])$escaped(?![\\p{L}\\p{N}-])';
      }

      final problems = <String>[];
      for (final glossaryTerm in corpus.glossary) {
        if (general.contains(glossaryTerm.id)) continue;
        for (final language in AppLanguage.values) {
          final forms = <String>[
            glossaryTerm.term.resolve(language),
            ...glossaryTerm.aliases.where(
              (alias) => (language == AppLanguage.fa) != _isAscii(alias),
            ),
          ];
          for (final form in forms) {
            final pattern = RegExp(
              boundary(form, language),
              unicode: true,
              caseSensitive: language != AppLanguage.en,
            );
            final traditions = <String>{};
            var entries = 0;
            for (final entity in corpus.allEntities) {
              final prose = _prose(entity, language);
              if (prose.any(pattern.hasMatch)) {
                entries++;
                traditions.addAll(entity.traditions);
              }
            }
            if (entries >= 8 && traditions.length >= 6) {
              problems.add(
                'glossary:${glossaryTerm.id} is marked by "$form" in $entries '
                'entries across ${traditions.length} traditions, which is '
                'wider than a term of art reaches',
              );
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });
}

bool _isAscii(String value) => value.runes.every((rune) => rune < 128);

/// Every authored passage of [entity] in [language].
///
/// Article bodies only: the glossary marks words inside prose a reader is
/// reading, not inside a name or a one-line summary.
List<String> _prose(KnowledgeEntity entity, AppLanguage language) => <String>[
  for (final section in entity.article.sections) section.body.resolve(language),
];
