import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A school's page has to say what it is showing.
///
/// ## The defect this is written against
///
/// The school screen built a list of the school's philosophers and put the
/// heading "Key ideas" over it. Every one of the twenty-nine schools shipped
/// that way: a reader on Stoicism saw the heading "Key ideas" and underneath it
/// a card for Epictetus, who is a person.
///
/// The heading was not merely wrong, it was standing in the place of the
/// section that should have been there. Six schools have concepts recorded
/// against them — Stoicism has the dichotomy of control, Madhyamaka has
/// emptiness — and the screen never read that field at all, so the one thing a
/// heading called "Key ideas" promises was the one thing the page did not have.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpSchool(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue('/schools/$id'),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a school shows the ideas recorded against it', (tester) async {
    await pumpSchool(tester, 'stoicism');
    expect(
      find.text('The Dichotomy of Control'),
      findsOneWidget,
      reason:
          'Stoicism names one concept in the corpus and the page never read '
          'the field',
    );
  });

  testWidgets('a school shows its philosophers under a heading about people', (
    tester,
  ) async {
    await pumpSchool(tester, 'stoicism');
    expect(find.text('Epictetus'), findsOneWidget);
    expect(
      find.text('Philosophers'),
      findsOneWidget,
      reason: 'the philosophers were filed under "Key ideas"',
    );
  });

  testWidgets('every school with concepts renders each of them', (
    tester,
  ) async {
    for (final school in corpus.schools.where(
      (school) => school.conceptIds.isNotEmpty,
    )) {
      await pumpSchool(tester, school.id);
      for (final id in school.conceptIds) {
        final concept = corpus.concept(id);
        if (concept == null) continue;
        expect(
          find.text(concept.name.en),
          findsWidgets,
          reason: '${school.id} does not show ${concept.id}',
        );
      }
    }
  });
}
