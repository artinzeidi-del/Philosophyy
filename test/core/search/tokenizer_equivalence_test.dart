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
