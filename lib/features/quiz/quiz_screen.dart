import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/core/design/backdrop.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/design/semantic_colors.dart';
import 'package:philosophyy/core/format/number_format.dart';
import 'package:philosophyy/core/quiz/quiz_builder.dart';
import 'package:philosophyy/domain/entities/quiz.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';
import 'package:philosophyy/features/shared/skeletons.dart';
import 'package:philosophyy/features/shared/ui_states.dart';
import 'package:philosophyy/features/shared/up_button.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// A round of questions about what the reader has read.
///
/// ## Why this only asks about marked entries
///
/// A quiz over the whole corpus would be a test of what a reader has not read
/// yet, which tells them nothing except that the app contains more than they
/// know. Drawn from the entries they ticked, a wrong answer means something:
/// they read it and it did not stay. That is worth showing them, and it is why
/// the result screen ends with the entries behind the questions they missed
/// rather than with a score alone.
///
/// The questions themselves come from the corpus — see [QuizBuilder], which is
/// where the rule that nothing may be invented is kept. The round in progress
/// lives in [quizSessionProvider] rather than in this widget, so that what the
/// reader is being asked is visible to something other than the screen drawing
/// it.
class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  @override
  void initState() {
    super.initState();
    // A round left over from a previous visit would drop the reader into the
    // middle of questions they have forgotten agreeing to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(quizSessionProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final read = ref.watch(readTargetsProvider);
    final session = ref.watch(quizSessionProvider);

    // ## Why the corpus is watched here even though this screen never reads it
    //
    // It did not used to be, and the screen was broken in the product while
    // every test passed. Nothing else on this route touches the corpus — the
    // count of entries read comes from the library, and the start screen shows
    // only that — so `corpusProvider` was never initialised, and pressing
    // «شروع» read `null` from it and silently did nothing. The tests missed it
    // because they override the provider with a value that is available
    // synchronously, which the real app's asynchronous load is not.
    //
    // Watching it does two things: it starts the load on arrival, and it makes
    // the button unreachable until there is something behind it.
    final corpus = ref.watch(corpusProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const UpButton(),
        title: Text(l10n.quizTitle),
        backgroundColor: Colors.transparent,
      ),
      body: LamplightBackdrop(
        intensity: 0.7,
        child: SafeArea(
          child: corpus.when(
            loading: ListSkeleton.new,
            error: (error, stack) => ErrorView(
              details: error.toString(),
              onRetry: () => ref.invalidate(corpusProvider),
            ),
            data: (_) => _body(l10n, read.length, session),
          ),
        ),
      ),
    );
  }

  Widget _body(AppL10n l10n, int readCount, QuizSession? session) {
    if (readCount == 0) {
      return EmptyView(
        icon: Icons.checklist_rounded,
        title: l10n.quizNothingReadTitle,
        body: l10n.quizNothingReadBody,
      );
    }
    if (readCount < QuizBuilder.minimumSubjects) {
      return EmptyView(
        icon: Icons.hourglass_empty_rounded,
        title: l10n.quizTooLittleReadTitle,
        body: l10n.quizTooLittleReadBody,
      );
    }

    if (session == null) {
      return _StartView(
        readCount: readCount,
        onStart: () => ref.read(quizSessionProvider.notifier).start(l10n),
      );
    }
    if (session.questions.isEmpty) {
      // Enough entries are marked, but nothing in them could be turned into a
      // question. Better to say so than to show an empty round.
      return EmptyView(
        icon: Icons.hourglass_empty_rounded,
        title: l10n.quizTooLittleReadTitle,
        body: l10n.quizTooLittleReadBody,
      );
    }
    if (session.isFinished) {
      return _ResultView(
        result: session.result,
        onAgain: () => ref.read(quizSessionProvider.notifier).start(l10n),
      );
    }

    return _QuestionView(
      question: session.current!,
      position: session.position,
      count: session.questions.length,
      chosen: session.pending,
      isLast: session.position == session.questions.length,
      onChoose: ref.read(quizSessionProvider.notifier).choose,
      onAdvance: ref.read(quizSessionProvider.notifier).advance,
    );
  }
}

