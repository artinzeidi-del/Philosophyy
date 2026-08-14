import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Proves the app lays itself out for the screen it is actually on.
///
/// The breakpoints existed for three sessions and nothing consulted them: every
/// window got one narrow column with a bottom bar under it, so a tablet showed
/// a strip down the middle with two thirds of the glass empty and a desktop
/// stretched five destinations across a metre. Constants nobody reads are not a
/// responsive design, and nothing failed to say so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;
  late AppL10n en;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
    en = await AppL10n.delegate.load(const Locale('en'));
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openExplore(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.explore_outlined));
    await tester.pumpAndSettle();
  }

  /// Phone, tablet portrait, and a desktop window.
  const phone = Size(390, 844);
  const tablet = Size(834, 1112);
  const desktop = Size(1728, 1000);

  group('Where the navigation lives', () {
    testWidgets('a phone gets a bottom bar', (tester) async {
      await pump(tester, phone);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('a tablet gets a side rail, not a bottom bar', (tester) async {
      // A bottom bar on a tablet puts the controls as far from the hand
      // holding it as the screen allows.
      await pump(tester, tablet);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('a desktop window gets a side rail, not a bottom bar', (
      tester,
    ) async {
      await pump(tester, desktop);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('every destination is named at every width', (tester) async {
      // The first version of the rail showed icons only, which asks a reader to
      // learn five glyphs before they can navigate — and the bottom bar it
      // replaced never asked that. The second version showed labels but sized
      // the rail so they read "Explo…" and "Setti…".
      for (final size in const <Size>[phone, tablet, desktop]) {
        await pump(tester, size);
        for (final label in <String>[
          en.navHome,
          en.navExplore,
          en.navSearch,
          en.navLibrary,
          en.navSettings,
        ]) {
          expect(
            find.text(label),
            findsWidgets,
            reason: '"$label" is not shown at $size',
          );
          // Asking the render object whether it had to clip, rather than
          // re-measuring the string. Two earlier versions of this check were
          // wrong in ways worth recording: one measured with the widget's own
          // `style`, which is null when the style comes from an ancestor, and
          // so measured the default font; the next compared the laid-out width
          // against `getMaxIntrinsicWidth` and reported the bottom bar as
          // truncated when the rendered bar was in fact complete at 360pt. The
          // second sent me off to shrink the label font for a defect that did
          // not exist. `didExceedMaxLines` is what the reader actually sees.
          for (final box in find.text(label).evaluate()) {
            final paragraph = box.renderObject! as RenderParagraph;
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: '"$label" is clipped at $size',
            );
          }
        }
      }
    });
  });

  group('How browsing uses the width', () {
    Future<List<double>> cardWidths(WidgetTester tester, Size size) async {
      await pump(tester, size);
      await openExplore(tester);
      return tester
          .widgetList<EntityCard>(find.byType(EntityCard))
          .map((card) => tester.getSize(find.byWidget(card)).width)
          .toList();
    }

    testWidgets('a phone shows one card per row', (tester) async {
      final widths = await cardWidths(tester, phone);
      expect(widths, isNotEmpty);
      // One column: a card takes the width it is given, minus the gutters.
      expect(widths.first, greaterThan(phone.width * 0.8));
    });

    testWidgets('a tablet shows two cards per row', (tester) async {
      final widths = await cardWidths(tester, tablet);
      expect(widths.length, greaterThan(2));
      expect(widths.first, lessThan(tablet.width * 0.6));
      expect(widths.first, greaterThan(tablet.width * 0.3));
    });

    testWidgets('every card in a grid is exactly the same size', (
      tester,
    ) async {
      // A row of cards at different widths or heights reads as a bug even when
      // the reader cannot say why, and the fixed grid extent only pays off if
      // the summary is clamped to match it.
      await pump(tester, desktop);
      await openExplore(tester);
      final sizes = tester
          .widgetList<EntityCard>(find.byType(EntityCard))
          .map((card) => tester.getSize(find.byWidget(card)))
          .toSet();
      expect(sizes, hasLength(1), reason: 'cards were laid out at $sizes');
    });

    testWidgets('content stops widening past the content measure', (
      tester,
    ) async {
      // Cards do not need the reading measure, but a card stretched across a
      // large monitor puts its date and its summary a head-turn apart.
      await pump(tester, desktop);
      await openExplore(tester);
      final row = tester
          .widgetList<EntityCard>(find.byType(EntityCard))
          .map((card) => tester.getRect(find.byWidget(card)))
          .toList();
      final left = row.map((r) => r.left).reduce((a, b) => a < b ? a : b);
      final right = row.map((r) => r.right).reduce((a, b) => a > b ? a : b);
      expect(
        right - left,
        lessThanOrEqualTo(Breakpoints.contentMaxWidth),
        reason: 'the grid spans ${right - left} logical pixels',
      );
    });
  });
}
