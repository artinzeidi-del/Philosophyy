import 'dart:math';

import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/quiz.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/domain/value_objects/taxonomy_term.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Builds questions out of the corpus, and out of nothing else.
///
/// ## The rule this file exists to keep
///
/// Every question here is a restatement of something the corpus already
/// records: an author on a work, a `taught` edge between two philosophers, a
/// term in an entity's own classification. Nothing is composed for the sake of
/// having a question, and there is no list of hand-written questions to drift
/// out of step with the articles — change an entry and the questions about it
/// change with it.
///
/// ## Where a false statement is allowed to come from
///
/// A yes-or-no question needs statements that are false, and this is the part
/// that is easy to get wrong. The corpus is incomplete by nature: no `taught`
/// edge between two philosophers does **not** mean one did not teach the other,
/// only that nobody recorded it. Generating "no" answers from absence would be
/// asserting things the app does not know.
///
/// So a false statement is only produced where the corpus makes it false rather
/// than merely silent:
///
/// - **Authorship.** A work records its author. Another philosopher did not
///   write it, and where both have dates, this additionally requires that they
///   could not have — their life does not overlap its composition.
/// - **Teaching.** Only between philosophers whose lifespans do not overlap at
///   all, so the answer does not depend on the corpus being complete. Nobody
///   taught a person born after they died.
/// - **Tradition.** The taxonomy is the app's own classification, and an
///   entity's list of terms is the whole of it, so a term that is absent is
///   absent by decision rather than by omission.
///
/// Four-option questions need no such care: exactly one option is the recorded
/// answer and the rest are other entities, which is true by construction.
abstract final class QuizBuilder {
  /// How many entries must be marked read before a round can be built.
  ///
  /// Below this the questions would repeat, and a round that asks the same
  /// thing three ways teaches nothing.
  static const int minimumSubjects = 3;

  /// How many questions a round holds.
  static const int roundLength = 8;

  /// Builds a round drawn from [subjects].
  ///
  /// [subjects] is what the reader has marked as read; a question is only
  /// asked when its subject is among them, so the quiz never tests an entry
  /// they have not seen. Distractors are drawn from the whole corpus, because
  /// a wrong option only has to be wrong.
  ///
  /// [seed] fixes the shuffle. A round that reshuffles on every rebuild would
  /// change under the reader's hand as they answer.
  static List<QuizQuestion> build({
    required KnowledgeBase corpus,
    required Set<EntityRef> subjects,
    required AppL10n l10n,
    required AppLanguage language,
    required int seed,
    int length = roundLength,
  }) {
    if (subjects.isEmpty) return const <QuizQuestion>[];

    final random = Random(seed);
    final questions = <String, QuizQuestion>{};

    void offer(QuizQuestion? question) {
      if (question != null) questions.putIfAbsent(question.id, () => question);
    }

    for (final ref in subjects) {
      switch (ref.kind) {
        case EntityKind.philosopher:
          final philosopher = corpus.philosopher(ref.id);
          if (philosopher == null) continue;
          offer(_whichTradition(corpus, philosopher, l10n, language, random));
          offer(_askedTradition(corpus, philosopher, l10n, language, random));
          offer(_askedTaught(corpus, philosopher, l10n, language, random));
        case EntityKind.work:
          final work = corpus.work(ref.id);
          if (work == null) continue;
          offer(_whoWrote(corpus, work, l10n, language, random));
          offer(_askedWrote(corpus, work, l10n, language, random));
        case EntityKind.concept:
        case EntityKind.school:
        case EntityKind.quote:
        case EntityKind.argument:
        case EntityKind.source:
          // Nothing structural to ask about beyond the summary question below.
          break;
      }

      // Asked of every kind: the entry's own one-line summary, against three
      // other entries' names. It is the only question that tests the article
      // rather than the record around it.
      offer(_whichEntry(corpus, ref, l10n, language, random));
    }

    final pool = questions.values.toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    pool.shuffle(random);
    return pool.length <= length ? pool : pool.sublist(0, length);
  }

  // ---- Four options, one recorded answer -----------------------------------

