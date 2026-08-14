import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// Holds works to the same standard as the rest of the corpus.
///
/// Works were the entity most likely to drift into being a second-class record:
/// they had a rich model, a detail screen and no way to reach them except
/// through their author, and nothing in the knowledge graph touched them. These
/// tests exist to keep that from happening again — and to prove the claim that
/// a new entity kind can join the graph without a relation system of its own.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  group('Works as records', () {
    test('every work names an author who is in the corpus', () {
      // A reference entry for a work whose author cannot be resolved leaves the
      // reader at a dead end on the one question they certainly have.
      for (final work in corpus.works) {
        expect(
          corpus.philosopher(work.authorId),
          isNotNull,
          reason:
              'work:${work.id} has an unresolvable author '
              '"${work.authorId}"',
        );
      }
    });

    test('every edition resolves to a bibliographic record', () {
      // Editions were loaded and never rendered for several sessions. Now that
      // they are on screen, a dangling one is a visible defect.
      for (final work in corpus.works) {
        for (final sourceId in work.editionSourceIds) {
          expect(
            corpus.source(sourceId),
            isNotNull,
            reason: 'work:${work.id} lists unknown edition "$sourceId"',
          );
        }
      }
    });

    test('every work is summarised in one sentence, in both languages', () {
      for (final work in corpus.works) {
        expect(work.oneLine.en.trim(), isNotEmpty, reason: work.id);
        expect(
          work.oneLine.isTranslated,
          isTrue,
          reason: 'work:${work.id} has no Persian summary',
        );
        expect(work.name.isTranslated, isTrue, reason: 'work:${work.id} title');
      }
    });
  });

  group('Browsing works', () {
    test('chronological order puts the earliest first and undated last', () {
      final ordered = corpus.worksChronologically;
      expect(ordered, hasLength(corpus.works.length));

      var lastDated = -1 << 20;
      var seenUndated = false;
      for (final work in ordered) {
        final year = work.composed?.start?.year;
        if (year == null) {
          seenUndated = true;
          continue;
        }
        expect(
          seenUndated,
          isFalse,
          reason: 'work:${work.id} is dated but sorts after an undated work',
        );
        expect(
          year,
          greaterThanOrEqualTo(lastDated),
          reason: 'work:${work.id} breaks chronological order',
        );
        lastDated = year;
      }
    });

    test('a work with no tradition of its own inherits its author\'s', () {
      // Otherwise filtering to a tradition silently hides works that plainly
      // belong to it, and filing a record loosely becomes a way to lose it.
      for (final work in corpus.works) {
        final author = corpus.philosopher(work.authorId);
        if (work.traditions.isNotEmpty || author == null) continue;
        expect(
          corpus.traditionsOf(work),
          author.traditions,
          reason: 'work:${work.id} did not inherit ${author.id}\'s traditions',
        );
      }
    });

    test('an explicit tradition wins over the inherited one', () {
      // A work that broke with its author's tradition has to be able to say so.
      final tagged = corpus.works.where((it) => it.traditions.isNotEmpty);
      expect(tagged, isNotEmpty, reason: 'no work carries its own tradition');
      for (final work in tagged) {
        expect(corpus.traditionsOf(work), work.traditions, reason: work.id);
      }
    });

    test('every work is reachable by browsing, not only through its author', () {
      // The defect this replaced: works existed, had a detail screen, and could
      // be reached only from a philosopher's page or by knowing what to search
      // for.
      final browsable = corpus.worksChronologically.map((it) => it.id).toSet();
      expect(browsable, corpus.works.map((it) => it.id).toSet());
    });
  });

  group('Works in the knowledge graph', () {
    test('works take part at all', () {
      // For several sessions no relation touched a work: `EntityKind.work` was
      // structurally supported everywhere and never exercised, which is the
      // state in which an architecture quietly stops working.
      final touching = corpus.relations.where(
        (relation) =>
            relation.subject.kind == EntityKind.work ||
            relation.object.kind == EntityKind.work,
      );
      expect(touching, isNotEmpty);
    });

    test('a work uses the same relation system as everything else', () {
      // The point of the check: no Work-specific graph, no parallel API.
      const apology = EntityRef(EntityKind.work, 'apology');
      final edges = corpus.relationsFor(apology);
      expect(edges, isNotEmpty);
      expect(
        edges.any(
          (edge) =>
              edge.type == RelationType.preserved &&
              edge.object ==
                  const EntityRef(EntityKind.philosopher, 'socrates'),
        ),
        isTrue,
      );
    });

    test(
      'the far end sees the edge, with its confidence and its inverse label',
      () {
        const socrates = EntityRef(EntityKind.philosopher, 'socrates');
        final fromSocrates = corpus
            .relationsFor(socrates)
            .where((edge) => edge.object.kind == EntityKind.work)
            .toList();
        expect(fromSocrates, isNotEmpty);
        for (final edge in fromSocrates) {
          expect(edge.isInverseReading, isTrue);
          expect(edge.labelId, edge.type.inverseId);
          expect(edge.confidence, RelationConfidence.documented);
        }
      },
    );

    test('a work can be the subject of a claim about a concept', () {
      // Work → Concept through the graph rather than through a bare id list,
      // so the claim can carry a source and a confidence like any other.
      const republic = EntityRef(EntityKind.work, 'republic');
      final toConcepts = corpus
          .relationsFor(republic)
          .where((edge) => edge.object.kind == EntityKind.concept);
      expect(toConcepts, isNotEmpty);
      for (final edge in toConcepts) {
        expect(edge.isSupported, isTrue);
        expect(corpus.resolve(edge.object), isNotNull);
      }
    });

    test('every relation touching a work resolves at both ends', () {
      for (final relation in corpus.relations) {
        if (relation.subject.kind != EntityKind.work &&
            relation.object.kind != EntityKind.work) {
          continue;
        }
        expect(corpus.exists(relation.subject), isTrue, reason: '$relation');
        expect(corpus.exists(relation.object), isTrue, reason: '$relation');
      }
    });
  });

  group('The architecture holds at scale', () {
    test('nothing about works is capped at the size of today\'s corpus', () {
      // Guards against a limit creeping into a list that currently has fourteen
      // entries and will one day have thousands.
      expect(corpus.worksChronologically.length, corpus.works.length);
      expect(
        corpus.allEntities.whereType<Work>().length,
        corpus.works.length,
        reason: 'works are missing from the entity stream that feeds search',
      );
    });

    test('works are indexed for search like any other entity', () {
      for (final work in corpus.works) {
        expect(
          work.searchableStrings.where((it) => it.trim().isNotEmpty),
          isNotEmpty,
          reason: 'work:${work.id} would be unfindable',
        );
      }
    });
  });
}
