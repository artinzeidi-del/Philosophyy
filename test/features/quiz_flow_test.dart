import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/app/app.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/core/quiz/quiz_builder.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/user_data.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The tick at the foot of an article, and the round it feeds.
///
/// Driven through the real screens rather than the providers, because the two
/// halves of this feature are joined by the reader walking from one to the
/// other: a tick that does not reach the quiz, or a quiz that asks about
/// entries nobody ticked, would pass every unit test and be useless.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  /// The refs marked read in the container behind [tester]'s app.
  Set<EntityRef> readIn(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PhilosophiaApp)))
          .read(readTargetsProvider);

  Future<void> pump(
    WidgetTester tester, {
    required String route,
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
          sharedPreferencesProvider.overrideWithValue(store),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(library),
          initialRouteProvider.overrideWithValue(route),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A library with [count] entries already marked read.
  UserLibrary libraryWith(int count) {
    var library = UserLibrary.empty;
    for (final entity in corpus.philosophers.take(count)) {
      library = library.toggleRead(entity.ref, at: DateTime(2026, 5, 1));
    }
    return library;
  }

  group('The tick at the foot of an article', () {
    testWidgets('is there, and starts unticked', (tester) async {
      await pump(tester, route: '/philosophers/plato');

      final l10n = await AppL10n.delegate.load(const Locale('en'));
      // `scrollUntilVisible` finds it without moving — slivers build ahead of
      // the viewport, so the widget is in the tree at an offset of 5,815 and
      // the finder is satisfied while the reader can see nothing. `ensureVisible`
      // is the one that actually brings it on screen.
      await tester.ensureVisible(find.text(l10n.articleMarkRead));
      await tester.pumpAndSettle();
      expect(find.text(l10n.articleMarkRead), findsOneWidget);
      expect(find.text(l10n.articleMarkedRead), findsNothing);
    });

    testWidgets('records the article when pressed, and unrecords it', (
      tester,
    ) async {
      await pump(tester, route: '/philosophers/plato');
      const plato = EntityRef(EntityKind.philosopher, 'plato');
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(readIn(tester), isNot(contains(plato)));

      await tester.ensureVisible(find.text(l10n.articleMarkRead));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.articleMarkRead));
      await tester.pumpAndSettle();

      expect(
        readIn(tester),
        contains(plato),
        reason: 'the tick did not reach the library',
      );
      expect(find.text(l10n.articleMarkedRead), findsOneWidget);

      // And it is a toggle, not a one-way door: a reader who ticks the wrong
      // article must be able to say so.
      await tester.tap(find.text(l10n.articleMarkedRead));
      await tester.pumpAndSettle();
      expect(readIn(tester), isNot(contains(plato)));
    });
  });

  group('The quiz', () {
    testWidgets('says where questions come from when nothing is read', (
      tester,
    ) async {
      await pump(tester, route: AppRouter.quiz);
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(find.text(l10n.quizNothingReadTitle), findsOneWidget);
      // The point of the empty state: it names the control that fixes it.
      expect(find.textContaining('I have read this'), findsOneWidget);
    });

    testWidgets('waits for enough to ask about', (tester) async {
      await pump(
        tester,
        route: AppRouter.quiz,
        library: libraryWith(QuizBuilder.minimumSubjects - 1),
      );
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      expect(find.text(l10n.quizTooLittleReadTitle), findsOneWidget);
    });

    testWidgets('runs a round through to a score', (tester) async {
      await pump(tester, route: AppRouter.quiz, library: libraryWith(12));
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhilosophiaApp)),
      );

      await tester.tap(find.text(l10n.quizStart));
      await tester.pumpAndSettle();

      final round = container.read(quizSessionProvider)!.questions;
      expect(round, isNotEmpty);

      // The reader answers everything correctly. Which option that is comes
      // from the session, so this tests the screen rather than restating the
      // builder's own arithmetic.
      for (var index = 0; index < round.length; index++) {
        final question = round[index];
        await tester.tap(find.text(question.answer).first);
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.quizCorrect),
          findsOneWidget,
          reason: 'the right answer to "${question.id}" was marked wrong',
        );

        final last = index == round.length - 1;
        await tester.tap(find.text(last ? l10n.quizFinish : l10n.quizNext));
        await tester.pumpAndSettle();
      }

      expect(
        find.text(l10n.quizScore(round.length, round.length)),
        findsOneWidget,
        reason: 'answering every question right did not produce a full score',
      );
      expect(find.text(l10n.quizAllRight), findsOneWidget);
    });

    testWidgets('does not colour the answer before one is chosen', (
      tester,
    ) async {
      // A screen that shows which option is right on arrival passes every
      // structural check and makes the whole feature pointless.
      await pump(tester, route: AppRouter.quiz, library: libraryWith(12));
      final l10n = await AppL10n.delegate.load(const Locale('en'));

      await tester.tap(find.text(l10n.quizStart));
      await tester.pumpAndSettle();

      expect(find.text(l10n.quizCorrect), findsNothing);
      expect(find.text(l10n.quizIncorrect), findsNothing);
      expect(find.text(l10n.quizNext), findsNothing);
    });

    testWidgets('a wrong answer says so and offers the entry', (tester) async {
      await pump(tester, route: AppRouter.quiz, library: libraryWith(12));
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhilosophiaApp)),
      );

      await tester.tap(find.text(l10n.quizStart));
      await tester.pumpAndSettle();

      final question = container.read(quizSessionProvider)!.questions.first;
      final wrong = question
          .options[(question.answerIndex + 1) % question.options.length];

      await tester.tap(find.text(wrong).first);
      await tester.pumpAndSettle();

      expect(find.text(l10n.quizIncorrect), findsOneWidget);
      // The point of the screen: a wrong answer leads somewhere.
      expect(find.text(l10n.quizOpenSource), findsOneWidget);
    });

    testWidgets('an answer cannot be changed once it is given', (tester) async {
      await pump(tester, route: AppRouter.quiz, library: libraryWith(12));
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhilosophiaApp)),
      );

      await tester.tap(find.text(l10n.quizStart));
      await tester.pumpAndSettle();

      final question = container.read(quizSessionProvider)!.questions.first;
      final wrong = question
          .options[(question.answerIndex + 1) % question.options.length];

      await tester.tap(find.text(wrong).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(question.answer).first);
      await tester.pumpAndSettle();

      expect(
        find.text(l10n.quizIncorrect),
        findsOneWidget,
        reason: 'the reader corrected an answer after being told it was wrong',
      );
    });

    testWidgets('waits for the corpus instead of doing nothing', (
      tester,
    ) async {
      // The defect this exists for: nothing on this route watched the corpus,
      // so on a real launch `corpusProvider` was never initialised, pressing
      // «شروع» read null from it and silently did nothing. Every existing test
      // passed, because they all override the provider with a value that is
      // available synchronously — which the real asynchronous load is not.
      //
      // So this one delays it, the way the asset load does.
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final store = await SharedPreferences.getInstance();
      final delayed = Completer<KnowledgeBase>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(store),
            corpusProvider.overrideWith((ref) => delayed.future),
            initialLibraryProvider.overrideWithValue(libraryWith(12)),
            initialRouteProvider.overrideWithValue(AppRouter.quiz),
          ],
          child: const PhilosophiaApp(),
        ),
      );
      await tester.pump();

      final l10n = await AppL10n.delegate.load(const Locale('en'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhilosophiaApp)),
      );

      // While it loads there is no button to press, so the reader cannot
      // press one that would do nothing.
      expect(find.text(l10n.quizStart), findsNothing);

      delayed.complete(corpus);
      await tester.pumpAndSettle();

      expect(find.text(l10n.quizStart), findsOneWidget);
      await tester.tap(find.text(l10n.quizStart));
      await tester.pumpAndSettle();

      expect(
        container.read(quizSessionProvider)?.questions,
        isNotEmpty,
        reason: 'pressing start after the corpus arrived did nothing',
      );
    });

    testWidgets('asks only about entries the reader marked', (tester) async {
      await pump(tester, route: AppRouter.quiz, library: libraryWith(12));
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(PhilosophiaApp)),
      );

      await tester.tap(find.text(l10n.quizStart));
      await tester.pumpAndSettle();

      final marked = container.read(readTargetsProvider);
      for (final question in container.read(quizSessionProvider)!.questions) {
        expect(
          marked,
          contains(question.source),
          reason: '${question.id} tests an entry the reader has not read',
        );
      }
    });
  });
}