/// What the reader sees before a round begins.
class _StartView extends ConsumerWidget {
  const _StartView({required this.readCount, required this.onStart});

  final int readCount;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final language = ref.watch(activeLanguageProvider);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: ReadingColumn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.school_outlined,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                l10n.quizTitle,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                AppNumbers.localizeDigits(
                  l10n.libraryReadCount(readCount),
                  language,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xl),
              FilledButton(onPressed: onStart, child: Text(l10n.quizStart)),
            ],
          ),
        ),
      ),
    );
  }
}

/// One question and its options.
class _QuestionView extends ConsumerWidget {
  const _QuestionView({
    required this.question,
    required this.position,
    required this.count,
    required this.chosen,
    required this.isLast,
    required this.onChoose,
    required this.onAdvance,
  });

  final QuizQuestion question;
  final int position;
  final int count;

  /// What the reader picked, or `null` while they are still deciding.
  final int? chosen;

  final bool isLast;
  final ValueChanged<int> onChoose;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final language = ref.watch(activeLanguageProvider);
    final answered = chosen != null;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.md,
            Spacing.lg,
            0,
          ),
          child: ReadingColumn(
            alignToStart: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppNumbers.localizeDigits(
                    l10n.quizProgress(position, count),
                    language,
                  ),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                ClipRRect(
                  borderRadius: const BorderRadius.all(
                    Radius.circular(Radii.pill),
                  ),
                  child: LinearProgressIndicator(
                    value: position / count,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xl,
              Spacing.lg,
              Spacing.xxxl,
            ),
            children: <Widget>[
              ReadingColumn(
                alignToStart: true,
                child: Text(question.prompt, style: theme.textTheme.titleLarge),
              ),
              const SizedBox(height: Spacing.xl),
              for (var index = 0; index < question.options.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: ReadingColumn(
                    child: _OptionButton(
                      label: question.options[index],
                      // Nothing is coloured until the reader has committed.
                      // Marking the right answer green on arrival is a defect
                      // that only shows on a screenshot, and it makes the
                      // whole screen pointless.
                      state: !answered
                          ? _OptionState.idle
                          : index == question.answerIndex
                          ? _OptionState.correct
                          : index == chosen
                          ? _OptionState.wrong
                          : _OptionState.idle,
                      onTap: answered ? null : () => onChoose(index),
                    ),
                  ),
                ),
              if (answered) ...<Widget>[
                const SizedBox(height: Spacing.md),
                ReadingColumn(
                  alignToStart: true,
                  child: _Verdict(question: question, chosen: chosen!),
                ),
              ],
            ],
          ),
        ),
        if (answered)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              0,
              Spacing.lg,
              Spacing.lg,
            ),
            child: ReadingColumn(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAdvance,
                  child: Text(isLast ? l10n.quizFinish : l10n.quizNext),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// What is said after an answer: whether it was right, and where to read more.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.question, required this.chosen});

  final QuizQuestion question;
  final int chosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final right = question.isCorrect(chosen);
    final detail = question.detail;
    final verdictColour = right
        ? context.semanticColors.verified
        : theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              right ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 20,
              color: verdictColour,
            ),
            const SizedBox(width: Spacing.sm),
            Text(
              right ? l10n.quizCorrect : l10n.quizIncorrect,
              style: theme.textTheme.titleSmall?.copyWith(color: verdictColour),
            ),
          ],
        ),
        if (detail != null) ...<Widget>[
          const SizedBox(height: Spacing.sm),
          Text(detail, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: Spacing.sm),
        // The point of the whole screen: a wrong answer is only useful if the
        // reader can go straight to the passage that settles it.
        TextButton.icon(
          onPressed: () => context.push(question.source.route),
          icon: const Icon(Icons.menu_book_outlined, size: 18),
          label: Text(l10n.quizOpenSource),
        ),
      ],
    );
  }
}

