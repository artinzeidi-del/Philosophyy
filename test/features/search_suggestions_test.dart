import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The search screen offers something before a word is typed, and while one is.
///
/// The reported defect was "no suggestions appear in search". Two separate
/// things were behind it. The empty state was an illustration and two sentences
/// of advice — nothing to press. And `SearchIndex.suggestions`, which completes
/// a half-typed word, had been written, tested, and called by nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pumpSearch(
    WidgetTester tester, {
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(preferences);
    final store = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(PreferencesStore(store)),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue(AppRouter.search),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the empty state offers entries to open', (tester) async {
    await pumpSearch(tester);

    // Whatever the corpus connects to most — asserted as "the screen shows the
    // entries the provider chose", not as a fixed list of names, so adding
    // entries to the corpus cannot fail this.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhilosophiaApp)),
    );
    final expected = container.read(searchStartingPointsProvider);
    expect(expected, isNotEmpty);

    expect(
      find.text(expected.first.name.en),
      findsOneWidget,
      reason: 'the search screen opens with nothing to press',
    );
  });

  testWidgets('a half-typed word is offered completions', (tester) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'aris');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhilosophiaApp)),
    );
    final completions = container.read(searchCompletionsProvider);

    expect(
      completions,
      isNotEmpty,
      reason: 'the index knows words starting with "aris" and offered none',
    );
    expect(completions.every((word) => word.startsWith('aris')), isTrue);
    expect(find.text(completions.first), findsOneWidget);
  });

  testWidgets('a completion replaces only the word being typed', (
    tester,
  ) async {
    await pumpSearch(tester);

    await tester.enterText(find.byType(TextField), 'greek aris');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhilosophiaApp)),
    );
    final completion = container.read(searchCompletionsProvider).first;

    await tester.tap(find.text(completion));
    await tester.pumpAndSettle();

    final query = container.read(searchQueryProvider);
    expect(
      query,
      startsWith('greek '),
      reason: 'completing the last word rewrote the ones before it',
    );
    expect(query.trim(), endsWith(completion));
  });

  testWidgets('previous searches come back on the next visit', (tester) async {
    // Stored under the controller's own key, so this checks the reading half
    // against a value the writing half would have produced.
    await pumpSearch(
      tester,
      preferences: <String, Object>{
        'flutter.${RecentSearchesController.storageKey}': 'stoicism\nplato',
      },
    );

    expect(find.text('stoicism'), findsOneWidget);
    expect(find.text('plato'), findsOneWidget);
  });

  test('recording a search keeps the newest first and does not duplicate', () {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    return SharedPreferences.getInstance().then((store) async {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(PreferencesStore(store)),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(recentSearchesProvider.notifier);
      await controller.record('plato');
      await controller.record('stoicism');
      await controller.record('  Plato ');

      expect(container.read(recentSearchesProvider), <String>[
        'Plato',
        'stoicism',
      ]);

      for (var index = 0; index < RecentSearchesController.limit + 3; index++) {
        await controller.record('query $index');
      }
      expect(
        container.read(recentSearchesProvider),
        hasLength(RecentSearchesController.limit),
      );
    });
  });

  test('a device that refuses the write does not throw past the caller', () async {
    // Both callers fire and forget, so a throw here would surface as an
    // unhandled async error while the reader was doing something else. The
    // history is a shortcut back to a word they can retype; losing it is worth
    // a line in the log and nothing more. This path could not be written
    // against anything real until the history went through the store.
    final store = InMemoryStore()..failWrites = true;
    final container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final controller = container.read(recentSearchesProvider.notifier);
    await controller.record('plato');

    expect(container.read(recentSearchesProvider), <String>['plato']);
    expect(store.read(RecentSearchesController.storageKey), isNull);

    await controller.clear();
    expect(container.read(recentSearchesProvider), isEmpty);
  });
}
