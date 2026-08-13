import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';

/// Search is tested against the corpus that actually ships, not a fixture.
///
/// A fixture would prove the algorithm works on data chosen to make it work.
/// What matters is whether a reader typing a real name into the real product
/// finds the right entry, so these tests ask exactly that.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SearchIndex index;

  setUpAll(() async {
    final corpus = await const AssetKnowledgeRepository().load();
    index = SearchIndex.build(corpus);
  });

  /// The identifier of the top hit, for terse assertions.
  String topHitId(String query) {
    final hits = index.search(query);
    expect(hits, isNotEmpty, reason: 'no results for "$query"');
    return hits.first.entity.id;
  }

  /// Whether [id] appears anywhere in the results for [query].
  bool contains(String query, String id) =>
      index.search(query).any((hit) => hit.entity.id == id);

  group('The index', () {
    test('covers every entity in the corpus', () async {
      final corpus = await const AssetKnowledgeRepository().load();
      expect(index.entityCount, corpus.allEntities.length);
      expect(index.tokenCount, greaterThan(100));
    });
  });

  group('Index health', () {
    // The diagnostics exist so that a silent degradation — an index that has
    // stopped indexing article bodies, or a tokeniser that has started emitting
    // whole sentences — fails here rather than quietly making search worse.
    test('the index is dense enough to be doing its job', () {
      expect(
        index.postingCount,
        greaterThan(index.tokenCount),
        reason: 'most tokens should appear in more than one place',
      );
      expect(index.averagePostingsPerToken, greaterThan(1.0));
    });

    test('no token is absurdly long, which would mean tokenisation broke', () {
      expect(
        index.longestToken.length,
        lessThan(40),
        reason: 'longest token was "${index.longestToken}"',
      );
    });

    test('no single token dominates the index', () {
      // One token matching a large share of all postings would drag every
      // query that touches it.
      expect(index.maxPostingsForOneToken, lessThan(index.postingCount));
    });
  });

  group('Finding one person by every name they are known under', () {
    // This is the single most important behaviour in the search engine. Ibn
    // Sīnā is the hardest case in the corpus: two scripts, a Latinisation, a
    // transliteration with diacritics, and two keyboard spellings of the
    // Persian.
    const expected = 'ibn-sina';

    test('by Latinised name', () {
      expect(topHitId('Avicenna'), expected);
    });

    test('by transliteration without diacritics', () {
      expect(topHitId('Ibn Sina'), expected);
    });

    test('by transliteration with diacritics', () {
      expect(topHitId('Ibn Sīnā'), expected);
    });

    test('by Persian spelling', () {
      expect(topHitId('ابن‌سینا'), expected);
    });

    test('by Persian typed with a space instead of the ZWNJ', () {
      expect(topHitId('ابن سینا'), expected);
    });

    test('by Arabic-keyboard spelling', () {
      expect(topHitId('ابن سينا'), expected);
    });

    test('by the honorific he is known by in Persian', () {
      expect(contains('شیخ‌الرئیس', expected), isTrue);
    });
  });

  group('Cross-script and cross-language retrieval', () {
    test('an English query finds an entity through its Persian name', () {
      expect(topHitId('Plato'), 'plato');
      expect(topHitId('افلاطون'), 'plato');
    });

    test('a Greek term finds the concept it names', () {
      expect(contains('εὐδαιμονία', 'eudaimonia'), isTrue);
      expect(contains('eudaimonia', 'eudaimonia'), isTrue);
    });

    test('a single Chinese character is not discarded as too short', () {
      // 仁 is one character and a whole word; dropping short tokens would make
      // it unfindable.
      expect(contains('仁', 'ren'), isTrue);
    });

    test('Sanskrit transliteration folds', () {
      expect(contains('sunyata', 'sunyata'), isTrue);
      expect(contains('śūnyatā', 'sunyata'), isTrue);
    });
  });

  group('Live typing', () {
    test('a prefix finds the entity before the reader finishes typing', () {
      expect(contains('arist', 'aristotle'), isTrue);
      expect(contains('nietz', 'nietzsche'), isTrue);
    });

    test('suggestions complete a partial word', () {
      final suggestions = index.suggestions('socr');
      expect(suggestions, isNotEmpty);
      expect(suggestions.every((s) => s.startsWith('socr')), isTrue);
    });

    test('suggestions are withheld until there is something to go on', () {
      expect(index.suggestions('a'), isEmpty);
      expect(index.suggestions(''), isEmpty);
    });
  });

  group('Typo tolerance', () {
    test('a single-character typo still finds the entity', () {
      expect(contains('Aristotl', 'aristotle'), isTrue);
      expect(contains('Nietzche', 'nietzsche'), isTrue);
      expect(contains('Descarte', 'descartes'), isTrue);
    });

    test('fuzzy matching does not fire on short tokens', () {
      // "cat" is within one edit of several indexed tokens. Allowing that would
      // fill the results with noise, so short tokens are exact-or-prefix only.
      final hits = index.search('cat');
      for (final hit in hits) {
        expect(
          hit.bestQuality,
          isNot(MatchQuality.fuzzy),
          reason: '${hit.entity.ref} matched "cat" fuzzily',
        );
      }
    });
  });

  group('Ranking', () {
    test('a title match outranks a body match', () {
      final hits = index.search('Plato');
      expect(hits.first.entity.id, 'plato');
      expect(hits.first.bestField, MatchField.name);
      // Plato is discussed in several other articles, so those must also be
      // present — just below him.
      expect(hits.length, greaterThan(1));
    });

    test('matching more of the query ranks higher', () {
      final hits = index.search('theory of forms');
      expect(hits.first.entity.id, 'theory-of-forms');
    });

    test('results are ordered by descending score', () {
      final hits = index.search('philosophy');
      for (var i = 1; i < hits.length; i++) {
        expect(hits[i - 1].score, greaterThanOrEqualTo(hits[i].score));
      }
    });

    test('identical queries return identical order', () {
      // Ties broken non-deterministically make a live-updating result list
      // shuffle under the reader's finger.
      final first = index.search('the').map((hit) => hit.entity.id).toList();
      final second = index.search('the').map((hit) => hit.entity.id).toList();
      expect(first, second);
    });
  });

  group('Degenerate queries', () {
    test(
      'an empty or punctuation-only query returns nothing, not everything',
      () {
        expect(index.search(''), isEmpty);
        expect(index.search('   '), isEmpty);
        expect(index.search('!!! ,,, ---'), isEmpty);
      },
    );

    test('a query matching nothing returns an empty list', () {
      expect(index.search('zzzzqqqqxxxx'), isEmpty);
    });

    test('the result limit is honoured', () {
      final hits = index.search('the', limit: 3);
      expect(hits.length, lessThanOrEqualTo(3));
    });
  });

  group('Edit-distance helper', () {
    // Exercised through the public API above, but the boundary cases are worth
    // pinning down directly since a fault here degrades search silently.
    test('finds entities despite an inserted, deleted or changed letter', () {
      expect(contains('Socratees', 'socrates'), isTrue);
      expect(contains('Socrtes', 'socrates'), isTrue);
      expect(contains('Socrages', 'socrates'), isTrue);
    });

    test('two edits are too many', () {
      // "Socrgtez" changes both the fifth and the last letter of "socrates".
      // One edit is a typo worth rescuing; two is a different word.
      expect(
        index.search('Socrgtez').any((hit) => hit.entity.id == 'socrates'),
        isFalse,
      );
    });
  });
}
