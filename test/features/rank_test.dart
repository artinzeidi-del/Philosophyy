import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/core/quiz/quiz_builder.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/data/user/key_value_store.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/ranks.dart';
import 'package:philosophyy/features/home/rank_banner.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The ladder ends where the questions do.
///
/// ## The defect this is written against
///
/// A rank ladder can be built so that its top is unreachable — thresholds set
/// against a number the reader can never attain, or against a denominator that
/// grows as they play. Either produces the same experience: nothing left to
/// answer, and a bar that is not full.
///
/// So the arithmetic is checked against the corpus itself rather than against
/// numbers chosen to make it come out right.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  Set<String> catalogue() => QuizBuilder.factsFor(
    corpus,
    corpus.allEntities.map((entity) => entity.ref).toSet(),
  );

  group('The ladder', () {
    test('answering everything reaches the last rank exactly', () {
      final total = catalogue().length;
      expect(total, greaterThan(0));

      expect(
        Ranks.levelFor(total, total),
        Ranks.top,
        reason:
            'a reader who has answered all $total facts is not at the top '
            'rank, so the app has nothing left to ask them and still says '
            'they are unfinished',
      );
      expect(Ranks.progressWithin(total, total), 1);
      expect(Ranks.factsToNext(total, total), isNull);
    });

    test('one short of everything is one short of the top', () {
      // The other half: if the last rank arrived early, the ones above it
      // would be unreachable in a different way — nothing would distinguish
      // finishing from nearly finishing.
      final total = catalogue().length;
      expect(Ranks.levelFor(total - 1, total), lessThan(Ranks.top));
    });

    test('starts at the first rank and never goes backwards', () {
      final total = catalogue().length;
      expect(Ranks.levelFor(0, total), 0);

      var previous = 0;
      for (var mastered = 0; mastered <= total; mastered++) {
        final level = Ranks.levelFor(mastered, total);
        expect(
          level,
          greaterThanOrEqualTo(previous),
          reason: 'the rank fell between $mastered and ${mastered - 1} facts',
        );
        expect(level, inInclusiveRange(0, Ranks.top));
        previous = level;
      }
    });

    test('every rank can be reached', () {
      // A threshold set so close to the one above it that no whole number of
      // facts lands between them would produce a rank nobody ever holds.
      final total = catalogue().length;
      final reached = <int>{
        for (var mastered = 0; mastered <= total; mastered++)
          Ranks.levelFor(mastered, total),
      };
      expect(
        reached,
        hasLength(Ranks.count),
        reason:
            'these ranks are skipped over: '
            '${List<int>.generate(Ranks.count, (i) => i).where((i) => !reached.contains(i))}',
      );
    });

    test('progress inside a rank runs from nothing to full', () {
      final total = catalogue().length;
      var sawEmpty = false;
      var sawFull = false;
      for (var mastered = 0; mastered <= total; mastered++) {
        final progress = Ranks.progressWithin(mastered, total);
        expect(progress, inInclusiveRange(0, 1));
        if (progress == 0) sawEmpty = true;
        if (progress > 0.99) sawFull = true;
      }
      expect(sawEmpty, isTrue);
      expect(sawFull, isTrue);
    });

    test('an empty corpus does not trap the reader at the bottom', () {
      // With nothing to answer there is nothing left to answer. Reporting a
      // beginner would be a rank nobody could ever leave.
      expect(Ranks.levelFor(0, 0), Ranks.top);
      expect(Ranks.progressWithin(0, 0), 1);
      expect(Ranks.factsToNext(0, 0), isNull);
    });

    test('every rank has a name in both languages', () async {
      for (final locale in const <Locale>[Locale('en'), Locale('fa')]) {
        final l10n = await AppL10n.delegate.load(locale);
        final names = <String>{
          for (var level = 0; level < Ranks.count; level++)
            RankBanner.nameFor(l10n, level),
        };
        expect(
          names,
          hasLength(Ranks.count),
          reason: 'two ranks share a name in ${locale.languageCode}: $names',
        );
        for (final name in names) {
          expect(name.trim(), isNotEmpty);
        }
      }
    });
  });

  group('The banner', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      UserLibrary library = UserLibrary.empty,
    }) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final store = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            keyValueStoreProvider.overrideWithValue(PreferencesStore(store)),
            corpusProvider.overrideWith((ref) => corpus),
            initialLibraryProvider.overrideWithValue(library),
            initialRouteProvider.overrideWithValue(AppRouter.home),
          ],
          child: const PhilosophiaApp(),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(PhilosophiaApp)),
      );
    }

    testWidgets('opens on the front page at the first rank', (tester) async {
      final container = await pump(tester);
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(find.byType(RankBanner), findsOneWidget);
      expect(find.text(l10n.rank1), findsOneWidget);
      expect(container.read(readerRankProvider).level, 0);
    });

    testWidgets('rises when facts are mastered', (tester) async {
      final facts = catalogue().toList()..sort();
      // Enough for the third rank on the current corpus, taken from the
      // catalogue rather than invented, so the test moves with the content.
      final container = await pump(
        tester,
        library: UserLibrary.empty.withMastered(
          facts.take((facts.length * 0.07).ceil()),
        ),
      );

      final rank = container.read(readerRankProvider);
      expect(rank.level, greaterThan(0));
      expect(rank.mastered, greaterThan(0));
      expect(rank.total, facts.length);

      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(RankBanner.nameFor(l10n, rank.level)), findsOneWidget);
    });

    testWidgets('says there is nothing left when everything is answered', (
      tester,
    ) async {
      final container = await pump(
        tester,
        library: UserLibrary.empty.withMastered(catalogue()),
      );
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(container.read(readerRankProvider).isTop, isTrue);
      expect(find.text(l10n.rank9), findsOneWidget);
      expect(find.text(l10n.rankTop), findsOneWidget);
    });

    testWidgets('leads to the quiz', (tester) async {
      await pump(tester);
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      await tester.ensureVisible(find.byType(RankBanner));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RankBanner));
      await tester.pumpAndSettle();

      expect(find.text(l10n.quizTitle), findsWidgets);
    });
  });

  group('Mastery', () {
    test('the same fact answered twice counts once', () {
      // Otherwise the ladder measures persistence rather than reading, and a
      // reader could reach the top by re-answering one question.
      final once = UserLibrary.empty.withMastered(const <String>['a']);
      final twice = once.withMastered(const <String>['a']);

      expect(once.masteredFacts, hasLength(1));
      expect(twice.masteredFacts, hasLength(1));
      expect(
        identical(twice, once),
        isTrue,
        reason: 'recording a known fact wrote to storage for nothing',
      );
    });

    test('clearing an article keeps what was learned from it', () {
      const plato = EntityRef(EntityKind.philosopher, 'plato');
      final library = UserLibrary.empty
          .toggleRead(plato, at: DateTime(2026))
          .withMastered(const <String>['tradition:plato']);

      final cleared = library.withoutTarget(plato);

      expect(cleared.hasRead(plato), isFalse);
      expect(
        cleared.masteredFacts,
        contains('tradition:plato'),
        reason:
            'tidying an article out of the library cost the reader the rank '
            'they climbed with it',
      );
    });
  });
}