  static QuizQuestion? _whoWrote(
    KnowledgeBase corpus,
    Work work,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final author = corpus.philosopher(work.authorId);
    if (author == null) return null;

    final others = _sample(
      corpus.philosophers.where((it) => it.id != author.id),
      3,
      random,
    );
    if (others.length < 3) return null;

    return _shuffledChoice(
      id: 'who-wrote:${work.id}',
      prompt: l10n.quizWhoWrote(work.name.resolve(language)),
      answer: author.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: work.ref,
      random: random,
    );
  }

  static QuizQuestion? _whichTradition(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final own = philosopher.traditions;
    if (own.isEmpty) return null;
    final term = corpus.taxonomy[own.first];
    if (term == null) return null;

    // Distractors must be traditions this philosopher is *not* in — including
    // not under one they are in, or "Greek" would be offered against "Ancient
    // Greek" and both would be right.
    final others = _sample(
      corpus.taxonomy
          .ofKind(TaxonomyKind.tradition)
          .where(
            (candidate) => !own.any(
              (mine) =>
                  candidate.id == mine ||
                  corpus.taxonomy.isUnder(mine, candidate.id) ||
                  corpus.taxonomy.isUnder(candidate.id, mine),
            ),
          ),
      3,
      random,
    );
    if (others.length < 3) return null;

    return _shuffledChoice(
      id: 'which-tradition:${philosopher.id}',
      prompt: l10n.quizWhichTradition(philosopher.name.resolve(language)),
      answer: term.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: philosopher.ref,
      random: random,
    );
  }

  static QuizQuestion? _whichEntry(
    KnowledgeBase corpus,
    EntityRef ref,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final entity = corpus.resolve(ref);
    if (entity == null) return null;
    final summary = entity.oneLine.resolve(language);
    if (summary.isEmpty) return null;

    final others = _sample(
      corpus.allEntities.where((it) => it.ref != ref),
      3,
      random,
    );
    if (others.length < 3) return null;

    return _shuffledChoice(
      id: 'which-entry:${ref.canonical}',
      prompt: '${l10n.quizWhichEntry}\n\n«$summary»',
      answer: entity.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: ref,
      random: random,
    );
  }

  // ---- Yes or no -----------------------------------------------------------

  static QuizQuestion? _askedWrote(
    KnowledgeBase corpus,
    Work work,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final author = corpus.philosopher(work.authorId);
    if (author == null) return null;

    // Half the time ask the true form, half the false one, so a reader cannot
    // learn that this kind of question is always answered the same way.
    final askTruth = random.nextBool();
    final subject = askTruth
        ? author
        : _pickOne(
            corpus.philosophers.where(
              (it) =>
                  it.id != author.id && !_couldHaveWritten(it, work.composed),
            ),
            random,
          );
    if (subject == null) return null;

    return _yesNo(
      id: 'asked-wrote:${work.id}:${subject.id}',
      prompt: l10n.quizAskedWrote(
        subject.name.resolve(language),
        work.name.resolve(language),
      ),
      isTrue: askTruth,
      l10n: l10n,
      source: work.ref,
    );
  }

  static QuizQuestion? _askedTaught(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final taught = corpus
        .relationsOfType(philosopher.ref, RelationType.taught)
        .where(
          (relation) =>
              relation.confidence.isEstablished &&
              relation.object.kind == EntityKind.philosopher,
        )
        .toList();
    if (taught.isEmpty) return null;

    final real = taught[random.nextInt(taught.length)];
    final student = corpus.philosopher(real.object.id);
    if (student == null) return null;

    final askTruth = random.nextBool();
    if (askTruth) {
      return _yesNo(
        id: 'asked-taught:${philosopher.id}:${student.id}',
        prompt: l10n.quizAskedTaught(
          philosopher.name.resolve(language),
          student.name.resolve(language),
        ),
        isTrue: true,
        l10n: l10n,
        source: philosopher.ref,
        detail: real.note?.resolve(language),
      );
    }

    // Only someone who could not have been taught by them at all — see the
    // rule at the top of this file.
    final impossible = _pickOne(
      corpus.philosophers.where(
        (it) => it.id != philosopher.id && !_livesOverlap(philosopher, it),
      ),
      random,
    );
    if (impossible == null) return null;

    return _yesNo(
      id: 'asked-taught:${philosopher.id}:not-${impossible.id}',
      prompt: l10n.quizAskedTaught(
        philosopher.name.resolve(language),
        impossible.name.resolve(language),
      ),
      isTrue: false,
      l10n: l10n,
      source: philosopher.ref,
    );
  }

