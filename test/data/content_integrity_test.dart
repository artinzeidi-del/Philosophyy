import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// Loads the corpus that actually ships and holds it to the content policy.
///
/// This is the test that stops the reference work from rotting. Content is
/// hand-authored across eight files that reference each other by identifier,
/// so a rename in one file silently breaks links in another — and a broken link
/// in a reference work is not a cosmetic problem, it is the product failing at
/// the one thing it exists to do.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  group('The shipped corpus', () {
    test('loads and parses', () {
      expect(corpus.philosophers, isNotEmpty);
      expect(corpus.concepts, isNotEmpty);
      expect(corpus.works, isNotEmpty);
      expect(corpus.schools, isNotEmpty);
      expect(corpus.quotes, isNotEmpty);
      expect(corpus.arguments, isNotEmpty);
      expect(corpus.sources, isNotEmpty);
      expect(corpus.relations, isNotEmpty);
    });

    test('has no dangling cross-references', () {
      final violations = corpus.findIntegrityViolations();
      expect(
        violations,
        isEmpty,
        reason:
            'Every identifier in the corpus must resolve. Violations:\n'
            '${violations.join('\n')}',
      );
    });

    test('every entity is reachable by the route its reference produces', () {
      for (final entity in corpus.allEntities) {
        expect(
          corpus.exists(entity.ref),
          isTrue,
          reason: '${entity.ref} does not resolve back to itself',
        );
        expect(
          entity.ref.route,
          startsWith('/${entity.ref.kind.routeSegment}/'),
          reason: '${entity.ref} produces a malformed route',
        );
      }
    });

    test('every reference parses back from its canonical form', () {
      for (final entity in corpus.allEntities) {
        final round = EntityRef.tryParse(entity.ref.canonical);
        expect(
          round,
          entity.ref,
          reason: '${entity.ref.canonical} did not round-trip',
        );
      }
    });
  });

  group('Editorial policy', () {
    test('every entity has a one-line summary in both languages', () {
      for (final entity in corpus.allEntities) {
        expect(
          entity.oneLine.en.trim(),
          isNotEmpty,
          reason: '${entity.ref} has no English one-line summary',
        );
        expect(
          entity.oneLine.isTranslated,
          isTrue,
          reason:
              '${entity.ref} has no Persian one-line summary. The product is '
              'bilingual by construction; an untranslated entry is incomplete, '
              'not merely unpolished.',
        );
      }
    });

    test('every authored section carries text in both languages', () {
      for (final entity in corpus.allEntities) {
        for (final section in entity.article.sections) {
          expect(
            section.body.isTranslated,
            isTrue,
            reason: '${entity.ref} section "${section.id}" has no Persian text',
          );
        }
      }
    });

    test('every non-factual passage cites a source', () {
      for (final entity in corpus.allEntities) {
        expect(
          entity.article.meetsCitationPolicy,
          isTrue,
          reason:
              '${entity.ref} makes an interpretive or contested claim without '
              'citing anything. Marking a claim as interpretation and then not '
              'saying whose interpretation it is helps nobody.',
        );
      }
    });

    test('every quotation satisfies the attribution rules', () {
      for (final quote in corpus.quotes) {
        expect(
          quote.isPublishable,
          isTrue,
          reason:
              'quote:${quote.id} claims "${quote.attribution.id}" without the '
              'support that status requires',
        );
      }
    });

    test('verified quotations point at a source that exists', () {
      for (final quote in corpus.quotes.where(
        (q) => q.attribution == AttributionStatus.verified,
      )) {
        final citation = quote.citation;
        expect(citation, isNotNull, reason: 'quote:${quote.id}');
        expect(
          corpus.source(citation!.sourceId),
          isNotNull,
          reason: 'quote:${quote.id} cites missing source ${citation.sourceId}',
        );
      }
    });

    test('quotations that need a caveat are not offered for sharing', () {
      // Sharing a misattributed line is precisely how misattribution spreads,
      // so the two flags must never both be true.
      for (final quote in corpus.quotes) {
        expect(
          quote.needsCaveat && quote.isShareable,
          isFalse,
          reason: 'quote:${quote.id} is both caveated and shareable',
        );
      }
    });

    test('no source carries an identifier or page range unless it is real', () {
      // The content policy forbids inventing bibliographic detail. Nothing in
      // the shipped corpus should carry a DOI, ISBN or page range at all yet;
      // when one is added it must come from the physical source in hand. This
      // test is the tripwire for that rule.
      for (final source in corpus.sources) {
        expect(
          source.identifier,
          isNull,
          reason:
              'source:${source.id} has an identifier. If it was checked '
              'against the actual publication, update this test; if it was '
              'reconstructed from memory, remove it.',
        );
        expect(
          source.pages,
          isNull,
          reason: 'source:${source.id} has a page range; see above.',
        );
      }
    });
  });

  group('Coverage', () {
    test('the corpus is not confined to one tradition', () {
      // A product claiming to cover world philosophy fails silently if its
      // content drifts back toward the European canon, because nothing breaks.
      final traditions = corpus.philosophers
          .expand((philosopher) => philosopher.traditions)
          .toSet();
      expect(
        traditions.length,
        greaterThanOrEqualTo(6),
        reason: 'philosophers span only ${traditions.map((t) => t.id)}',
      );
    });

    test('philosophers can be ordered chronologically', () {
      final ordered = corpus.philosophersChronologically;
      expect(ordered, isNotEmpty);
      for (var index = 1; index < ordered.length; index++) {
        expect(
          ordered[index].timelineAnchor!.year,
          greaterThanOrEqualTo(ordered[index - 1].timelineAnchor!.year),
          reason: 'timeline ordering is not monotonic',
        );
      }
    });

    test('every philosopher with works has them resolvable', () {
      for (final philosopher in corpus.philosophers) {
        for (final workId in philosopher.workIds) {
          expect(
            corpus.work(workId),
            isNotNull,
            reason: 'philosopher:${philosopher.id} lists missing work $workId',
          );
        }
      }
    });

    test('the graph connects entities in both directions', () {
      // Authored one way, readable both ways: the relation from Socrates to
      // Plato must be visible on Plato's page as well.
      const socrates = EntityRef(EntityKind.philosopher, 'socrates');
      const plato = EntityRef(EntityKind.philosopher, 'plato');

      expect(
        corpus.relationsFor(socrates).any((r) => r.object == plato),
        isTrue,
        reason: 'the authored direction is missing',
      );
      expect(
        corpus.relationsFor(plato).any((r) => r.object == socrates),
        isTrue,
        reason: 'the inverse reading is missing',
      );
      expect(
        corpus
            .relationsFor(plato)
            .firstWhere((r) => r.object == socrates)
            .isInverseReading,
        isTrue,
        reason:
            'the inverse reading is not marked as inverse, so the '
            'interface would label it "influenced" instead of "influenced by"',
      );
    });
  });
}
