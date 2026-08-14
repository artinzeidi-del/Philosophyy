import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';

/// Holds the classification vocabulary to the terms on which it was opened.
///
/// Traditions and branches were Dart enums until the scope audit. That made a
/// typo a compile error, but it also made Korean, Tibetan, Ethiopian and every
/// Indigenous tradition unnameable without a release. Opening the vocabulary to
/// content removed the ceiling and, with it, the compiler's guarantee. These
/// tests are where that guarantee now lives: an id that resolves to nothing is
/// caught here, and the claim that a tradition can be added without touching
/// Dart is exercised rather than asserted in a comment.

/// A minimal philosopher, so a test can say what it is about in one line.
Philosopher _fixture(Set<String> traditions) => Philosopher(
  id: 'someone',
  name: const LocalizedText(en: 'Someone', fa: 'کسی'),
  oneLine: const LocalizedText(en: 'A test fixture.', fa: 'نمونهٔ آزمون.'),
  life: LifeSpan(birth: HistoricalYear(1900), death: HistoricalYear(1980)),
  traditions: traditions,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  group('The shipped taxonomy', () {
    test('loads with terms of every kind the product classifies by', () {
      final taxonomy = corpus.taxonomy;
      expect(taxonomy.length, greaterThan(0));
      expect(
        taxonomy.ofKind(TaxonomyKind.tradition),
        isNotEmpty,
        reason: 'a philosophy reference with no traditions is not one',
      );
      expect(taxonomy.ofKind(TaxonomyKind.branch), isNotEmpty);
    });

    test('every id used by content resolves to a term of the right kind', () {
      // This is the check that replaced the compiler. It is asserted separately
      // from the integrity test so a failure names the taxonomy rather than
      // being buried among cross-reference violations.
      final taxonomy = corpus.taxonomy;
      final problems = <String>[];

      for (final entity in corpus.allEntities) {
        for (final id in entity.traditions) {
          final term = taxonomy[id];
          if (term == null) {
            problems.add('${entity.id}: tradition "$id" is not defined');
          } else if (term.kind != TaxonomyKind.tradition) {
            problems.add('${entity.id}: "$id" is a ${term.kind.id}');
          }
        }
        for (final id in entity.branches) {
          final term = taxonomy[id];
          if (term == null) {
            problems.add('${entity.id}: branch "$id" is not defined');
          } else if (term.kind != TaxonomyKind.branch) {
            problems.add('${entity.id}: "$id" is a ${term.kind.id}');
          }
        }
      }

      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no term names a parent that does not exist', () {
      expect(corpus.taxonomy.orphans, isEmpty);
    });

    test('every term is named in both languages', () {
      // The old enums enforced this by construction: the label switch would not
      // compile without a Persian name. Opening the vocabulary must not quietly
      // drop the bilingual guarantee, so it is asserted here instead.
      final untranslated = corpus.taxonomy.all
          .where((term) => !term.name.isTranslated)
          .map((term) => term.id)
          .toList();
      expect(untranslated, isEmpty);
    });

    test('ids are unique across the whole vocabulary', () {
      final ids = corpus.taxonomy.all.map((term) => term.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('reaches beyond the traditions the old enum could name', () {
      // The specific failure the audit found: sixteen hardcoded traditions, with
      // no way to name a Korean, Tibetan, Ethiopian, Mesoamerican or Indigenous
      // philosophy at all. Naming them here means the ceiling cannot be
      // reintroduced without this failing.
      final taxonomy = corpus.taxonomy;
      for (final id in const <String>[
        'korean',
        'vietnamese',
        'tibetan',
        'ethiopian',
        'mesoamerican',
        'andean',
        'indigenous',
        'indigenous-australian',
        'first-nations',
      ]) {
        expect(
          taxonomy.contains(id),
          isTrue,
          reason: '"$id" must be nameable by content alone',
        );
      }
    });

    test('nesting lets a reader browse at the level they are thinking at', () {
      final taxonomy = corpus.taxonomy;
      expect(taxonomy.isUnder('mesoamerican', 'indigenous'), isTrue);
      expect(taxonomy.isUnder('mesoamerican', 'mesoamerican'), isTrue);
      expect(taxonomy.isUnder('mesoamerican', 'ancient-greek'), isFalse);
      expect(taxonomy.childrenOf('indigenous'), isNotEmpty);
    });

    test('an unknown id is reported, not silently accepted', () {
      final taxonomy = corpus.taxonomy;
      expect(taxonomy['no-such-tradition'], isNull);
      expect(taxonomy.contains('no-such-tradition'), isFalse);
      expect(
        taxonomy.unknownAmong(<String>['ancient-greek', 'no-such-tradition']),
        <String>['no-such-tradition'],
      );
    });

    test('an unknown id still renders something legible', () {
      // A content mistake must not blank a chip. The id is at least readable,
      // where an empty label would be a mystery to the reader and to whoever
      // has to find the bug.
      expect(
        corpus.taxonomy.nameOf('no-such-tradition').en,
        'no-such-tradition',
      );
    });
  });

  group('Classifying against the taxonomy', () {
    test('a tradition can be added without changing any Dart', () {
      // The claim the whole refactor rests on, exercised rather than asserted:
      // a term that exists nowhere in the source builds, classifies an entity,
      // resolves its name and answers ancestry queries.
      final taxonomy = Taxonomy(<TaxonomyTerm>[
        const TaxonomyTerm(
          id: 'hypothetical-lineage',
          kind: TaxonomyKind.tradition,
          name: LocalizedText(en: 'Hypothetical', fa: 'فرضی'),
        ),
        const TaxonomyTerm(
          id: 'hypothetical-branchlet',
          kind: TaxonomyKind.tradition,
          parentId: 'hypothetical-lineage',
          name: LocalizedText(en: 'Hypothetical Branchlet', fa: 'شاخهٔ فرضی'),
        ),
      ]);

      expect(taxonomy.nameOf('hypothetical-lineage').en, 'Hypothetical');
      expect(taxonomy.nameOf('hypothetical-lineage').fa, 'فرضی');
      expect(
        taxonomy.isUnder('hypothetical-branchlet', 'hypothetical-lineage'),
        isTrue,
      );
      expect(taxonomy.orphans, isEmpty);
    });

    test('a corpus tagged with an undefined term fails integrity', () {
      // The guarantee the compiler used to give, now given at load time.
      final base = KnowledgeBase(
        philosophers: <Philosopher>[
          _fixture(<String>{'undefined-tradition'}),
        ],
        concepts: const [],
        works: const [],
        schools: const [],
        quotes: const [],
        arguments: const [],
        sources: const [],
        relations: const [],
        taxonomy: Taxonomy.empty,
      );

      expect(
        base.findIntegrityViolations(),
        contains(contains('undefined-tradition')),
      );
    });

    test('a term used as the wrong kind is rejected', () {
      final base = KnowledgeBase(
        // A branch id in the traditions field. Under the old enums this was a
        // type error; it has to be caught somewhere.
        philosophers: <Philosopher>[
          _fixture(<String>{'ethics'}),
        ],
        concepts: const [],
        works: const [],
        schools: const [],
        quotes: const [],
        arguments: const [],
        sources: const [],
        relations: const [],
        taxonomy: Taxonomy(<TaxonomyTerm>[
          const TaxonomyTerm(
            id: 'ethics',
            kind: TaxonomyKind.branch,
            name: LocalizedText(en: 'Ethics', fa: 'اخلاق'),
          ),
        ]),
      );

      expect(
        base.findIntegrityViolations(),
        contains(contains('which is a branch, not a tradition')),
      );
    });

    test('a narrower tradition counts under the wider one', () {
      // Browsing "Indigenous" must not hide the entries filed as Mesoamerican.
      // Without this, filing an entry more precisely would make it harder to
      // find, which is exactly backwards.
      final taxonomy = Taxonomy(<TaxonomyTerm>[
        const TaxonomyTerm(
          id: 'indigenous',
          kind: TaxonomyKind.tradition,
          name: LocalizedText(en: 'Indigenous', fa: 'بومی'),
        ),
        const TaxonomyTerm(
          id: 'mesoamerican',
          kind: TaxonomyKind.tradition,
          parentId: 'indigenous',
          name: LocalizedText(en: 'Mesoamerican', fa: 'میان‌آمریکایی'),
        ),
      ]);
      final base = KnowledgeBase(
        philosophers: <Philosopher>[
          _fixture(<String>{'mesoamerican'}),
        ],
        concepts: const [],
        works: const [],
        schools: const [],
        quotes: const [],
        arguments: const [],
        sources: const [],
        relations: const [],
        taxonomy: taxonomy,
      );

      expect(base.philosophersInTradition('mesoamerican'), hasLength(1));
      expect(base.philosophersInTradition('indigenous'), hasLength(1));
      expect(base.philosophersInTradition('ancient-greek'), isEmpty);
    });
  });
}
