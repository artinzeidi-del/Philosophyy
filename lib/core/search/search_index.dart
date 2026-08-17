import 'dart:math' as math;

import 'package:philosophyy/core/search/text_normalizer.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// Which part of an entity a token was found in.
///
/// A query matching a title means something quite different from the same query
/// matching the fourth paragraph of an article, so the field is carried through
/// scoring rather than flattened away.
enum MatchField {
  /// The display name or title.
  name(weight: 10),

  /// A name in the original script, a transliteration, or an alternative name.
  alternateName(weight: 8),

  /// The one-line summary.
  summary(weight: 4),

  /// A definition or other short descriptive field.
  definition(weight: 3),

  /// The body of the article.
  body(weight: 1);

  const MatchField({required this.weight});

  /// How much a match in this field counts toward the score.
  final int weight;
}

/// How closely a query token matched an indexed token.
enum MatchQuality {
  /// The tokens are identical after normalisation.
  exact(multiplier: 1.0),

  /// The indexed token starts with the query token, which is what a reader
  /// typing into a live search box produces on almost every keystroke.
  prefix(multiplier: 0.6),

  /// The tokens differ by a single character — a typo or a transliteration
  /// variant the folding table does not cover.
  fuzzy(multiplier: 0.3);

  const MatchQuality({required this.multiplier});

  /// How much this quality of match is discounted.
  final double multiplier;
}

/// One entity matched by a search, with enough detail to explain why.
class SearchHit implements Comparable<SearchHit> {
  const SearchHit({
    required this.entity,
    required this.score,
    required this.bestField,
    required this.bestQuality,
    required this.matchedTokens,
  });

  /// The entity found.
  final KnowledgeEntity entity;

  /// Relevance, higher is better.
  final double score;

  /// The most significant field the query matched in, used to tell the reader
  /// why a result is here — "matched in the article" is useful information when
  /// the title looks unrelated.
  final MatchField bestField;

  /// The closest quality of match achieved.
  final MatchQuality bestQuality;

  /// How many of the query's tokens matched at all.
  final int matchedTokens;

  @override
  int compareTo(SearchHit other) {
    final byScore = other.score.compareTo(score);
    if (byScore != 0) return byScore;
    // Ties break alphabetically so results never reshuffle between identical
    // queries, which is disorienting in a live-updating list.
    return entity.name.en.toLowerCase().compareTo(
      other.entity.name.en.toLowerCase(),
    );
  }

  @override
  String toString() =>
      'SearchHit(${entity.ref}, ${score.toStringAsFixed(2)}, ${bestField.name})';
}

/// An inverted index over the corpus.
///
/// ## Why this is hand-written rather than delegated to a package
///
/// The hard part of search here is not the data structure, which is a map from
/// token to postings. It is that a reader may look for one philosopher as
/// `Avicenna`, `Ibn Sīnā`, `ابن‌سینا` or `ابن سينا`, and must find him every
/// time. That behaviour comes from the normaliser and from indexing every name
/// variant an entity carries — neither of which a generic search dependency
/// would do for us, and both of which are the actual product requirement.
///
/// The index is built once when the corpus loads and then only read, so it is
/// safe to share across the app without synchronisation.
class SearchIndex {
  SearchIndex._(
    this._postings,
    this._entities,
    this._allTokens,
    this._exactNames,
  ) : _documentFrequency = <String, int>{
        for (final entry in _postings.entries)
          entry.key: entry.value.map((posting) => posting.ref).toSet().length,
      };

