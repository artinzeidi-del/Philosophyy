import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

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
    test('no entry can render as a blank article', () {
      // Every work and every school in the corpus opened with an empty space
      // where the article should be. Their sections are authored at
      // `standard`, the default reading level is `quick`, and `Article.at`
      // faithfully returned nothing — so the screen faithfully drew nothing.
      // Seventy-six entries shipped like that and every test passed, because
      // the content was well formed and the screen was doing as it was told.
      for (final entity in corpus.allEntities) {
        if (entity.article.isEmpty) continue;
        for (final depth in ContentDepth.values) {
          expect(
            entity.article.at(depth),
            isNotEmpty,
            reason: '${entity.ref} shows nothing at ${depth.id}',
          );
        }
      }
    });

    test('no section repeats another section of the same entry', () {
      // A deepening pass added a "standard" section to thirty entries, and
      // three of them restated a section the entry already had — Heidegger's
      // party membership was written twice, in different words, one above the
      // other. Nothing caught it: both sections were well formed, cited, and
      // bilingual. It was found by looking at a screenshot.
      //
      // Word overlap does not separate the cases: a legitimate pair on Rūmī
      // shares more vocabulary than the duplicate did. What does separate them
      // is a long identical run of words — restating a fact tends to reuse the
      // phrasing. Across the whole corpus the longest run between two genuine
      // sections is five words; the duplicate ran to nine.
      const maximumSharedRun = 6;
      final problems = <String>[];

      for (final entity in corpus.allEntities) {
        final sections = entity.article.sections;
        for (var i = 0; i < sections.length; i++) {
          for (var j = i + 1; j < sections.length; j++) {
            final shared = _longestSharedRun(
              sections[i].body.en,
              sections[j].body.en,
            );
            if (shared >= maximumSharedRun) {
              problems.add(
                '${entity.ref}: "${sections[i].id}" and "${sections[j].id}" '
                'share a run of $shared words',
              );
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

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

    test('every philosopher rests on a text, not only on the encyclopedia', () {
      // 147 of 191 entries once cited nothing but the Stanford Encyclopedia,
      // because the corpus held no text of theirs. That is one defect wearing
      // two coats: the entry is thin *and* it is unsourced, and an entry whose
      // only support is a tertiary summary is repeating what it read.
      //
      // Two philosophers legitimately have no text — Pythagoras and Hypatia
      // left no writing at all — and they are grounded in the ancient reports
      // that do exist rather than exempted, because a named report is evidence
      // and an encyclopedia entry about it is not.
      final unsupported = <String>[];
      for (final philosopher in corpus.philosophers) {
        final cited = <String>{
          for (final citation in philosopher.citations) citation.sourceId,
          for (final section in philosopher.article.sections)
            for (final citation in section.citations) citation.sourceId,
        };
        final rests = cited
            .map(corpus.source)
            .nonNulls
            .any((source) => source.kind.rank <= SourceKind.monograph.rank);
        if (!rests) unsupported.add(philosopher.id);
      }
      expect(
        unsupported,
        isEmpty,
        reason:
            'these entries cite only reference works: ${unsupported.join(', ')}',
      );
    });

    test('every philosopher offers more than one reading depth', () {
      // The reader can ask for more, and for 127 entries the control had
      // nothing to give: one `quick` paragraph was the whole article, so
      // turning the depth up changed nothing on the screen. A depth control
      // that does not work is worse than none, because it promises.
      final flat = corpus.philosophers
          .where(
            (philosopher) =>
                philosopher.article.sections
                    .map((section) => section.depth)
                    .toSet()
                    .length <
                2,
          )
          .map((philosopher) => philosopher.id)
          .toList();
      expect(
        flat,
        isEmpty,
        reason: 'these entries have only one depth: ${flat.join(', ')}',
      );
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

    test('every passage of authored prose names its sources', () {
      // Sourcing used to be uneven in a way a reader would notice: a
      // philosopher's standard section carried its citations and the in-depth
      // layer under it carried none, and most concept, school and work
      // sections carried none at all. The page ended with a reference list, so
      // nothing was strictly unsourced — but there was no way to tell which
      // passage rested on what, which is the part that matters.
      //
      // Quick sections are exempt by design: they are one-sentence summaries
      // of the sections below them, and a reference list under two lines is
      // noise rather than rigour.
      final bare = <String>[];
      for (final entity in corpus.allEntities) {
        for (final section in entity.article.sections) {
          if (section.depth == ContentDepth.quick) continue;
          if (section.citations.isNotEmpty) continue;
          bare.add('${entity.ref}: "${section.id}" (${section.depth.id})');
        }
      }
      expect(
        bare,
        isEmpty,
        reason:
            'these passages show the reader no source:\n  ${bare.join('\n  ')}',
      );
    });

    test('a quotation does not contradict its own attribution', () {
      // Found on screen rather than by any test: the opening couplet of the
      // Masnavī — a line every Persian reader knows — was displayed badged as
      // verified and captioned "corresponds to no located line". The audit
      // that removed a fabricated Rūmī line had put the genuine couplet in its
      // place and left the debunking note behind, so the app was warning
      // readers away from the one quotation on the card that was certainly
      // real.
      //
      // Two rules, both mechanical. `actualSource` names where a line really
      // comes from when it is attributed to the wrong person; on a verified
      // quotation it has nothing to say. And a note that reports failure to
      // trace the line cannot sit under a badge asserting it was traced.
      final untraced = RegExp(
        r'not (been )?(traced|identified|located)|no located|does not appear',
        caseSensitive: false,
      );
      final problems = <String>[];

      for (final quote in corpus.quotes) {
        if (quote.attribution != AttributionStatus.verified) continue;
        if (quote.actualSource != null) {
          problems.add(
            'quote:${quote.id} is verified and still carries an actualSource, '
            'which is the field for a line attributed to the wrong person',
          );
        }
        final note = quote.attributionNote?.en;
        if (note != null && untraced.hasMatch(note)) {
          problems.add(
            'quote:${quote.id} is badged verified and its note says the line '
            'could not be traced: "$note"',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
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
        reason: 'philosophers span only $traditions',
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

/// The longest run of consecutive words appearing in both [a] and [b].
///
/// Words only, lowercased, punctuation dropped — the interest is in reused
/// phrasing rather than in exact text.
int _longestSharedRun(String a, String b) {
  final first = _words(a);
  final second = _words(b);
  var longest = 0;
  for (
    var length = 3;
    length <= first.length && length <= second.length;
    length++
  ) {
    final grams = <String>{
      for (var i = 0; i + length <= first.length; i++)
        first.sublist(i, i + length).join(' '),
    };
    var found = false;
    for (var i = 0; i + length <= second.length; i++) {
      if (grams.contains(second.sublist(i, i + length).join(' '))) {
        found = true;
        break;
      }
    }
    if (!found) break;
    longest = length;
  }
  return longest;
}

List<String> _words(String text) =>
    RegExp(r'[A-Za-z]+')
        .allMatches(text)
        .map((match) => match.group(0)!.toLowerCase())
        .toList();
