import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/features/shared/ui_states.dart';

/// What each screen does when the corpus will not load.
///
/// The reported shape of the defect: the search screen answered a query with
/// "Nothing found for “plato” — check the spelling", which blames the reader
/// for the app's own failure and leaves them nothing to press. Every other
/// screen said what had happened and offered to try again. This holds all of
/// them to the same answer, so the next screen added cannot quietly go back to
/// pretending the library is empty.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAt(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryStore()),
          corpusProvider.overrideWith(
            (ref) => Future<Never>.error(StateError('assets unreadable')),
          ),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  const routes = <String, String>{
    'home': AppRouter.home,
    'explore': AppRouter.explore,
    'search': AppRouter.search,
    'library': AppRouter.library,
    'glossary': AppRouter.glossary,
    'quiz': AppRouter.quiz,
    'primer': AppRouter.primer,
  };

  for (final entry in routes.entries) {
    testWidgets('${entry.key} says what happened and offers to try again', (
      tester,
    ) async {
      await pumpAt(tester, entry.value);

      expect(
        find.byType(ErrorView),
        findsOneWidget,
        reason: 'the ${entry.key} screen hid a failure instead of reporting it',
      );

      // The one action has to be reachable, not merely present: an error screen
      // with a button the reader cannot press is the same dead end.
      final retry = find.descendant(
        of: find.byType(ErrorView),
        matching: find.byType(FilledButton),
      );
      expect(retry, findsOneWidget);
      expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
    });
  }
}