  /// Builds an index over everything in [corpus].
  factory SearchIndex.build(KnowledgeBase corpus) {
    final postings = <String, List<_Posting>>{};
    final entities = <EntityRef, KnowledgeEntity>{};
    final exactNames = <String, Set<EntityRef>>{};

    void index(EntityRef ref, String text, MatchField field) {
      for (final token in TextNormalizer.tokenize(text)) {
        // Single characters match far too much to be worth indexing, except in
        // scripts where one character is a whole word — Chinese, for instance,
        // where 仁 is exactly what a reader would type.
        if (token.length < 2 && !_isIdeographic(token)) continue;
        postings
            .putIfAbsent(token, () => <_Posting>[])
            .add(_Posting(ref, field));
      }
    }

    /// Remembers a name the reader could type in full.
    ///
    /// A name is indexed token by token, which is right for finding things and
    /// wrong for ranking them: «افلاطون‌گرایی» contains «افلاطون», so Platonism
    /// matched the query "Plato" in its *name* field, at the same weight as
    /// Plato — and once the school had a long article mentioning him, the body
    /// matches broke the tie the wrong way. Someone who types a name in full
    /// wants the thing with that name.
    void remember(EntityRef ref, String? name) {
      if (name == null) return;
      final key = TextNormalizer.tokenize(name).join(' ');
      if (key.isEmpty) return;
      exactNames.putIfAbsent(key, () => <EntityRef>{}).add(ref);
    }

    for (final entity in corpus.allEntities) {
      entities[entity.ref] = entity;
      index(entity.ref, entity.name.en, MatchField.name);
      remember(entity.ref, entity.name.en);
      final persianName = entity.name.fa;
      if (persianName != null) index(entity.ref, persianName, MatchField.name);
      remember(entity.ref, persianName);

      // searchableStrings carries native scripts, transliterations and
      // alternative names; the display name is already indexed above, so
      // anything here beyond it is an alternate.
      for (final variant in entity.searchableStrings) {
        index(entity.ref, variant, MatchField.alternateName);
      }

      for (final variant in entity.oneLine.allVariants) {
        index(entity.ref, variant, MatchField.summary);
      }

      for (final section in entity.article.sections) {
        for (final variant in section.body.allVariants) {
          index(entity.ref, variant, MatchField.body);
        }
        final heading = section.heading;
        if (heading != null) {
          for (final variant in heading.allVariants) {
            index(entity.ref, variant, MatchField.definition);
          }
        }
      }
    }

    return SearchIndex._(
      postings,
      entities,
      postings.keys.toList(growable: false),
      exactNames,
    );
  }

