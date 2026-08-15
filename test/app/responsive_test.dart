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

  /// Scrolls the home screen until its entry points are built.
  ///
  /// The list is lazy and the entry points sit below the primer and the
  /// glossary, so they do not exist until the reader gets there.
  Future<void> scrollToEntryPoints(WidgetTester tester) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (find.byType(EntityCard).evaluate().isNotEmpty) return;
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  group('The front page leads somewhere', () {
    testWidgets('it lays itself out for the window, on one left edge', (
      tester,
    ) async {
      // The whole page used to sit in one ReadingColumn, centred: on a desktop
      // the heading started 180 logical pixels to the right of the cards under
      // it, which reads as a misalignment rather than as a measure, and two
      // thirds of the glass was empty.
      await pump(tester, desktop);
      // The entry points are below the fold now that the page offers the
      // primer and the glossary first, and the list is lazy — so they have to
      // be scrolled to before they can be measured.
      await scrollToEntryPoints(tester);

      final heading = tester.getRect(find.text(en.homeStartHere));
      final cards = tester
          .widgetList<EntityCard>(find.byType(EntityCard))
          .map((card) => tester.getRect(find.byWidget(card)))
          .toList();
      expect(cards, isNotEmpty);
      final leftmost = cards.map((r) => r.left).reduce((a, b) => a < b ? a : b);
      expect(
        (heading.left - leftmost).abs(),
        lessThan(1),
        reason: 'prose starts at ${heading.left}, cards at $leftmost',
      );
    });

    testWidgets('a desktop shows a row of entry points, not a column of one', (
      tester,
    ) async {
      await pump(tester, desktop);
      await scrollToEntryPoints(tester);
      final tops = tester
          .widgetList<EntityCard>(find.byType(EntityCard))
          .map((card) => tester.getRect(find.byWidget(card)).top)
          .toSet();
      expect(
        tops.length,
        lessThan(tester.widgetList<EntityCard>(find.byType(EntityCard)).length),
        reason: 'every entry point is on its own row',
      );
    });

    testWidgets('the taxonomy chips open Explore already filtered', (
      tester,
    ) async {
      // The front page offered four cards and a random button, and no route to
      // the other hundred and eighty-seven entries.
      await pump(tester, desktop);
      expect(find.text(en.homeBrowseByBranch), findsOneWidget);

      // Whichever branch the strip happens to offer first — the eight it shows
      // are chosen by how much is filed under them, so naming one here would
      // pin the test to today's corpus.
      final chipFinder = find
          .descendant(
            of: find.byKey(const ValueKey<String>('home-strip-branch')),
            matching: find.byType(ActionChip),
          )
          .first;
      final label = tester.widget<ActionChip>(chipFinder).label as Text;
      final branch = label.data!;

      // Scrolled into view before tapping: the strip can be built and still be
      // off-screen, and a tap dispatched outside the viewport is swallowed —
      // which looks exactly like a broken link and is not one.
      await tester.ensureVisible(chipFinder);
      await tester.pumpAndSettle();
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      // Explore opens on the branch axis with that term already selected.
      expect(find.text(en.homeBrowseByBranch), findsOneWidget);
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, branch),
      );
      expect(
        chip.selected,
        isTrue,
        reason: '"$branch" did not arrive selected',
      );
    });
  });

  group('Both halves of the taxonomy can be browsed', () {
    testWidgets('a reader can switch from traditions to branches', (
      tester,
    ) async {
      // Twenty-six branches were authored, labelled in both languages, and
      // reachable from nowhere: Explore filtered by tradition only, and the
      // `homeBrowseByBranch` string sat unused in the ARB file as evidence
      // that somebody had meant to build this. A reader looking for aesthetics
      // or political philosophy — which is how most people arrive at
      // philosophy — had no way to ask.
      await pump(tester, desktop);
      await openExplore(tester);

      expect(find.text(en.browseByTraditionShort), findsWidgets);
      expect(find.text(en.browseByBranchShort), findsWidgets);

      // On the tradition axis the chips are traditions.
      expect(find.widgetWithText(FilterChip, 'Ancient Greek'), findsOneWidget);

      await tester.tap(find.text(en.browseByBranchShort).last);
      await tester.pumpAndSettle();

      // On the branch axis they are branches, and the heading follows.
      expect(find.text(en.homeBrowseByBranch), findsOneWidget);
      expect(
        find.widgetWithText(FilterChip, 'Aesthetics'),
        findsOneWidget,
        reason: 'the branch chips are not being offered',
      );
      expect(find.widgetWithText(FilterChip, 'Ancient Greek'), findsNothing);
    });

    testWidgets('filtering by a branch narrows the whole screen', (
      tester,
    ) async {
      // Counting cards would measure the viewport rather than the filter —
      // the list is lazy, so roughly a screenful is built either way. What is
      // checked instead is that the entries on screen are the right ones.
      final expected = corpus.philosophersChronologically
          .where((p) => p.branches.contains('aesthetics'))
          .map((p) => p.name.en)
          .toList();
      expect(expected, isNotEmpty, reason: 'no aesthetics entries to test on');

      await pump(tester, desktop);
      await openExplore(tester);
      await tester.tap(find.text(en.browseByBranchShort).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Aesthetics'));
      await tester.pumpAndSettle();

      final cards = tester
          .widgetList<EntityCard>(find.byType(EntityCard))
          .toList();
      expect(cards, isNotEmpty, reason: 'a live filter led to an empty screen');
      expect(
        cards.first.title,
        expected.first,
        reason:
            'the first card is ${cards.first.title}, not an aesthetics entry',
      );
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
