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

/// Every entry in the corpus, built from its own data.
///
/// The screenshot sweep covers twenty-one routes chosen by hand, and the widget
/// tests cover the entries whose shape someone thought to check. Between them
/// they leave four hundred and forty-six entries that no test has ever drawn.
///
/// That is where a data-shaped crash hides: one philosopher with a work whose
/// author is missing, one concept naming a term the taxonomy dropped, one work
/// whose structure nests deeper than the widget expects. Each is invisible
/// until the reader opens that one page.
///
/// So this opens all of them, in both languages, and fails on any exception the
/// framework reports while building. It is slow on purpose — it is the only
/// test in the suite that sees the whole corpus through the whole widget tree.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<String?> failureFor(
    WidgetTester tester,
    String route,
    String language,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.settings.language': language,
    });
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

    final thrown = tester.takeException();
    if (thrown != null) return '$route ($language): $thrown';
    return null;
  }

  for (final language in <String>['en', 'fa']) {
    testWidgets('every entry opens in ${language.toUpperCase()}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final problems = <String>[];
      for (final entity in corpus.allEntities) {
        final failure = await failureFor(tester, entity.ref.route, language);
        if (failure != null) problems.add(failure);
      }

      expect(
        problems,
        isEmpty,
        reason:
            '${problems.length} entries failed to build:\n'
            '${problems.take(20).join('\n')}',
      );
    });
  }
}