  static bool _isIdeographic(String token) {
    final code = token.runes.first;
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  final Map<String, List<_Posting>> _postings;
  final Map<EntityRef, KnowledgeEntity> _entities;

  /// How much being named exactly by the query is worth.
  ///
  /// Large enough that no amount of body text can overturn it, because no
  /// amount of body text should: the reader typed the name.
  static const double _exactNameBoost = 2.5;

  final List<String> _allTokens;

  /// Entities whose whole name is exactly this normalised string.
  ///
  /// A map rather than one entity per name, because two things can genuinely
  /// share a name and neither should be picked arbitrarily.
  final Map<String, Set<EntityRef>> _exactNames;

  /// How many distinct entities each token appears in.
  ///
  /// The basis of [_rarityOf]. Computed once at build time because it is a
  /// property of the corpus, not of a query.
  final Map<String, int> _documentFrequency;

  /// How much a match on [token] is worth, given how common the token is.
  ///
  /// ## Why this exists
  ///
  /// Without it, every occurrence counted the same, and a query of ordinary
  /// English lost to whichever article happened to repeat its filler words
  /// most. Searching "theory of forms" once returned the entry on illumination
  /// ahead of the entry actually called Theory of Forms: the illumination
  /// article says "of" and "form" often enough, in a long body, to beat a
  /// title match. The defect was always there and only showed once the corpus
  /// was large enough for some article to win on volume.
  ///
  /// Standard inverse document frequency: a token in nearly every entity
  /// carries almost no information about which one the reader wants, and a
  /// token in three carries a great deal. The floor keeps a universal token
  /// contributing something rather than nothing, so a query made entirely of
  /// common words still returns its best guess instead of an empty list.
  double _rarityOf(String token) {
    final frequency = _documentFrequency[token] ?? 1;
    return math.max(0.05, math.log(_entities.length / frequency));
  }

  /// Number of distinct tokens indexed.
  int get tokenCount => _postings.length;

  /// Number of entities indexed.
  int get entityCount => _entities.length;

  /// Searches for [query], returning hits ordered by relevance.
  ///
  /// Returns an empty list for a query with no usable tokens, rather than
  /// everything — a search box that shows the whole corpus when the reader
  /// types a comma is worse than one that shows nothing.
  List<SearchHit> search(String query, {int limit = 30}) {
    final queryTokens = TextNormalizer.tokenize(query);
    if (queryTokens.isEmpty) return const <SearchHit>[];

    // Accumulated per entity: total score, best field, best quality, and which
    // query tokens matched — the last so that a result matching two of two
    // tokens outranks one matching two of five.
    final scores = <EntityRef, double>{};
    final bestField = <EntityRef, MatchField>{};
    final bestQuality = <EntityRef, MatchQuality>{};
    final matched = <EntityRef, Set<int>>{};

    for (var index = 0; index < queryTokens.length; index++) {
      final token = queryTokens[index];
      for (final match in _matchesFor(token)) {
        final rarity = _rarityOf(match.token);

        // Occurrences are counted per entity and field before they are scored,
        // so that repetition saturates. Ten mentions in a body are better
        // evidence than one and nowhere near ten times better, and counting
        // them linearly is how a long article beats a title.
        final occurrences = <EntityRef, Map<MatchField, int>>{};
        for (final posting in match.postings) {
          final fields = occurrences.putIfAbsent(
            posting.ref,
            () => <MatchField, int>{},
          );
          fields[posting.field] = (fields[posting.field] ?? 0) + 1;
        }

        for (final entry in occurrences.entries) {
          final ref = entry.key;
          for (final field in entry.value.entries) {
            final contribution =
                field.key.weight *
                match.quality.multiplier *
                rarity *
                math.sqrt(field.value);
            scores.update(
              ref,
              (existing) => existing + contribution,
              ifAbsent: () => contribution,
            );
          }
          matched.putIfAbsent(ref, () => <int>{}).add(index);

          final best = entry.value.keys.reduce(
            (a, b) => a.weight >= b.weight ? a : b,
          );
          final currentField = bestField[ref];
          if (currentField == null || best.weight > currentField.weight) {
            bestField[ref] = best;
          }
          final currentQuality = bestQuality[ref];
          if (currentQuality == null ||
              match.quality.multiplier > currentQuality.multiplier) {
            bestQuality[ref] = match.quality;
          }
        }
      }
    }

    // Whoever is named by exactly this query, if anyone is.
    //
    // Typing a name in full is the least ambiguous thing a reader can do, and
    // it was losing: «افلاطون» reached Platonism through the first half of
    // «افلاطون‌گرایی» at full name weight, and the school's body text settled
    // the tie against Plato himself. A whole-name match is different in kind
    // from matching one token of a longer name, so it is scored that way
    // rather than by adjusting weights until this one case comes out right.
    final named = _exactNames[queryTokens.join(' ')] ?? const <EntityRef>{};

    final hits = <SearchHit>[];
    for (final entry in scores.entries) {
      final entity = _entities[entry.key];
      if (entity == null) continue;
      final tokensMatched = matched[entry.key]?.length ?? 0;
      // Covering more of the query is worth more than matching one term often,
      // so completeness multiplies rather than adds.
      final coverage = tokensMatched / queryTokens.length;
      hits.add(
        SearchHit(
          entity: entity,
          score:
              entry.value *
              (0.4 + 0.6 * coverage) *
              (named.contains(entry.key) ? _exactNameBoost : 1),
          bestField: bestField[entry.key] ?? MatchField.body,
          bestQuality: bestQuality[entry.key] ?? MatchQuality.fuzzy,
          matchedTokens: tokensMatched,
        ),
      );
    }

    hits.sort();
    return hits.length <= limit ? hits : hits.sublist(0, limit);
  }

  /// Suggestions for a partially typed query, drawn from indexed tokens.
  List<String> suggestions(String partial, {int limit = 8}) {
    final normalized = TextNormalizer.normalize(partial);
    if (normalized.length < 2) return const <String>[];
    final matches =
        _allTokens.where((token) => token.startsWith(normalized)).toList()
          ..sort((a, b) {
            final byLength = a.length.compareTo(b.length);
            return byLength != 0 ? byLength : a.compareTo(b);
          });
    return matches.length <= limit ? matches : matches.sublist(0, limit);
  }

  Iterable<_TokenMatch> _matchesFor(String token) sync* {
    final exact = _postings[token];
    if (exact != null) {
      yield _TokenMatch(token, exact, MatchQuality.exact);
    }

    // Prefix matching is what makes search feel live: a reader who has typed
    // "aris" should already be seeing Aristotle.
    if (token.length >= 2) {
      for (final candidate in _allTokens) {
        if (candidate != token && candidate.startsWith(token)) {
          yield _TokenMatch(
            candidate,
            _postings[candidate]!,
            MatchQuality.prefix,
          );
        }
      }
    }

    // Fuzzy matching is deliberately restricted to longer tokens. On short
    // tokens an edit distance of one matches so much that it drowns the
    // results it was meant to rescue.
    if (token.length >= 4) {
      for (final candidate in _allTokens) {
        if (candidate == token || candidate.startsWith(token)) continue;
        if ((candidate.length - token.length).abs() > 1) continue;
        if (_isWithinOneEdit(token, candidate)) {
          yield _TokenMatch(
            candidate,
            _postings[candidate]!,
            MatchQuality.fuzzy,
          );
        }
      }
    }
  }

  /// Whether [a] and [b] differ by at most one insertion, deletion or
  /// substitution.
  ///
  /// A bounded check rather than a full edit-distance computation: the answer
  /// needed is "is this within one edit", and the bounded form is a single pass
  /// instead of an n×m table, which matters when it runs against every indexed
  /// token on every keystroke.
  static bool _isWithinOneEdit(String a, String b) {
    final lengthDifference = (a.length - b.length).abs();
    if (lengthDifference > 1) return false;

    if (a.length == b.length) {
      var differences = 0;
      for (var index = 0; index < a.length; index++) {
        if (a.codeUnitAt(index) != b.codeUnitAt(index)) {
          differences++;
          if (differences > 1) return false;
        }
      }
      return differences == 1;
    }

    // Exactly one longer than the other: walk both, allowing a single skip in
    // the longer string.
    final shorter = a.length < b.length ? a : b;
    final longer = a.length < b.length ? b : a;
    var shortIndex = 0;
    var longIndex = 0;
    var skipped = false;
    while (shortIndex < shorter.length && longIndex < longer.length) {
      if (shorter.codeUnitAt(shortIndex) == longer.codeUnitAt(longIndex)) {
        shortIndex++;
        longIndex++;
        continue;
      }
      if (skipped) return false;
      skipped = true;
      longIndex++;
    }
    return true;
  }

  /// The mean number of postings per token, used by tests to catch an index
  /// that has silently stopped indexing most of the corpus.
  double get averagePostingsPerToken => _postings.isEmpty
      ? 0
      : _postings.values.fold<int>(0, (sum, list) => sum + list.length) /
            _postings.length;

  /// The longest indexed token, useful when diagnosing tokenisation faults.
  String get longestToken => _allTokens.isEmpty
      ? ''
      : _allTokens.reduce((a, b) => a.length >= b.length ? a : b);

  /// A rough measure of index size for diagnostics.
  int get postingCount =>
      _postings.values.fold<int>(0, (sum, list) => sum + list.length);

  /// The number of tokens sharing the most common prefix length, exposed so
  /// performance tests can assert the prefix scan has not become pathological.
  int get maxPostingsForOneToken => _postings.isEmpty
      ? 0
      : _postings.values.map((list) => list.length).reduce(math.max);
}

class _Posting {
  const _Posting(this.ref, this.field);

  final EntityRef ref;
  final MatchField field;
}

class _TokenMatch {
  const _TokenMatch(this.token, this.postings, this.quality);

  /// The indexed token that matched, which is not always the query token —
  /// rarity is a property of what was found, not of what was typed.
  final String token;

  final List<_Posting> postings;
  final MatchQuality quality;
}
