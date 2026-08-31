import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A school has to be findable by someone looking around.
///
/// ## The defect this is written against
///
/// Explore is the screen for readers who would rather browse than search. It
/// lists philosophers, then works, then concepts — and never schools. Twenty-
/// nine schools carry full articles at three depths, in two languages, with
/// their own timelines, and the browse surface did not know they existed.
///
/// The only ways to one were to search for it by name, or to already be on the
/// page of a philosopher who belongs to it. Neither helps the reader who wants
/// to know what Stoicism is, or what schools the Hellenistic world produced —
/// which is the question Explore exists to answer.
///
/// Nothing in the screen argued for leaving them out: the comments explain why
/// works and concepts are filtered alongside the philosophers, and schools are
/// simply absent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpExplore(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1000, 3000);
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
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('browsing a tradition shows the schools it produced', (
    tester,
  ) async {
    // Hellenistic is the narrowest useful filter: ten philosophers and one
    // school, so everything fits without scrolling a lazy list.
    await pumpExplore(tester, '/explore?axis=tradition&term=hellenistic');
    expect(find.text('Stoicism'), findsOneWidget);
  });

  testWidgets('a filter that has no schools shows no empty section', (
    tester,
  ) async {
    // The heading must not appear over nothing, the way an empty works section
    // would not.
    final withoutSchools = corpus.taxonomy
        .ofKind(TaxonomyKind.tradition)
        .where(
          (term) => !corpus.schools.any(
            (school) => school.traditions.any(
              (id) => corpus.taxonomy.isUnder(id, term.id),
            ),
          ),
        );
    expect(
      withoutSchools,
      isNotEmpty,
      reason: 'the corpus has no tradition without a school to test with',
    );

    await pumpExplore(
      tester,
      '/explore?axis=tradition&term=${withoutSchools.first.id}',
    );
    expect(find.text('Schools'), findsNothing);
  });
}