  static QuizQuestion? _askedTradition(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final own = philosopher.traditions;
    if (own.isEmpty) return null;

    final askTruth = random.nextBool();
    final term = askTruth
        ? corpus.taxonomy[own.first]
        : _pickOne(
            corpus.taxonomy
                .ofKind(TaxonomyKind.tradition)
                .where(
                  (candidate) => !own.any(
                    (mine) =>
                        candidate.id == mine ||
                        corpus.taxonomy.isUnder(mine, candidate.id) ||
                        corpus.taxonomy.isUnder(candidate.id, mine),
                  ),
                ),
            random,
          );
    if (term == null) return null;

    return _yesNo(
      id: 'asked-tradition:${philosopher.id}:${term.id}',
      prompt: l10n.quizAskedTradition(
        philosopher.name.resolve(language),
        term.name.resolve(language),
      ),
      isTrue: askTruth,
      l10n: l10n,
      source: philosopher.ref,
    );
  }

  // ---- Shared ---------------------------------------------------------------

  static QuizQuestion _yesNo({
    required String id,
    required String prompt,
    required bool isTrue,
    required AppL10n l10n,
    required EntityRef source,
    String? detail,
  }) => QuizQuestion(
    id: id,
    format: QuizFormat.trueFalse,
    prompt: prompt,
    // Fixed order rather than shuffled. Yes and no are not interchangeable
    // labels a reader reads afresh each time — they are two positions the hand
    // learns, and moving them turns a question about philosophy into a question
    // about whether you were paying attention to the buttons.
    options: <String>[l10n.quizYes, l10n.quizNo],
    answerIndex: isTrue ? 0 : 1,
    source: source,
    detail: detail,
  );

  static QuizQuestion _shuffledChoice({
    required String id,
    required String prompt,
    required String answer,
    required List<String> distractors,
    required EntityRef source,
    required Random random,
  }) {
    final options = <String>[answer, ...distractors]..shuffle(random);
    return QuizQuestion(
      id: id,
      format: QuizFormat.multipleChoice,
      prompt: prompt,
      options: options,
      answerIndex: options.indexOf(answer),
      source: source,
    );
  }

  /// Whether [philosopher] was alive at any point during [range].
  ///
  /// Unknown dates count as an overlap. The question this answers is "can this
  /// be ruled out", and an unknown date rules nothing out.
  static bool _couldHaveWritten(
    Philosopher philosopher,
    HistoricalRange? range,
  ) {
    if (range == null) return true;
    final composed = range.start ?? range.end;
    if (composed == null) return true;

    final birth = philosopher.life.birth ?? philosopher.life.floruit?.start;
    final death = philosopher.life.death ?? philosopher.life.floruit?.end;
    if (birth == null && death == null) return true;

    if (birth != null && birth.year > composed.year) return false;
    if (death != null && death.year < composed.year) return false;
    return true;
  }

  /// Whether the two lives overlap, or whether that cannot be determined.
  ///
  /// Returns `true` when either is undated, for the same reason as above: a
  /// missing date is not evidence of separation, and a question whose falsity
  /// rests on a missing date is a question the app cannot stand behind.
  static bool _livesOverlap(Philosopher a, Philosopher b) {
    final aBirth = a.life.birth ?? a.life.floruit?.start;
    final aDeath = a.life.death ?? a.life.floruit?.end;
    final bBirth = b.life.birth ?? b.life.floruit?.start;
    final bDeath = b.life.death ?? b.life.floruit?.end;
    if (aBirth == null || aDeath == null || bBirth == null || bDeath == null) {
      return true;
    }
    return aBirth.year <= bDeath.year && bBirth.year <= aDeath.year;
  }

  static List<T> _sample<T>(Iterable<T> from, int count, Random random) {
    final pool = from.toList()..shuffle(random);
    return pool.length <= count ? pool : pool.sublist(0, count);
  }

  static T? _pickOne<T>(Iterable<T> from, Random random) {
    final pool = from.toList();
    if (pool.isEmpty) return null;
    return pool[random.nextInt(pool.length)];
  }
}
