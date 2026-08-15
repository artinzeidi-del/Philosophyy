import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/format/number_format.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the glossary, the primer and the Persian half of the product to the
/// standard the rest of it is held to.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;
  late AppL10n fa;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
    fa = await AppL10n.delegate.load(const Locale('fa'));
  });

  Future<void> pump(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          corpusProvider.overrideWith((ref) => corpus),
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('The glossary is reachable and complete', () {
    test('every term has both languages', () {
      // A bilingual product whose glossary is half English is a glossary the
      // Persian reader cannot use, and it is the half the product says it
      // favours.
      for (final term in corpus.glossary) {
        expect(term.term.fa, isNotNull, reason: '${term.id} has no Persian');
        expect(
          term.shortDefinition.fa,
          isNotNull,
          reason: '${term.id} has no Persian definition',
        );
        final long = term.longDefinition;
        if (long != null) {
          expect(long.fa, isNotNull, reason: '${term.id} long is English-only');
        }
      }
    });

    test('every term a definition offers an entry for actually has one', () {
      // Checked at load now, so this is the tripwire for the check itself.
      expect(corpus.findIntegrityViolations(), isEmpty);
    });

    test('search finds a term the corpus defines', () {
      // The glossary existed and search knew nothing about it: a reader
      // looking for "dialectic" was told there were no results while the
      // product held a definition of exactly that word.
      expect(
        corpus.glossaryMatching('dialectic').map((term) => term.id),
        contains('dialectic'),
      );
      expect(
        corpus.glossaryMatching('قیاس').map((term) => term.id),
        isNotEmpty,
        reason: 'a Persian query finds nothing in the glossary',
      );
    });

    test('a query too short to mean anything matches nothing', () {
      expect(corpus.glossaryMatching('a'), isEmpty);
      expect(corpus.glossaryMatching(''), isEmpty);
    });
  });

  group('Arriving from a link', () {
    testWidgets('the term asked for is the first one shown', (tester) async {
      // Scrolling to it was the first attempt and it does not work: the list
      // is lazy, so the card does not exist to be scrolled to, and the reader
      // landed at the top with the word they asked about expanded somewhere
      // below the fold — which looks exactly like a link that did nothing.
      await pump(tester, '/glossary?term=dialectic');
      final en = await AppL10n.delegate.load(const Locale('en'));
      final expected = corpus.glossaryTerm('dialectic')!;

      // Its long definition is on screen, which only happens for the linked
      // term — every other card starts collapsed.
      expect(find.text(expected.longDefinition!.en), findsOneWidget);
      expect(find.text(en.glossaryTitle), findsWidgets);
    });
  });

  group('The primer', () {
    test('is ordered and every step leads somewhere real', () {
      expect(corpus.primer, isNotEmpty);
      for (final step in corpus.primer) {
        expect(step.title.fa, isNotNull, reason: '${step.id} has no Persian');
        expect(step.body.fa, isNotNull, reason: '${step.id} body is English');
        for (final ref in step.reads) {
          expect(
            corpus.resolve(ref),
            isNotNull,
            reason: '${step.id} points at $ref, which does not exist',
          );
        }
      }
    });
  });

  group('Persian typography', () {
    test('counted strings are set in Persian digits', () {
      // `flutter gen-l10n` formats the numbers inside plural messages itself,
      // in Latin digits whatever the locale — so "Step 1 of 9" and "3 results"
      // arrived in Persian sentences with Western numerals, which is the
      // typographic equivalent of switching alphabet mid-word.
      for (final text in <String>[
        fa.primerStepLabel(1, 9),
        fa.searchResultCount(3),
        fa.libraryItemCount(5),
        fa.argumentObjections(2),
        fa.filterShowMore(16),
      ]) {
        final localized = AppNumbers.localizeDigits(text, AppLanguage.fa);
        expect(
          RegExp(r'[0-9]').hasMatch(localized),
          isFalse,
          reason: 'Latin digits survive in "$localized"',
        );
      }
    });

    test('English is left alone', () {
      expect(
        AppNumbers.localizeDigits('Step 1 of 9', AppLanguage.en),
        'Step 1 of 9',
      );
    });
  });

  group('Reaching the new sections', () {
    testWidgets('the primer opens from the front page', (tester) async {
      await pump(tester, '/');
      final en = await AppL10n.delegate.load(const Locale('en'));
      await tester.tap(find.text(en.primerTitle));
      await tester.pumpAndSettle();
      expect(find.text(en.primerIntro), findsOneWidget);
      expect(find.textContaining('Step 1 of'), findsOneWidget);
    });

    testWidgets('the glossary opens from the front page', (tester) async {
      await pump(tester, '/');
      final en = await AppL10n.delegate.load(const Locale('en'));
      await tester.tap(find.text(en.glossaryTitle));
      await tester.pumpAndSettle();
      expect(find.text(en.glossarySearchHint), findsWidgets);
    });
  });
}
