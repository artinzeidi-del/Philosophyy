import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/search/search_index.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// Arguments are findable.
///
/// They were not. `allEntities` yielded philosophers, concepts, works and
/// schools, and the index is built from that, so every argument in the corpus
/// was invisible to search — a reader who had read about the drowning child
/// and wanted to find it again had no way back except the philosopher's entry.
/// Nothing failed, because nothing looked.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;
  late SearchIndex index;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
    index = SearchIndex.build(corpus);
  });

  Set<EntityRef> refsFor(String query) =>
      index.search(query).map((hit) => hit.entity.ref).toSet();

  test('every argument is in the index', () {
    final indexed = <EntityRef>{};
    for (final argument in corpus.arguments) {
      indexed.addAll(refsFor(argument.name.en).where((r) => r == argument.ref));
    }
    expect(
      indexed,
      hasLength(corpus.arguments.length),
      reason: 'an argument nobody can search for is content nobody can reach',
    );
  });

  test('an argument is found by its name in both languages', () {
    final anselm = corpus.argument('ontological-argument')!;
    expect(refsFor('ontological argument'), contains(anselm.ref));
    expect(refsFor(anselm.name.fa!), contains(anselm.ref));
  });

  test('an argument is found by a phrase from its article', () {
    // The prose is what a reader remembers. "Drowning child" appears nowhere
    // in the argument's name or summary — only in the article.
    expect(
      refsFor('drowning child'),
      contains(corpus.argument('singer-famine-argument')!.ref),
    );
  });

  test('every argument the search returns can be opened', () {
    // A hit whose route the router does not serve is worse than no hit: the
    // reader taps a result and lands on "this entry does not exist".
    for (final argument in corpus.arguments) {
      expect(
        corpus.resolve(argument.ref),
        isNotNull,
        reason: '${argument.ref} is searchable but does not resolve',
      );
    }
  });
}
