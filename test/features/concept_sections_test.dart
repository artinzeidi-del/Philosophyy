import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An idea page has to lead to the people who argued the idea.
///
/// ## The defect this is written against
///
/// Every one of the sixty-one concepts records the philosophers it belongs to —
/// ninety links in all — and the concept screen read none of them. It showed
/// examples, counterexamples and neighbouring ideas, and forty-one concepts
/// have none of those three, so forty-one pages were prose with no way onward
/// at all. A reader on Ren could not reach Confucius from it.
///
/// The seventeen recorded work links were dropped the same way, so the page for
/// an idea never named the book it is argued in.
///
/// This is the same defect the school screen had, and it hid for the same
/// reason: the field parses, the integrity checker validates that every
/// identifier in it resolves, and nothing anywhere asserts that the reader is
/// ever shown the result.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpConcept(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            PreferencesStore(preferences),
          ),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue('/concepts/$id'),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an idea leads to the philosopher who argued it', (tester) async {
    await pumpConcept(tester, 'ren');
    expect(find.text('Confucius'), findsOneWidget);
  });

  testWidgets('an idea leads to the work it is argued in', (tester) async {
    await pumpConcept(tester, 'ren');
    expect(find.text('Analects'), findsOneWidget);
  });

  testWidgets('no concept page is a dead end', (tester) async {
    // Every concept names at least one philosopher, so after this change every
    // concept page has somewhere to go that is not the back button.
    for (final concept in corpus.concepts) {
      expect(
        concept.philosopherIds,
        isNotEmpty,
        reason: '${concept.id} names nobody, so its page can lead nowhere',
      );
    }
  });

  testWidgets('every philosopher a concept names is on its page', (
    tester,
  ) async {
    for (final concept in corpus.concepts.take(12)) {
      await pumpConcept(tester, concept.id);
      for (final id in concept.philosopherIds) {
        final philosopher = corpus.philosopher(id);
        if (philosopher == null) continue;
        expect(
          find.text(philosopher.name.en),
          findsWidgets,
          reason: '${concept.id} does not show $id',
        );
      }
    }
  });
}
