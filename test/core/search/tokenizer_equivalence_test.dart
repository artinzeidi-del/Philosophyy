import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/search/text_normalizer.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';

/// The fast path and the general path agree, on the real corpus.
///
/// `tokenize` splits ASCII by hand and everything else with a Unicode-property
/// regex, because the regex cost 788 milliseconds per index build and the
/// reader paid it as a freeze on their first keystroke. Two implementations of
/// one rule is exactly the arrangement where they drift apart, and a drift here
/// does not crash: it quietly stops indexing some words.
///
/// So the two are compared against each other over every string the index
/// actually reads, rather than over a handful of examples chosen by whoever
/// wrote the fast path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The general path, kept here as the reference implementation.
  List<String> reference(String input) {
    final normalized = TextNormalizer.normalize(input);
    if (normalized.isEmpty) return const <String>[];
    return normalized
        .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  test('every string in the corpus tokenises identically both ways', () async {
    final corpus = await const AssetKnowledgeRepository().load();

    final strings = <String>[];
    for (final entity in corpus.allEntities) {
      strings.add(entity.name.en);
      final persian = entity.name.fa;
      if (persian != null) strings.add(persian);
      strings.addAll(entity.searchableStrings);
      strings.addAll(entity.oneLine.allVariants);
      for (final section in entity.article.sections) {
        strings.addAll(section.body.allVariants);
        final heading = section.heading;
        if (heading != null) strings.addAll(heading.allVariants);
      }
    }

    expect(strings, hasLength(greaterThan(5000)));

    final divergent = <String>[
      for (final string in strings)
        if (TextNormalizer.tokenize(string).join('|') !=
            reference(string).join('|'))
          string,
    ];

    expect(
      divergent,
      isEmpty,
      reason:
          'the ASCII fast path disagrees with the general path on '
          '${divergent.length} strings, first: '
          '${divergent.isEmpty ? '' : divergent.first}',
    );
  });

  test('every string in the corpus folds identically both ways', () async {
    // The same arrangement one level down. `normalize` used to remove the
    // zero-width characters, the Arabic diacritics and the combining marks
    // with three regular expressions, fold the letters in a loop, then trim
    // and collapse the spaces with a fourth — six passes and five throwaway
    // copies of every string. It is one walk of the runes now, because that
    // fold was 346 ms of the 630 ms an index build costs and the reader pays
    // it as a pause when the search screen opens.
    //
    // Every decision the passes made is a decision about a single character,
    // so the fused loop should give the same answer. Should is not a claim
    // worth making about matching, which fails silently: a word folded
    // differently is a word the reader cannot find, and nothing crashes.
    final corpus = await const AssetKnowledgeRepository().load();

    final strings = <String>[];
    for (final entity in corpus.allEntities) {
      strings.add(entity.name.en);
      final persian = entity.name.fa;
      if (persian != null) strings.add(persian);
      strings.addAll(entity.searchableStrings);
      strings.addAll(entity.oneLine.allVariants);
      for (final section in entity.article.sections) {
        strings.addAll(section.body.allVariants);
        final heading = section.heading;
        if (heading != null) strings.addAll(heading.allVariants);
      }
    }
    expect(strings, hasLength(greaterThan(5000)));

    final divergent = <String>[
      for (final string in strings)
        if (TextNormalizer.normalize(string) !=
            TextNormalizer.foldInSteps(string))
          string,
    ];
    expect(
      divergent,
      isEmpty,
      reason:
          'the fused fold disagrees with the stepwise one on '
          '${divergent.length} strings, first: '
          '${divergent.isEmpty ? '' : divergent.first}',
    );
  });

  test('the folds agree on the shapes a query arrives in', () {
    for (final query in <String>[
      'ابن‌سینا',
      'ابن سينا',
      '  فلسفهٔ   اسلامی  ',
      'Zärʾa Yaʿəqob',
      'Trần Nhân Tông',
      'Lǎozǐ',
      'ΣΩΚΡΆΤΗΣ',
      'Ἀριστοτέλης',
      'æsthetics',
      'straße',
      '\u200cleading joiner',
      'trailing joiner\u200c',
      'double\u200c\u200cjoiner',
      'ʿilm',
      'a\u0301ccent',
      '',
      '   ',
      '\u200b\u200e\u200f',
      '道可道，非常道',
      'योगश्चित्तवृत्तिनिरोधः',
    ]) {
      expect(
        TextNormalizer.normalize(query),
        TextNormalizer.foldInSteps(query),
        reason: 'the two folds differ on "$query"',
      );
    }
  });

  test('the paths agree on the punctuation a reader types', () {
    // The corpus is edited prose; a search box is not. These are the shapes a
    // query arrives in.
    for (final query in <String>[
      "aristotle's ethics",
      'plato, republic',
      'well-being',
      'a.d. 1250',
      '  spaced   out  ',
      '1098a',
      '§125',
      'q1',
      '',
      '...',
      '42',
      'x',
    ]) {
      expect(
        TextNormalizer.tokenize(query),
        reference(query),
        reason: 'disagreement on "$query"',
      );
    }
  });
}
