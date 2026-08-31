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
import 'package:philosophyy/features/quiz/quiz_screen.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/painted_contrast.dart';

/// The quiz, measured on the screens it actually shows.
///
/// The whole-app contrast sweep pumps every route with an empty library, and
/// with an empty library the quiz is three lines telling the reader to go and
/// read something. That is not the screen worth checking. The one that is has
/// options tinted green and red over a tinted background — the exact
/// arrangement where a colour picked to signal something ends up too close to
/// what it is painted on.
///
/// So this walks the round: the question before an answer, and the question
/// after one, in both themes and both languages.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
  });

  /// A library with a dozen entries marked read, which is enough for a round.
  UserLibrary readLibrary() {
    var library = UserLibrary.empty;
    for (final philosopher in corpus.philosophers.take(12)) {
      library = library.toggleRead(philosopher.ref, at: DateTime(2026, 5, 1));
    }
    return library;
  }

  /// The seed the measured round is built from.
  ///
  /// Fixed so that a failure can be reproduced. Nothing about this number is
  /// special beyond having been picked once.
  const roundSeed = 20260501;

  Future<ProviderContainer> pumpRound(
    WidgetTester tester, {
    required ThemeMode theme,
    required String language,
    int seed = roundSeed,
  }) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    tester.platformDispatcher.platformBrightnessTestValue =
        theme == ThemeMode.dark ? Brightness.dark : Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'flutter.settings.language': language,
      'flutter.settings.themeMode': theme == ThemeMode.dark ? 'dark' : 'light',
    });
    final store = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(PreferencesStore(store)),
          corpusProvider.overrideWith((ref) => corpus),
          initialLibraryProvider.overrideWithValue(readLibrary()),
          initialRouteProvider.overrideWithValue(AppRouter.quiz),
        ],
        child: const PhilosophiaApp(),
      ),
    );
    await tester.pumpAndSettle();

    // The start screen has exactly one button, so this does not depend on its
    // wording in either language.
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PhilosophiaApp)),
    );
    expect(
      container.read(quizSessionProvider)?.questions,
      isNotEmpty,
      reason: 'no round started, so there is no question to measure',
    );

    // The round the button builds is seeded from the clock, so which questions
    // this measures changed on every run and a red build could not be
    // reproduced. The tap above is what proves the button starts a round; the
    // round measured below is a fixed one. Change [roundSeed] to sample
    // different content, and the builder itself is swept over many seeds in
    // quiz_builder_test.dart.
    container
        .read(quizSessionProvider.notifier)
        .start(AppL10n.of(tester.element(find.byType(QuizScreen))), seed: seed);
    await tester.pumpAndSettle();
    expect(container.read(quizSessionProvider)?.questions, isNotEmpty);
    return container;
  }

  void expectReadable(
    WidgetTester tester,
    String where, {
    required List<String> mustInclude,
  }) {
    final measured = PaintedContrast.measure(tester);

    // Named rather than counted. A threshold on the number of paragraphs is
    // the wrong guard here: a yes-or-no question legitimately resolves six —
    // the title, the progress line, the prompt and two options — and a number
    // low enough to admit that is too low to catch anything. Requiring the
    // question's own text to be among what was measured cannot be satisfied by
    // the wrong screen.
    final resolved = measured.findings.map((finding) => finding.text).toList();
    final seen = measured.findings.map((finding) => finding.shortText).toList();
    for (final required in mustInclude) {
      expect(
        resolved.any((text) => text.contains(required)),
        isTrue,
        reason:
            'the check did not measure "$required" on $where, so it is not '
            'looking at the screen it thinks it is. It saw: $seen',
      );
    }
    expect(
      measured.failures,
      isEmpty,
      reason:
          '$where paints text a reader cannot read:\n  '
          '${measured.failures.join('\n  ')}',
    );
  }

  testWidgets('right and wrong are told apart without relying on colour', (
    tester,
  ) async {
    // They were not told apart at all at first: the right answer was painted
    // in the colour scheme's primary and the wrong one in its error colour,
    // and in this app the primary is an ember red, so both came out as two
    // shades of the same thing.
    //
    // Colouring them green and red fixed that for most readers and for nobody
    // with a red-green deficiency — and a contrast ratio is no help in
    // deciding, because #2f6b43 and #9b2318 are plainly different hues while
    // sitting at almost the same luminance. So the check is not about colour:
    // each state must carry a mark of its own.
    final container = await pumpRound(
      tester,
      theme: ThemeMode.light,
      language: 'en',
    );
    final question = container.read(quizSessionProvider)!.questions.first;
    final wrongIndex = (question.answerIndex + 1) % question.options.length;

    expect(
      find.byIcon(Icons.check_circle_rounded),
      findsNothing,
      reason: 'the answer was marked before the reader chose one',
    );

    container.read(quizSessionProvider.notifier).choose(wrongIndex);
    await tester.pumpAndSettle();

    Finder markInside(String label) => find.descendant(
      of: find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          )
          .first,
      matching: find.byType(Icon),
    );

    expect(
      tester.widget<Icon>(markInside(question.answer).first).icon,
      Icons.check_circle_rounded,
      reason: 'the right answer carries no mark of its own',
    );
    expect(
      tester.widget<Icon>(markInside(question.options[wrongIndex]).first).icon,
      Icons.cancel_rounded,
      reason: 'the chosen wrong answer carries no mark of its own',
    );

    // And the colours are still different colours, which is the fast signal
    // for everyone who can use it.
    Color borderOf(String label) {
      final box = tester.widget<AnimatedContainer>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      return (box.decoration! as BoxDecoration).border!.top.color;
    }

    expect(
      borderOf(question.answer),
      isNot(borderOf(question.options[wrongIndex])),
    );
  });

  for (final theme in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    final themeName = theme == ThemeMode.dark ? 'dark' : 'light';
    for (final language in <String>['en', 'fa']) {
      testWidgets('a question is readable in $themeName/$language', (
        tester,
      ) async {
        final container = await pumpRound(
          tester,
          theme: theme,
          language: language,
        );
        final question = container.read(quizSessionProvider)!.questions.first;
        expectReadable(
          tester,
          'the quiz question in $themeName/$language',
          mustInclude: <String>[question.options.first],
        );
      });

      testWidgets('a wrong answer is readable in $themeName/$language', (
        tester,
      ) async {
        // The red and green states only exist after a choice, so they are only
        // measurable after one. Answering wrongly puts both on screen at once:
        // the option that was picked and the one that was right.
        final container = await pumpRound(
          tester,
          theme: theme,
          language: language,
        );
        final question = container.read(quizSessionProvider)!.questions.first;
        final wrong = (question.answerIndex + 1) % question.options.length;
        container.read(quizSessionProvider.notifier).choose(wrong);
        await tester.pumpAndSettle();

        expectReadable(
          tester,
          'the answered quiz question in $themeName/$language',
          // Both coloured states are on screen: the wrong option the reader
          // picked, and the right one shown beside it.
          mustInclude: <String>[question.options[wrong], question.answer],
        );
      });
    }
  }
}