/// How an option is being shown.
enum _OptionState { idle, correct, wrong }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ## Why the right answer is not the primary colour
    //
    // It was, and on screen the two states were indistinguishable: this app's
    // primary is an ember red and so is its error colour, so "right" and
    // "wrong" came out as two shades of the same thing and a reader could not
    // tell which option had been correct — the single fact the screen exists to
    // convey.
    //
    // `verified` is the palette's own word for a claim that checked out. Using
    // it here means the quiz says "right" in the same colour the rest of the
    // app says "this attribution holds", rather than introducing a green that
    // means nothing anywhere else.
    final correct = context.semanticColors.verified;
    final (background, border, foreground) = switch (state) {
      _OptionState.idle => (
        theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        theme.colorScheme.outlineVariant,
        theme.colorScheme.onSurface,
      ),
      _OptionState.correct => (
        correct.withValues(alpha: 0.16),
        correct,
        theme.colorScheme.onSurface,
      ),
      _OptionState.wrong => (
        theme.colorScheme.error.withValues(alpha: 0.12),
        theme.colorScheme.error,
        theme.colorScheme.onSurface,
      ),
    };

    return PressableSurface(
      onTap: onTap,
      borderRadius: Radii.surfaceRadius,
      child: AnimatedContainer(
        duration: Motion.duration(context, MotionTokens.quick),
        curve: MotionTokens.standard,
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        alignment: AlignmentDirectional.centerStart,
        decoration: BoxDecoration(
          color: background,
          borderRadius: Radii.surfaceRadius,
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(color: foreground),
              ),
            ),
            // ## Why a mark and not only a colour
            //
            // Green for right and red for wrong is unreadable to a reader who
            // cannot tell the two apart, and roughly one man in twelve cannot.
            // The colours stay — they are the fastest signal for everyone else
            // — but they are no longer the only one.
            if (state != _OptionState.idle) ...<Widget>[
              const SizedBox(width: Spacing.sm),
              Icon(
                state == _OptionState.correct
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 20,
                color: border,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The end of a round.
class _ResultView extends ConsumerWidget {
  const _ResultView({required this.result, required this.onAgain});

  final QuizResult result;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppL10n.of(context);
    final language = ref.watch(activeLanguageProvider);
    final corpus = ref.watch(corpusProvider).value;
    final missed = result.missed;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xxl,
        Spacing.lg,
        Spacing.xxxl,
      ),
      children: <Widget>[
        ReadingColumn(
          child: Column(
            children: <Widget>[
              Text(
                AppNumbers.localizeDigits(
                  l10n.quizScore(result.correct, result.total),
                  language,
                ),
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (missed.isEmpty) ...<Widget>[
                const SizedBox(height: Spacing.sm),
                Text(
                  l10n.quizAllRight,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.semanticColors.verified,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: Spacing.xl),
              FilledButton(onPressed: onAgain, child: Text(l10n.quizAgain)),
            ],
          ),
        ),
        // Not a list of what was got wrong — a list of what to go and read.
        // The score is the least useful thing on this screen.
        if (missed.isNotEmpty && corpus != null) ...<Widget>[
          const SizedBox(height: Spacing.xxl),
          ReadingColumn(
            alignToStart: true,
            child: SectionHeader(title: l10n.quizReviewTitle),
          ),
          const SizedBox(height: Spacing.md),
          for (final question in _distinctSources(missed))
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: ReadingColumn(
                child: Builder(
                  builder: (context) {
                    final entity = corpus.resolve(question.source);
                    if (entity == null) return const SizedBox.shrink();
                    return EntityCard(
                      title: entity.name.resolve(language),
                      summary: entity.oneLine.resolve(language),
                      onTap: () => context.push(question.source.route),
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }

  /// One card per entry, however many of its questions were missed.
  static List<QuizQuestion> _distinctSources(List<QuizQuestion> questions) {
    final seen = <String>{};
    return <QuizQuestion>[
      for (final question in questions)
        if (seen.add(question.source.canonical)) question,
    ];
  }
}
