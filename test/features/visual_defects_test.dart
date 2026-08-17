import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/gradient_surfaces.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Covers four defects that only a screenshot found.
///
/// Each of these passed every existing test. They were visible, wrong, and
/// invisible to a widget tree that was structurally correct — which is the
/// class of defect this file exists for.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Future<void> pump(
    WidgetTester tester,
    String route, {
    Size size = const Size(390, 844),
    Map<String, Object> preferences = const <String, Object>{},
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(preferences);
    final instance = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(instance),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(UserLibrary.empty),
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('The section tiles', () {
    testWidgets('keep their size as the window grows', (tester) async {
      // A fixed column count with an aspect ratio ties the tile's height to
      // the window's width. On a tablet that produced two 580-pixel squares
      // holding an icon and six words, with the text stranded at the bottom
      // of an acre of empty card.
      final sizes = <Size, double>{};
      for (final size in const <Size>[
        Size(390, 844),
        Size(834, 1112),
        Size(1440, 1000),
      ]) {
        await pump(tester, '/', size: size);
        final tiles = find.byType(TileCard);
        expect(tiles, findsWidgets, reason: 'no section tiles at $size');
        sizes[size] = tester.getSize(tiles.first).width;
      }

      for (final entry in sizes.entries) {
        expect(
          entry.value,
          lessThan(260),
          reason:
              'a tile is ${entry.value} logical pixels wide at ${entry.key}',
        );
      }
    });

    testWidgets('the front page does not overflow anywhere, in either '
        'language', (tester) async {
      // Persian runs longer than English almost everywhere, and a fixed height
      // that fits one does not necessarily fit the other. This has caught two
      // separate widgets already: the section tiles, and then the entry cards,
      // whose grid pins them to 220 pixels — adding the coloured initial made
      // the header one pixel taller in Persian and the card overflowed.
      for (final language in const <String?>[null, 'fa']) {
        for (final size in const <Size>[
          Size(320, 700),
          Size(390, 844),
          Size(834, 1112),
          Size(1000, 3000),
        ]) {
          await pump(
            tester,
            '/',
            size: size,
            preferences: language == null
                ? const <String, Object>{}
                : <String, Object>{'flutter.settings.language': language},
          );
          expect(
            tester.takeException(),
            isNull,
            reason:
                'something on the front page overflowed at $size in '
                '${language ?? 'en'}',
          );
        }
      }
    });
  });

  group('The glossary', () {
    test('never prints the same word twice on one card', () {
      // «قیاس» appeared twice on the English card for "Analogy" — once as the
      // Persian translation in the header, once as the original underneath.
      // The guard compared the original against the *active* language only,
      // so it fired in Persian and not in English.
      final duplicates = corpus.glossary
          .where(
            (term) =>
                term.nativeTerm != null &&
                (term.nativeTerm == term.term.en ||
                    term.nativeTerm == term.term.fa),
          )
          .map((term) => term.id)
          .toList();

      // The content may legitimately carry such a term; what must not happen
      // is the card printing it twice. This asserts the data case exists so
      // the widget test below is testing something real.
      expect(
        duplicates,
        isNotEmpty,
        reason:
            'no term now repeats its own name, so the widget test below '
            'no longer proves anything — pick a different fixture',
      );
    });

    testWidgets('shows a repeated original once', (tester) async {
      final repeated = corpus.glossary.firstWhere(
        (term) => term.nativeTerm != null && term.nativeTerm == term.term.fa,
      );
      await pump(tester, '/glossary?term=${repeated.id}');

      expect(
        find.text(repeated.nativeTerm!),
        findsOneWidget,
        reason:
            '"${repeated.nativeTerm}" is printed more than once on the '
            '${repeated.id} card',
      );
    });
  });

  group('The card initials', () {
    test('skip a leading article', () {
      // "The Forms" showed a T, which tells a reader nothing and files every
      // title beginning with an article under the same letter.
      expect(entityInitial('The Forms'), 'F');
      expect(entityInitial('A Theory of Justice'), 'T');
      expect(entityInitial('An Enquiry'), 'E');
      // And leaves alone a name that merely begins with those letters.
      expect(entityInitial('Thales'), 'T');
      expect(entityInitial('Anaxagoras'), 'A');
    });

    test('take a whole grapheme, in any script', () {
      expect(entityInitial('افلاطون'), 'ا');
      expect(entityInitial('Πλάτων'), 'Π');
      expect(entityInitial('  '), '?');
      expect(entityInitial(''), '?');
    });

    test('every entity in the corpus gets a usable initial', () {
      for (final entity in corpus.allEntities) {
        final glyph = entityInitial(entity.name.en);
        expect(
          glyph,
          isNot('?'),
          reason: '${entity.ref} has no initial to show',
        );
        expect(
          glyph.characters.length,
          1,
          reason: '${entity.ref} produced "$glyph", which is not one glyph',
        );
      }
    });
  });

  group('An empty state', () {
    testWidgets('is centred, not pinned to the left edge', (tester) async {
      // An empty state is the whole screen. A short heading against the left
      // edge of a blank page reads as content that failed to load rather than
      // as a considered state.
      await pump(tester, '/library');
      final en = await AppL10n.delegate.load(const Locale('en'));

      final heading = tester.getRect(find.text(en.libraryEmptyTitle));
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(
        (heading.center.dx - screen.center.dx).abs(),
        lessThan(2),
        reason:
            'the empty state sits at ${heading.center.dx}, not the screen '
            'centre of ${screen.center.dx}',
      );
    });
  });
}
