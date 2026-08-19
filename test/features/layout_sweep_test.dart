import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders every screen at every width, in both languages, at two text sizes.
///
/// ## Why a sweep rather than more single tests
///
/// Every layout defect this project has shipped was found by looking at one
/// screen at one width in one language, and each fix was a constant chosen to
/// suit that one case. The section tiles overflowed English by twelve pixels;
/// the measured height that replaced the guess overflowed Persian by one. The
/// navigation row overflowed a 320-wide phone; the threshold that fixed it
/// dropped the label on a 390-wide phone with forty pixels to spare.
///
/// A row of numbers that each happen to be right is not a layout. The point of
/// sweeping is that a change has to survive every combination at once, so the
/// only way to pass is to be structurally unable to overflow — which is what
/// `Expanded` over `Flexible`, and measuring over guessing, were both for.
///
/// ## What counts as a failure
///
/// Anything the framework reports: an overflow, a failed assertion, a layout
/// that cannot be measured. `pumpWidget` surfaces all of them as test failures
/// without an explicit expectation, so the sweep asserts only the one thing
/// the framework would not notice — that the screen actually rendered, rather
/// than the route quietly falling through to the not-found page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  // Read from the content rather than written down, and read synchronously
  // because the test tree is declared before `setUpAll` runs. A hardcoded id
  // is a test that stops testing the day the content changes and says nothing
  // about it: `/works/plato-republic` was not a work id, so eleven work-page
  // checks spent a session measuring the not-found screen behind a green tick.
  final routes = <String, String>{
    'home': '/',
    'explore': '/explore',
    'search': '/search',
    'library': '/library',
    'settings': '/settings',
    'primer': '/start',
    'glossary': '/glossary',
    // Only the kinds with a page. Quotations, arguments and sources are shown
    // inside other articles by design, and the router registers no route for
    // them — a sweep that demanded pages for all seven would be asserting a
    // product decision nobody made.
    for (final kind in AppRouter.articleKinds)
      kind.id: '/${kind.routeSegment}/${_firstId(kind)}',
  };

  Future<void> pump(
    WidgetTester tester,
    String route, {
    required Size size,
    required String? language,
    required double textScale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Set on the platform rather than by wrapping the app in a `MediaQuery`.
    // Wrapping replaces the whole `MediaQueryData`, which zeroes the window
    // size — every screen then lays out against a 0x0 window and fails for a
    // reason the app has nothing to do with. A reader who has turned text size
    // up is not an edge case, and a layout that only fits at 1.0 fails the
    // readers most likely to need a reference work read to them.
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.${SettingsController.languageKey}': ?language,
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Every identifier in the shipped content, for the check that none of them
  // is ever shown to a reader.
  final ids = <String>{for (final kind in EntityKind.values) ..._idsOf(kind)};

  /// The narrowest phone still sold, a common phone, a tablet, and a desktop
  /// window. The first and the last are where layouts break: one has no room
  /// and the other has too much.
  const sizes = <String, Size>{
    'small phone': Size(320, 640),
    'phone': Size(390, 844),
    'tablet': Size(834, 1112),
    'desktop': Size(1440, 900),
    'phone landscape': Size(844, 390),
  };

  for (final language in <String?>[null, 'fa']) {
    final languageName = language ?? 'en';

    for (final size in sizes.entries) {
      // One test per screen rather than a loop inside one test. A loop stops at
      // the first failure and names the group, so a run that breaks on the
      // first of fourteen screens says nothing about the other thirteen — and
      // the whole point of a sweep is the list it produces.
      for (final scale in <double>[1.0, 1.5, 2.0]) {
        final scaleName = scale == 1.0 ? '' : ' at ${scale}x text';

        group('${size.key}, $languageName$scaleName', () {
          for (final route in routes.entries) {
            testWidgets('${route.key} lays out', (tester) async {
              await pump(
                tester,
                route.value,
                size: size.value,
                language: language,
                textScale: scale,
              );
              expect(
                find.text(_notFoundTitle(language)),
                findsNothing,
                reason:
                    '${route.value} fell through to the not-found screen, so '
                    'this sweep is not laying out the ${route.key} screen at '
                    'all',
              );

              expect(
                _identifiersOnScreen(tester, ids),
                isEmpty,
                reason:
                    '${route.value} prints an identifier where a name belongs',
              );
            });
          }
        });
      }
    }
  }
}

/// Any identifier printed on screen as if it were a name.
///
/// The relation card on Kant's page asked for the name of Avicenna's
/// contingency argument, got nothing back — arguments have no page, so the
/// lookup it used answered only for the four kinds that do — and printed
/// "criticised contingency-argument". Nothing failed, because no test reads
/// what a screen says the way a reader does.
///
/// Only hyphenated identifiers are looked for. A single-word id like `plato`
/// would collide with ordinary prose; `contingency-argument` cannot.
Set<String> _identifiersOnScreen(WidgetTester tester, Set<String> ids) {
  final found = <String>{};
  for (final element in find.byType(RichText).evaluate()) {
    final render = element.renderObject;
    if (render is! RenderParagraph) continue;
    for (final token in render.text.toPlainText().split(RegExp(r'\s+'))) {
      final word = token.replaceAll(RegExp(r'^\W+|\W+$'), '');
      if (word.contains('-') && ids.contains(word)) found.add(word);
    }
  }
  return found;
}

/// Every identifier of [kind] in the shipped content.
List<String> _idsOf(EntityKind kind) {
  final file = File('assets/content/${kind.routeSegment}.json');
  final parsed = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return <String>[
    for (final item in parsed[kind.routeSegment]! as List<dynamic>)
      (item as Map<String, dynamic>)['id']! as String,
  ];
}

/// The id of the first entity of [kind] in the shipped content.
///
/// The collections are named by the route segment in the asset files, which is
/// what lets one line cover all seven kinds instead of seven hand-written ids
/// that can each go stale on their own.
String _firstId(EntityKind kind) => _idsOf(kind).first;

/// The not-found headline, in whichever language the run is using.
String _notFoundTitle(String? language) =>
    language == 'fa' ? 'این مدخل وجود ندارد' : 'This entry does not exist';
