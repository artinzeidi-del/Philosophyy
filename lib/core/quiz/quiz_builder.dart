import 'dart:math';

import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/concept.dart';
import 'package:philosophyy/domain/entities/philosopher.dart';
import 'package:philosophyy/domain/entities/quiz.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/school.dart';
import 'package:philosophyy/domain/entities/work.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
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

    // Grouped by fact rather than by id: two ways of asking one thing are two
    // questions and one fact, and a round that asks both hands the reader the
    // second answer for free. See `QuizQuestion.fact`.
    //
    // Collected rather than deduplicated on arrival, because keeping the first
    // arrival would decide the format by the order the builders happen to run
    // in — the four-option phrasing is offered first for both tradition and
    // authorship, so the yes-or-no form would have disappeared from the quiz
    // entirely. One is chosen per fact below, by lot.
    final byFact = <String, List<QuizQuestion>>{};

    void offer(QuizQuestion? question) {
      if (question != null) {
        byFact.putIfAbsent(question.fact, () => <QuizQuestion>[]).add(question);
      }
    }

    for (final ref in subjects) {
      switch (ref.kind) {
        case EntityKind.philosopher:
          final philosopher = corpus.philosopher(ref.id);
          if (philosopher == null) continue;
          offer(_whichTradition(corpus, philosopher, l10n, language, random));
          offer(_askedTradition(corpus, philosopher, l10n, language, random));
          offer(_askedTaught(corpus, philosopher, l10n, language, random));
          offer(_whichBranch(corpus, philosopher, l10n, language, random));
          offer(_whichSchool(corpus, philosopher, l10n, language, random));
          offer(_whoseWork(corpus, philosopher, l10n, language, random));
          offer(_whoSaid(corpus, philosopher, l10n, language, random));
          offer(_askedInfluenced(corpus, philosopher, l10n, language, random));
          offer(
            _askedContemporary(corpus, philosopher, l10n, language, random),
          );
          offer(_whoIsEarlier(corpus, philosopher, l10n, language, random));
        case EntityKind.work:
          final work = corpus.work(ref.id);
          if (work == null) continue;
          offer(_whoWrote(corpus, work, l10n, language, random));
          offer(_askedWrote(corpus, work, l10n, language, random));
        case EntityKind.concept:
          final concept = corpus.concept(ref.id);
          if (concept == null) continue;
          offer(_whichConcept(corpus, concept, l10n, language, random));
        case EntityKind.school:
          final school = corpus.school(ref.id);
          if (school == null) continue;
          offer(_whoFounded(corpus, school, l10n, language, random));
        case EntityKind.quote:
        case EntityKind.argument:
        case EntityKind.source:
        case EntityKind.problem:
          // Nothing structural to ask about beyond the summary question below.
          // A problem's content is the disagreement, and a question with one
          // right answer is the wrong shape for it.
          break;
      }

      // Asked of every kind: the entry's own one-line summary, against three
      // other entries' names. It is the only question that tests the article
      // rather than the record around it.
      offer(_whichEntry(corpus, ref, l10n, language, random));
    }

    // One phrasing per fact. Sorted first so the choice depends on the seed
    // and not on map iteration order, which would make a round unreproducible.
    final facts = byFact.keys.toList()..sort();
    final pool = <QuizQuestion>[
      for (final fact in facts)
        (byFact[fact]!..sort((a, b) => a.id.compareTo(b.id)))[random.nextInt(
          byFact[fact]!.length,
        )],
    ];
    pool.shuffle(random);
    return pool.length <= length ? pool : pool.sublist(0, length);
  }

  /// Every fact the corpus can build a question about, given [subjects].
  ///
  /// ## Why this exists separately from [build]
  ///
  /// The reader's level is a fraction: facts they have mastered over facts
  /// there are. The denominator has to be a property of the corpus, known
  /// without playing, and stable — otherwise the top rank moves as rounds are
  /// played, and a reader who has answered everything can still find
  /// themselves short of it, which is the defect this is written to prevent.
  ///
  /// [build] cannot supply it: it picks one phrasing per fact and stops at a
  /// round's length, so it shows a sample. This mirrors the same availability
  /// conditions and enumerates instead. A test plays two hundred rounds and
  /// asserts that every fact they produce appears here, so the two cannot
  /// drift apart silently.
  static Set<String> factsFor(KnowledgeBase corpus, Set<EntityRef> subjects) {
    final facts = <String>{};

    bool enoughOthers(Iterable<Object?> candidates) =>
        candidates.take(3).length >= 3;

    for (final ref in subjects) {
      final entity = corpus.resolve(ref);
      if (entity != null &&
          entity.oneLine.resolve(AppLanguage.en).isNotEmpty &&
          enoughOthers(corpus.allEntities.where((it) => it.ref != ref))) {
        facts.add('summary:${ref.canonical}');
      }

      switch (ref.kind) {
        case EntityKind.philosopher:
          final philosopher = corpus.philosopher(ref.id);
          if (philosopher == null) continue;

          for (final (axis, own) in <(TaxonomyKind, Set<String>)>[
            (TaxonomyKind.tradition, philosopher.traditions),
            (TaxonomyKind.branch, philosopher.branches),
          ]) {
            if (own.isEmpty || corpus.taxonomy[own.first] == null) continue;
            final unrelated = corpus.taxonomy
                .ofKind(axis)
                .where(
                  (candidate) => !own.any(
                    (mine) =>
                        candidate.id == mine ||
                        corpus.taxonomy.isUnder(mine, candidate.id) ||
                        corpus.taxonomy.isUnder(candidate.id, mine),
                  ),
                );
            if (!enoughOthers(unrelated)) continue;
            facts.add(
              '${axis == TaxonomyKind.tradition ? 'tradition' : 'branch'}:'
              '${philosopher.id}',
            );
          }

          if (philosopher.schoolIds.isNotEmpty &&
              corpus.school(philosopher.schoolIds.first) != null &&
              enoughOthers(
                corpus.schools.where(
                  (it) => !philosopher.schoolIds.contains(it.id),
                ),
              )) {
            facts.add('school:${philosopher.id}');
          }

          if (corpus.worksBy(philosopher.id).isNotEmpty &&
              enoughOthers(
                corpus.works.where((it) => it.authorId != philosopher.id),
              )) {
            facts.add('whose-work:${philosopher.id}');
          }

          if (corpus
              .relationsOfType(philosopher.ref, RelationType.taught)
              .any(
                (relation) =>
                    relation.confidence.isEstablished &&
                    relation.object.kind == EntityKind.philosopher &&
                    corpus.philosopher(relation.object.id) != null,
              )) {
            facts.add('taught:${philosopher.id}');
          }

          if (corpus
              .relationsOfType(philosopher.ref, RelationType.influenced)
              .any(
                (relation) =>
                    relation.confidence.isEstablished &&
                    corpus.resolve(relation.object) != null,
              )) {
            facts.add('influenced:${philosopher.id}');
          }

          // Producible when a partner exists on either side of the question —
          // one whose life overlaps, or one whose life does not.
          if (_isDated(philosopher) &&
              corpus.philosophers.any(
                (it) => it.id != philosopher.id && _isDated(it),
              )) {
            facts.add('contemporary:${philosopher.id}');
          }

          final death = philosopher.life.death ?? philosopher.life.floruit?.end;
          if (_isDated(philosopher) &&
              death != null &&
              enoughOthers(_bornAfter(corpus, philosopher, death.year))) {
            facts.add('earliest:${philosopher.id}');
          }

          if (enoughOthers(
            corpus.philosophers.where((it) => it.id != philosopher.id),
          )) {
            for (final quote in corpus.quotes) {
              if (quote.speakerId == philosopher.id &&
                  quote.attribution == AttributionStatus.verified) {
                facts.add('who-said:${quote.id}');
              }
            }
          }

        case EntityKind.work:
          final work = corpus.work(ref.id);
          if (work == null) continue;
          if (corpus.philosopher(work.authorId) != null &&
              enoughOthers(
                corpus.philosophers.where((it) => it.id != work.authorId),
              )) {
            facts.add('author:${work.id}');
          }

        case EntityKind.concept:
          final concept = corpus.concept(ref.id);
          if (concept == null) continue;
          if (concept.shortDefinition.resolve(AppLanguage.en).isNotEmpty &&
              enoughOthers(
                corpus.concepts.where((it) => it.id != concept.id),
              )) {
            facts.add('definition:${concept.id}');
          }

        case EntityKind.school:
          final school = corpus.school(ref.id);
          if (school == null) continue;
          if (school.founderIds.isNotEmpty &&
              corpus.philosopher(school.founderIds.first) != null &&
              enoughOthers(
                corpus.philosophers.where(
                  (it) =>
                      !school.founderIds.contains(it.id) &&
                      !school.memberIds.contains(it.id),
                ),
              )) {
            facts.add('founder:${school.id}');
          }

        case EntityKind.quote:
        case EntityKind.argument:
        case EntityKind.source:
        case EntityKind.problem:
          break;
      }
    }

    return facts;
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
      fact: 'author:${work.id}',
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
      fact: 'tradition:${philosopher.id}',
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
      fact: 'summary:${ref.canonical}',
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
      fact: 'author:${work.id}',
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
        fact: 'taught:${philosopher.id}',
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
      fact: 'taught:${philosopher.id}',
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
      fact: 'tradition:${philosopher.id}',
      prompt: l10n.quizAskedTradition(
        philosopher.name.resolve(language),
        term.name.resolve(language),
      ),
      isTrue: askTruth,
      l10n: l10n,
      source: philosopher.ref,
    );
  }

  // ---- Kinds added because one round of six shapes reads the same every
  // time. Each still rests on something the corpus records. ------------------

  /// Which branch of philosophy an entry is filed under.
  static QuizQuestion? _whichBranch(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final own = philosopher.branches;
    if (own.isEmpty) return null;
    final term = corpus.taxonomy[own.first];
    if (term == null) return null;

    final others = _sample(
      corpus.taxonomy
          .ofKind(TaxonomyKind.branch)
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
      id: 'which-branch:${philosopher.id}',
      fact: 'branch:${philosopher.id}',
      prompt: l10n.quizWhichBranch(philosopher.name.resolve(language)),
      answer: term.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: philosopher.ref,
      random: random,
    );
  }

  /// Which school a philosopher belongs to.
  static QuizQuestion? _whichSchool(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    if (philosopher.schoolIds.isEmpty) return null;
    final school = corpus.school(philosopher.schoolIds.first);
    if (school == null) return null;

    // A distractor must be a school this philosopher is in none of, or two
    // options are right and the reader is marked wrong for choosing one.
    final others = _sample(
      corpus.schools.where(
        (candidate) => !philosopher.schoolIds.contains(candidate.id),
      ),
      3,
      random,
    );
    if (others.length < 3) return null;

    return _shuffledChoice(
      id: 'which-school:${philosopher.id}',
      fact: 'school:${philosopher.id}',
      prompt: l10n.quizWhichSchool(philosopher.name.resolve(language)),
      answer: school.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: philosopher.ref,
      random: random,
    );
  }

  /// Which of four works this philosopher wrote.
  ///
  /// The inverse of `who wrote X`, and a different question: it tests whether
  /// a reader can pick a title out of a shelf rather than attach a name to one
  /// they have already been handed.
  static QuizQuestion? _whoseWork(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final own = corpus.worksBy(philosopher.id);
    if (own.isEmpty) return null;
    final work = own[random.nextInt(own.length)];

    final others = _sample(
      corpus.works.where((candidate) => candidate.authorId != philosopher.id),
      3,
      random,
    );
    if (others.length < 3) return null;

    return _shuffledChoice(
      id: 'whose-work:${philosopher.id}',
      fact: 'whose-work:${philosopher.id}',
      prompt: l10n.quizWhoseWork(philosopher.name.resolve(language)),
      answer: work.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: philosopher.ref,
      random: random,
    );
  }

  /// Who said a quotation.
  ///
  /// Drawn only from quotations the corpus marks verified, so the answer is
  /// one the app itself stands behind. A misattributed quotation is a fine
  /// thing to read about and a terrible thing to be marked wrong on.
  static QuizQuestion? _whoSaid(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final own = corpus.quotes
        .where(
          (quote) =>
              quote.speakerId == philosopher.id &&
              quote.attribution == AttributionStatus.verified,
        )
        .toList();
    if (own.isEmpty) return null;
    final quote = own[random.nextInt(own.length)];

    final others = _sample(
      corpus.philosophers.where((it) => it.id != philosopher.id),
      3,
      random,
    );
    if (others.length < 3) return null;

    return _shuffledChoice(
      id: 'who-said:${quote.id}',
      fact: 'who-said:${quote.id}',
      prompt: '${l10n.quizWhoSaid}\n\n«${quote.text.resolve(language)}»',
      answer: philosopher.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: philosopher.ref,
      random: random,
    );
  }

  /// Which concept a definition defines.
  static QuizQuestion? _whichConcept(
    KnowledgeBase corpus,
    Concept concept,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final definition = concept.shortDefinition.resolve(language);
    if (definition.isEmpty) return null;

    final others = _sample(
      corpus.concepts.where((it) => it.id != concept.id),
      3,
      random,
    );
    if (others.length < 3) return null;

    return _shuffledChoice(
      id: 'which-concept:${concept.id}',
      fact: 'definition:${concept.id}',
      prompt: '${l10n.quizWhichConcept}\n\n«$definition»',
      answer: concept.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: concept.ref,
      random: random,
    );
  }

  /// Who founded a school.
  static QuizQuestion? _whoFounded(
    KnowledgeBase corpus,
    School school,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    if (school.founderIds.isEmpty) return null;
    final founder = corpus.philosopher(school.founderIds.first);
    if (founder == null) return null;

    // Not merely a different philosopher: one who founded nothing here and is
    // not a member of this school, so no option can be argued for.
    final others = _sample(
      corpus.philosophers.where(
        (it) =>
            !school.founderIds.contains(it.id) &&
            !school.memberIds.contains(it.id),
      ),
      3,
      random,
    );
    if (others.length < 3) return null;

    return _shuffledChoice(
      id: 'who-founded:${school.id}',
      fact: 'founder:${school.id}',
      prompt: l10n.quizWhoFounded(school.name.resolve(language)),
      answer: founder.name.resolve(language),
      distractors: <String>[
        for (final other in others) other.name.resolve(language),
      ],
      source: school.ref,
      random: random,
    );
  }

  /// Whether one philosopher influenced another.
  ///
  /// The true form comes from a recorded, established edge. There is no false
  /// form: absence of a recorded influence is not evidence that none existed,
  /// and unlike teaching, influence is not ruled out by dates — a philosopher
  /// can influence someone born a thousand years later.
  static QuizQuestion? _askedInfluenced(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    final influenced = corpus
        .relationsOfType(philosopher.ref, RelationType.influenced)
        .where((relation) => relation.confidence.isEstablished)
        .toList();
    if (influenced.isEmpty) return null;

    final relation = influenced[random.nextInt(influenced.length)];
    final object = corpus.resolve(relation.object);
    if (object == null) return null;

    return _yesNo(
      id: 'asked-influenced:${philosopher.id}:${relation.object.id}',
      // Keyed to the philosopher rather than to the pair. Which of their
      // recorded influences gets asked is up to the seed, and a fact per pair
      // would make the number of facts in the corpus depend on how many
      // rounds had happened to be played — which is the denominator the
      // levels are measured against.
      fact: 'influenced:${philosopher.id}',
      prompt: l10n.quizAskedInfluenced(
        philosopher.name.resolve(language),
        object.name.resolve(language),
      ),
      isTrue: true,
      l10n: l10n,
      source: philosopher.ref,
      detail: relation.note?.resolve(language),
    );
  }

  /// Whether two philosophers were alive at the same time.
  ///
  /// Both answers come from dates the corpus records, so neither rests on
  /// silence: overlapping lifespans make it true, separated ones make it
  /// false, and a missing date disqualifies the pair entirely.
  static QuizQuestion? _askedContemporary(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    if (!_isDated(philosopher)) return null;
    final askTruth = random.nextBool();

    final other = _pickOne(
      corpus.philosophers.where(
        (it) =>
            it.id != philosopher.id &&
            _isDated(it) &&
            _livesOverlap(philosopher, it) == askTruth,
      ),
      random,
    );
    if (other == null) return null;

    // Ordered, so the same pairing produces the same question whichever of the
    // two is the subject.
    final pair = <String>[philosopher.id, other.id]..sort();
    return _yesNo(
      id: 'asked-contemporary:${pair[0]}:${pair[1]}',
      // One fact per philosopher, not per pair. Every dated philosopher can be
      // paired with every other, so a fact per pair is quadratic: 191
      // philosophers produced 6,214 of them, and a reader could never finish.
      fact: 'contemporary:${philosopher.id}',
      prompt: l10n.quizAskedContemporary(
        philosopher.name.resolve(language),
        other.name.resolve(language),
      ),
      isTrue: askTruth,
      l10n: l10n,
      source: philosopher.ref,
    );
  }

  /// Which of four philosophers lived earliest.
  ///
  /// The subject is the answer, so the question is only built when every
  /// distractor was born after the subject died — otherwise "earlier" is a
  /// judgement about overlapping lives rather than a fact, and a reader could
  /// be marked wrong for a defensible choice.
  static QuizQuestion? _whoIsEarlier(
    KnowledgeBase corpus,
    Philosopher philosopher,
    AppL10n l10n,
    AppLanguage language,
    Random random,
  ) {
    if (!_isDated(philosopher)) return null;
    final death = philosopher.life.death ?? philosopher.life.floruit?.end;
    if (death == null) return null;

    final later = _sample(
      _bornAfter(corpus, philosopher, death.year),
      3,
      random,
    );
    if (later.length < 3) return null;

    return _shuffledChoice(
      id: 'who-is-earlier:${philosopher.id}',
      fact: 'earliest:${philosopher.id}',
      prompt: l10n.quizWhoIsEarlier,
      answer: philosopher.name.resolve(language),
      distractors: <String>[
        for (final other in later) other.name.resolve(language),
      ],
      source: philosopher.ref,
      random: random,
    );
  }

  /// Philosophers whose recorded birth falls after [year].
  static Iterable<Philosopher> _bornAfter(
    KnowledgeBase corpus,
    Philosopher subject,
    int year,
  ) => corpus.philosophers.where((it) {
    if (it.id == subject.id || !_isDated(it)) return false;
    final birth = it.life.birth ?? it.life.floruit?.start;
    return birth != null && birth.year > year;
  });

  /// Whether both ends of a life are on record.
  ///
  /// [_livesOverlap] answers `true` for an undated philosopher, because it is
  /// asked whether an overlap can be *ruled out*. Here the question is put to
  /// the reader as a fact, so an undated pair has to be excluded rather than
  /// assumed to overlap.
  static bool _isDated(Philosopher philosopher) =>
      (philosopher.life.birth ?? philosopher.life.floruit?.start) != null &&
      (philosopher.life.death ?? philosopher.life.floruit?.end) != null;

  // ---- Shared ---------------------------------------------------------------

  static QuizQuestion _yesNo({
    required String id,
    required String fact,
    required String prompt,
    required bool isTrue,
    required AppL10n l10n,
    required EntityRef source,
    String? detail,
  }) => QuizQuestion(
    id: id,
    fact: fact,
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

  static QuizQuestion? _shuffledChoice({
    required String id,
    required String fact,
    required String prompt,
    required String answer,
    required List<String> distractors,
    required EntityRef source,
    required Random random,
  }) {
    // A distractor that reads the same as the answer makes the question
    // unanswerable: two of the four options are correct and only one of them
    // is marked so, and a reader who picks the other is told they are wrong.
    //
    // This is not hypothetical. Four Presocratics have a collection of their
    // surviving quotations in the corpus, and in English all four were called
    // "Fragments" — so a question about one of them could be offered with
    // another as a decoy. The titles were made distinct, but the same trap is
    // waiting for any two entries that ever share a display name, in either
    // language, so the guard lives here rather than in the content.
    //
    // Dropping the duplicate and shipping three options would be worse: the
    // shape of the question would tell the reader something had gone wrong.
    // Skipping it costs one question out of thousands, and the round is
    // assembled from whatever is offered.
    //
    // Two *decoys* that read alike are the same defect one step over. The
    // question stays answerable, but the reader is shown four options of which
    // two are the same words, which reads as a broken screen and invites them
    // to look for a difference that is not there. It happens for the same
    // reason: distinct entries can share a display name — a philosopher and
    // the book named after them, say — and sampling picks entries, not names.
    final options = <String>[answer, ...distractors]..shuffle(random);
    final question = QuizQuestion(
      id: id,
      fact: fact,
      format: QuizFormat.multipleChoice,
      prompt: prompt,
      options: options,
      answerIndex: options.indexOf(answer),
      source: source,
    );

    // One check for the whole family rather than a guard per failure mode.
    // Skipping costs one question out of thousands, and the round is assembled
    // from whatever is offered; shipping a malformed one costs the reader's
    // trust in every question after it.
    return question.isWellFormed ? question : null;
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
