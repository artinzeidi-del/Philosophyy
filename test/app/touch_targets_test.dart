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

/// Nothing a finger has to hit is too small to hit.
///
/// The product is meant to be read on a phone, and every other check in this
/// suite looks at what a screen *says* rather than at whether it can be
/// operated. A control that is legible and eight pixels tall passes analysis,
/// passes the layout sweep, renders correctly in a screenshot, and is still
/// missed half the time by an adult thumb.
///
/// Both platform guidelines are applied — Material's forty-eight logical
/// pixels and Apple's forty-four points — at phone size, in both languages, on
/// every screen a reader can reach.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pump(WidgetTester tester, String route, String? language) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(
      language == null
          ? const <String, Object>{}
          : <String, Object>{'flutter.settings.language': language},
    );
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

  final routes = <String, String>{
    'home': AppRouter.home,
    'explore': AppRouter.explore,
    'search': AppRouter.search,
    'library': AppRouter.library,
    'settings': AppRouter.settings,
    'primer': AppRouter.primer,
    'glossary': AppRouter.glossary,
    'quiz': AppRouter.quiz,
    'article': '/philosophers/aristotle',
  };

  for (final language in <String?>[null, 'fa']) {
    final languageName = language ?? 'en';
    for (final route in routes.entries) {
      testWidgets('${route.key} in $languageName: every control is reachable', (
        tester,
      ) async {
        await pump(tester, route.value, language);

        // The framework's own guideline check rather than measuring widgets by
        // hand. A first version of this test measured the InkWell inside each
        // control and reported the article's tag chips as 25 pixels tall —
        // but Material puts a chip's tap-target padding *outside* its InkWell,
        // so the finger has more to hit than the ink suggests. Measuring the
        // wrong box would have produced a fix for a defect that was not there.
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));

        // Reachable is not the same as usable. The rank banner on the home
        // screen carried its name on a wrapper *around* the surface that took
        // the tap, so a screen reader announced a container that read the rank
        // and then a button with no name at all — and the button is the node a
        // reader lands on. A control nobody can name is a control nobody can
        // choose.
        //
        // The guideline reads a node's tooltip as its name, which is why the
        // app bar's icon buttons pass on their tooltips alone.
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      });
    }
  }
}
