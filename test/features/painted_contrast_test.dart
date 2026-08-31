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

import '../support/painted_contrast.dart';

/// Reads every screen the way a reader does, and fails on anything unreadable.
///
/// The palette test checks the pairs the palette declares and has never been
/// wrong about them. Two screens still shipped illegible — Settings in dark
/// mode, an article's title in light mode — because in both the surface under
/// the text was one the screen painted itself, so the pairing existed nowhere
/// in the palette to be checked. Both were found by looking at a screenshot,
/// which is not a thing the build can do.
///
/// This walks the real render tree instead: every paragraph, the colours
/// actually painted behind it, and the ratio a reader would actually get.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pump(
    WidgetTester tester,
    String route, {
    required ThemeMode theme,
    String? language,
    Size size = const Size(420, 1400),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // The platform brightness is what `ThemeMode.system` follows, and it is
    // also what decides which scheme a `light`/`dark` choice lands on when the
    // test asks for one explicitly.
    tester.platformDispatcher.platformBrightnessTestValue =
        theme == ThemeMode.dark ? Brightness.dark : Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            PreferencesStore(await _preferences(theme, language)),
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

  /// Every screen a reader can reach without typing something first.
  const routes = <String, String>{
    'home': '/',
    'explore': '/explore',
    'search': '/search',
    'library': '/library',
    'settings': '/settings',
    'primer': '/start',
    'glossary': '/glossary',
    'a philosopher': '/philosophers/plato',
    'a concept': '/concepts/theory-of-forms',
    'a work': '/works/republic',
    'a school': '/schools/platonism',
  };

  for (final theme in <ThemeMode>[ThemeMode.dark, ThemeMode.light]) {
    final themeName = theme == ThemeMode.dark ? 'dark' : 'light';

    for (final language in <String?>[null, 'fa']) {
      final languageName = language ?? 'en';

      group('Painted contrast — $themeName, $languageName', () {
        for (final entry in routes.entries) {
          testWidgets('${entry.key} is readable', (tester) async {
            await pump(tester, entry.value, theme: theme, language: language);

            // A route that does not resolve renders the not-found screen,
            // which is a perfectly readable page — so this suite passed on it
            // and reported the screen it was asked for as checked. It cost a
            // real gap: `/works/plato-republic` is not a work id, and eleven
            // work-page pairings went unmeasured behind a green tick.
            expect(
              find.text(_notFoundTitle(language)),
              findsNothing,
              reason:
                  '${entry.value} did not resolve to an entry — this test is '
                  'measuring the not-found screen, not the screen it names',
            );

            final measured = PaintedContrast.measure(tester);

            // A run that resolved almost nothing is a broken check, not a
            // passing screen: a screen that failed to load, or a change to how
            // surfaces are painted, would leave this asserting over an empty
            // list and reporting success. The thinnest real screen — an empty
            // library — resolves seventeen.
            expect(
              measured.findings.length,
              greaterThan(10),
              reason:
                  'only ${measured.findings.length} pieces of text could be '
                  'resolved on ${entry.value} — the check is not looking at '
                  'the screen it thinks it is',
            );

            expect(
              measured.failures,
              isEmpty,
              reason:
                  '${entry.value} in $themeName/$languageName paints text a '
                  'reader cannot read:\n  '
                  '${measured.failures.join('\n  ')}',
            );
          });
        }
      });
    }
  }
}

/// The not-found headline, in whichever language the run is using.
String _notFoundTitle(String? language) =>
    language == 'fa' ? 'این مدخل وجود ندارد' : 'This entry does not exist';

Future<SharedPreferences> _preferences(ThemeMode theme, String? language) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'flutter.${SettingsController.themeKey}': switch (theme) {
      ThemeMode.dark => 'dark',
      ThemeMode.light => 'light',
      ThemeMode.system => 'system',
    },
    'flutter.${SettingsController.languageKey}': ?language,
  });
  return SharedPreferences.getInstance();
}
