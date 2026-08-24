import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where somebody was born is a fact the corpus holds and never showed.
///
/// ## The defect this is written against
///
/// Thirteen philosophers carry a birthplace and eleven a place of death, in
/// both languages, and no screen in the app read either field. Aristotle's page
/// gave his dates and not that he was born in Stagira and died in Chalcis.
///
/// The four shapes matter. Somebody who lived and died in one city should not
/// be told it twice, and a record with only one of the two must not print the
/// word "null" or an empty half-sentence — which is what a single format string
/// would have done for Confucius, whose place of death is not recorded.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpPhilosopher(WidgetTester tester, String id) async {
    tester.view.physicalSize = const Size(900, 2000);
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
          initialRouteProvider.overrideWithValue('/philosophers/$id'),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('two different places are both named', (tester) async {
    await pumpPhilosopher(tester, 'aristotle');
    expect(
      find.text('Born in Stagira, Chalcidice, died in Chalcis, Euboea.'),
      findsOneWidget,
    );
  });

  testWidgets('one place is not said twice', (tester) async {
    await pumpPhilosopher(tester, 'socrates');
    expect(find.text('Born and died in Athens.'), findsOneWidget);
  });

  testWidgets('an unrecorded death place leaves no half-sentence', (
    tester,
  ) async {
    await pumpPhilosopher(tester, 'confucius');
    expect(find.text('Born in State of Lu.'), findsOneWidget);
    expect(find.textContaining('died in'), findsNothing);
  });

  testWidgets('a philosopher with no place recorded gets no line', (
    tester,
  ) async {
    await pumpPhilosopher(tester, 'thales');
    expect(find.textContaining('Born in'), findsNothing);
    expect(find.textContaining('Born and died'), findsNothing);
  });
}
