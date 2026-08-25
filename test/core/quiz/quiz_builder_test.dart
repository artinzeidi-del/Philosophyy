import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/quiz/quiz_builder.dart';
import 'package:philosophyy/data/content/asset_knowledge_repository.dart';
import 'package:philosophyy/data/content/knowledge_base.dart';
import 'package:philosophyy/domain/entities/quiz.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// Every question is checked back against the corpus that produced it.
///
/// ## Why this file is longer than the thing it tests
///
/// A quiz is the one part of a reference work that can be wrong in a way the
/// reader cannot detect. An article that overstates a claim can be checked
/// against its citations; a question that marks the right answer wrong teaches
/// the reader something false and tells them they were mistaken to doubt it.
///
/// So nothing here trusts the builder's own account of itself. Each question is
/// taken apart and its answer re-derived from the corpus independently — if the
/// builder says Kant wrote the first Critique, the test goes and looks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeBase corpus;
  late AppL10n en;
  late AppL10n fa;

  setUpAll(() async {
    corpus = await const AssetKnowledgeRepository().load();
    en = await AppL10n.delegate.load(const Locale('en'));
    fa = await AppL10n.delegate.load(const Locale('fa'));
  });

  /// A round drawn from the whole corpus, which is the widest net available.
  List<QuizQuestion> roundFrom(
    Set<EntityRef> subjects, {
    int seed = 1,
    int length = 400,
    AppLanguage language = AppLanguage.en,
  }) => QuizBuilder.build(
    corpus: corpus,
    subjects: subjects,
    l10n: language == AppLanguage.en ? en : fa,
    language: language,
    seed: seed,
    length: length,
  );

  Set<EntityRef> everything() =>
      corpus.allEntities.map((entity) => entity.ref).toSet();

  /// Every distinct question the builder can produce over [seeds] rounds.
  ///
  /// A round now picks one phrasing per fact by lot, so a single seed shows
  /// only about half of each pair. Anything asserting about a phrasing has to
  /// look across seeds, or it is measuring the coin toss rather than the
  /// builder.
  List<QuizQuestion> across({
    int seeds = 12,
    AppLanguage language = AppLanguage.en,
  }) {
    final byId = <String, QuizQuestion>{};
    for (var seed = 0; seed < seeds; seed++) {
      for (final question in roundFrom(
        everything(),
        seed: seed,
        language: language,
      )) {
        byId[question.id] = question;
      }
    }
    return byId.values.toList();
  }

  group('Every question is answerable from the corpus', () {
    test('the named answer is among the options exactly once', () {
      final problems = <String>[];
      for (final question in across()) {
        if (question.answerIndex >= question.options.length) {
          problems.add('${question.id}: answer index out of range');
          continue;
        }
        final occurrences = question.options
            .where((option) => option == question.answer)
            .length;
        if (occurrences != 1) {
          // Two identical options means one of the distractors *is* the answer,
          // and the reader can be marked wrong for picking a right one.
          problems.add(
            '${question.id}: the answer "${question.answer}" appears '
            '$occurrences times in ${question.options}',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no question offers the same option twice', () {
      // Two identical options is always a defect, whichever one is the answer.
      // If it is the answer, the reader can pick the "wrong" copy of a right
      // answer; if it is a decoy, the question looks broken. The existing
      // check that the answer appears exactly once does not cover a pair of
      // identical decoys, and decoys are chosen by identifier while the reader
      // sees a name — two taxonomy terms or two entries can be distinct and
      // read the same.
      final problems = <String>[];
      for (final language in AppLanguage.values) {
        for (final question in across(seeds: 20, language: language)) {
          final seen = <String>{};
          for (final option in question.options) {
            if (!seen.add(option)) {
              problems.add(
                '${question.id} (${language.name}) offers "$option" twice',
              );
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no wrong option is also right', () {
      // The existing checks catch a distractor that reads identically to the
      // answer. This one asks the harder question: whether a distractor that
      // reads differently is nonetheless true of the same subject. A reader
      // who knows that Kant worked in both ethics and metaphysics, shown
      // "which branch" with one of them as the answer and the other among the
      // decoys, is marked wrong for knowing more.
      //
      // Every kind whose decoys are drawn from a pool the subject could also
      // belong to is checked against the corpus by hand here, because only
      // the corpus knows what else is true.
      final problems = <String>[];

      void reject(QuizQuestion question, Set<String> alsoTrue) {
        for (var i = 0; i < question.options.length; i++) {
          if (i == question.answerIndex) continue;
          if (alsoTrue.contains(question.options[i])) {
            problems.add(
              '${question.id}: "${question.options[i]}" is offered as wrong '
              'and is true of the subject',
            );
          }
        }
      }

      for (final language in AppLanguage.values) {
        for (final question in across(seeds: 8, language: language)) {
          final id = question.id;
          final subject = id.split(':').length > 1 ? id.split(':')[1] : '';

          if (id.startsWith('which-branch:')) {
            final person = corpus.philosopher(subject);
            if (person == null) continue;
            reject(question, <String>{
              for (final branch in person.branches)
                ?corpus.taxonomy[branch]?.name.resolve(language),
            });
          } else if (id.startsWith('which-school:')) {
            final person = corpus.philosopher(subject);
            if (person == null) continue;
            reject(question, <String>{
              for (final school in person.schoolIds)
                ?corpus.school(school)?.name.resolve(language),
            });
          } else if (id.startsWith('which-tradition:')) {
            final person = corpus.philosopher(subject);
            if (person == null) continue;
            reject(question, <String>{
              for (final tradition in person.traditions)
                ?corpus.taxonomy[tradition]?.name.resolve(language),
            });
          } else if (id.startsWith('whose-work:')) {
            final person = corpus.philosopher(subject);
            if (person == null) continue;
            reject(question, <String>{
              for (final work in corpus.works)
                if (work.authorId == person.id) work.name.resolve(language),
            });
          } else if (id.startsWith('which-concept:')) {
            final concept = corpus.concept(subject);
            if (concept == null) continue;
            // The decoys are other concepts; none of them may share this
            // concept's summary, which is what the reader is matching on.
            reject(question, <String>{
              for (final other in corpus.concepts)
                if (other.id != concept.id &&
                    other.oneLine.resolve(language) ==
                        concept.oneLine.resolve(language))
                  other.name.resolve(language),
            });
          } else if (id.startsWith('who-founded:')) {
            final school = corpus.school(subject);
            if (school == null) continue;
            reject(question, <String>{
              for (final relation in corpus.relations)
                if (relation.type == RelationType.founded &&
                    relation.object.id == school.id)
                  ?corpus
                      .philosopher(relation.subject.id)
                      ?.name
                      .resolve(language),
            });
          } else if (id.startsWith('who-said:')) {
            final quote = corpus.quotes
                .where((q) => q.id == subject)
                .firstOrNull;
            if (quote == null) continue;
            reject(question, <String>{
              ?corpus.philosopher(quote.speakerId)?.name.resolve(language),
            });
          } else if (id.startsWith('who-wrote:')) {
            final work = corpus.work(subject);
            if (work == null) continue;
            reject(question, <String>{
              ?corpus.philosopher(work.authorId)?.name.resolve(language),
            });
          } else if (id.startsWith('who-is-earlier:')) {
            // The answer is the earliest; no decoy may have started before
            // the subject finished.
            final person = corpus.philosopher(subject);
            if (person == null) continue;
            final end =
                person.life.death?.year ?? person.life.floruit?.end?.year;
            if (end == null) continue;
            reject(question, <String>{
              for (final other in corpus.philosophers)
                if (other.id != person.id &&
                    ((other.life.birth?.year ??
                            other.life.floruit?.start?.year ??
                            end + 1) <=
                        end))
                  other.name.resolve(language),
            });
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('every question points at an entry that exists', () {
      final problems = <String>[
        for (final question in across())
          if (corpus.resolve(question.source) == null)
            '${question.id}: cites ${question.source}, which is not in the corpus',
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no option is empty and no prompt is a bare template', () {
      final problems = <String>[];
      for (final question in across()) {
        if (question.prompt.trim().isEmpty) {
          problems.add('${question.id}: empty prompt');
        }
        if (question.prompt.contains('{') || question.prompt.contains('}')) {
          problems.add('${question.id}: unfilled placeholder in the prompt');
        }
        for (final option in question.options) {
          if (option.trim().isEmpty) {
            problems.add('${question.id}: empty option');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a four-option question has four options, a yes-or-no has two', () {
      for (final question in across()) {
        expect(
          question.options,
          hasLength(question.format == QuizFormat.trueFalse ? 2 : 4),
          reason: '${question.id} has the wrong number of options',
        );
      }
    });
  });

  group('The answers are the corpus’s answers', () {
    test('"who wrote X" names the author the work records', () {
      var checked = 0;
      for (final question in across()) {
        if (!question.id.startsWith('who-wrote:')) continue;
        final work = corpus.work(question.id.split(':').last)!;
        final author = corpus.philosopher(work.authorId)!;
        expect(
          question.answer,
          author.name.en,
          reason: '${question.id} marks the wrong philosopher right',
        );
        checked++;
      }
      expect(checked, greaterThan(20), reason: 'too few to be a real check');
    });

    test('"which tradition" names a tradition the entry is in', () {
      var checked = 0;
      for (final question in across()) {
        if (!question.id.startsWith('which-tradition:')) continue;
        final philosopher = corpus.philosopher(question.id.split(':').last)!;
        final named = philosopher.traditions
            .map((id) => corpus.taxonomy[id]?.name.en)
            .toList();
        expect(
          named,
          contains(question.answer),
          reason:
              '${question.id} marks "${question.answer}" right, but the '
              'record says $named',
        );
        checked++;
      }
      expect(checked, greaterThan(20));
    });

    test('"which entry is this" names the entry whose summary is shown', () {
      var checked = 0;
      for (final question in across()) {
        if (!question.id.startsWith('which-entry:')) continue;
        final ref = EntityRef.tryParse(
          question.id.substring('which-entry:'.length),
        )!;
        final entity = corpus.resolve(ref)!;
        expect(question.answer, entity.name.en);
        expect(question.prompt, contains(entity.oneLine.en));
        checked++;
      }
      expect(checked, greaterThan(100));
    });
  });

  group('A statement is only called false when the corpus makes it false', () {
    // The heart of it. The corpus is incomplete: an unrecorded connection is
    // not a refuted one, and a quiz that treats silence as denial teaches
    // readers things nobody checked.

    test('"did X write W" answered yes is what the work records', () {
      var checked = 0;
      for (final question in across()) {
        if (!question.id.startsWith('asked-wrote:')) continue;
        final parts = question.id.split(':');
        final work = corpus.work(parts[1])!;
        final subject = corpus.philosopher(parts[2])!;
        final saysYes = question.answerIndex == 0;

        if (saysYes) {
          expect(
            subject.id,
            work.authorId,
            reason:
                '${question.id} answers yes for a philosopher who is not '
                'the recorded author',
          );
        } else {
          expect(subject.id, isNot(work.authorId));
        }
        checked++;
      }
      expect(checked, greaterThan(10));
    });

    test('"did X teach Y" answered no names someone who could not have', () {
      var checked = 0;
      var refutedByDates = 0;
      for (final question in across()) {
        if (!question.id.startsWith('asked-taught:')) continue;
        final parts = question.id.split(':');
        final teacher = corpus.philosopher(parts[1])!;
        final saysYes = question.answerIndex == 0;

        if (saysYes) {
          final student = corpus.philosopher(parts[2])!;
          final recorded = corpus
              .relationsOfType(teacher.ref, RelationType.taught)
              .any((relation) => relation.object == student.ref);
          expect(
            recorded,
            isTrue,
            reason:
                '${question.id} answers yes to a teaching the corpus does '
                'not record',
          );
        } else {
          // "not-<id>" — and the claim must be refuted by the dates, not by
          // the corpus merely being silent.
          final other = corpus.philosopher(parts[2].substring('not-'.length))!;
          final teacherDeath = teacher.life.death ?? teacher.life.floruit?.end;
          final otherBirth = other.life.birth ?? other.life.floruit?.start;
          final teacherBirth =
              teacher.life.birth ?? teacher.life.floruit?.start;
          final otherDeath = other.life.death ?? other.life.floruit?.end;

          expect(
            teacherDeath,
            isNotNull,
            reason: '${question.id}: falsity rests on a missing date',
          );
          expect(otherBirth, isNotNull);
          expect(teacherBirth, isNotNull);
          expect(otherDeath, isNotNull);

          final separated =
              teacherDeath!.year < otherBirth!.year ||
              otherDeath!.year < teacherBirth!.year;
          expect(
            separated,
            isTrue,
            reason:
                '${question.id} says no to two people who were alive at '
                'the same time — which the corpus cannot rule out',
          );
          refutedByDates++;
        }
        checked++;
      }
      // Derived rather than a threshold: the corpus records six teaching
      // edges, and a number written here would have to be edited every time
      // one is added. Each philosopher with an established one yields at most
      // a single question.
      final withTeaching = corpus.philosophers
          .where(
            (philosopher) => corpus
                .relationsOfType(philosopher.ref, RelationType.taught)
                .any(
                  (relation) =>
                      relation.confidence.isEstablished &&
                      relation.object.kind == EntityKind.philosopher,
                ),
          )
          .length;
      expect(withTeaching, greaterThan(0), reason: 'no teaching is recorded');
      expect(checked, greaterThan(0));

      // Counted by fact rather than by question. The false form picks a
      // different impossible philosopher on each seed, so across twelve seeds
      // one teaching fact yields a dozen distinct ids and only ever one fact.
      final facts = <String>{
        for (final question in across())
          if (question.id.startsWith('asked-taught:')) question.fact,
      };
      expect(facts, hasLength(lessThanOrEqualTo(withTeaching)));
      expect(refutedByDates, greaterThan(0), reason: 'no false form was built');
    });

    test(
      '"does X belong to Y" answered no names a term the entry is not in',
      () {
        var checked = 0;
        for (final question in across()) {
          if (!question.id.startsWith('asked-tradition:')) continue;
          final parts = question.id.split(':');
          final philosopher = corpus.philosopher(parts[1])!;
          final termId = parts[2];
          final saysYes = question.answerIndex == 0;

          final belongs = philosopher.traditions.any(
            (mine) => mine == termId || corpus.taxonomy.isUnder(mine, termId),
          );
          expect(
            saysYes,
            belongs,
            reason:
                '${question.id} disagrees with the classification on record',
          );
          checked++;
        }
        expect(checked, greaterThan(20));
      },
    );
  });

  group('A round', () {
    test('is empty when the reader has read nothing', () {
      expect(roundFrom(const <EntityRef>{}), isEmpty);
    });

    test('asks only about entries the reader has marked read', () {
      const plato = EntityRef(EntityKind.philosopher, 'plato');
      const kant = EntityRef(EntityKind.philosopher, 'kant');
      final round = roundFrom(<EntityRef>{plato, kant});

      expect(round, isNotEmpty);
      for (final question in round) {
        expect(
          question.source,
          anyOf(plato, kant),
          reason: '${question.id} tests an entry the reader has not read',
        );
      }
    });

    test('is the same round for the same seed, and differs for another', () {
      final subjects = everything();
      final first = roundFrom(subjects, seed: 7, length: 8);
      final again = roundFrom(subjects, seed: 7, length: 8);
      final other = roundFrom(subjects, seed: 8, length: 8);

      expect(
        first.map((q) => q.id),
        again.map((q) => q.id),
        reason: 'a round that changes under the reader as they answer',
      );
      expect(first.map((q) => q.id), isNot(other.map((q) => q.id)));
    });

    test('never asks the same fact twice, however it is phrased', () {
      // Reported from use: a round asked which tradition Ibn Sīnā belongs to,
      // and two questions later asked whether he belongs to the Chinese one.
      // The second was free — the first had just answered it.
      //
      // Both were deduplicated, by id, and the ids differ: one is
      // `which-tradition:ibn-sina`, the other
      // `asked-tradition:ibn-sina:chinese`. Two ways of asking one thing are
      // two questions and one fact, and it is the fact that must not repeat.
      for (var seed = 0; seed < 40; seed++) {
        final round = roundFrom(
          everything(),
          seed: seed,
          length: QuizBuilder.roundLength,
        );
        final facts = round.map((question) => question.fact).toList();
        expect(
          facts.toSet(),
          hasLength(facts.length),
          reason:
              'seed $seed asks one fact twice: '
              '${facts..sort()}',
        );
      }
    });

    test('every question states a fact it turns on', () {
      // A question with no fact would be deduplicated against nothing and
      // could be asked beside its own answer.
      for (final question in across()) {
        expect(
          question.fact.trim(),
          isNotEmpty,
          reason: '${question.id} declares no fact',
        );
      }
    });

    test('the two phrasings of one fact agree on what it is', () {
      // The pairing that produced the defect. Both builders must name the
      // fact identically, or the deduplication passes them through.
      final byFact = <String, Set<String>>{};
      for (var seed = 0; seed < 30; seed++) {
        for (final question in roundFrom(everything(), seed: seed)) {
          byFact.putIfAbsent(question.fact, () => <String>{}).add(question.id);
        }
      }

      final tradition = byFact['tradition:ibn-sina'] ?? const <String>{};
      expect(
        tradition.where((id) => id.startsWith('which-tradition:')),
        isNotEmpty,
        reason: 'the four-option form does not report this fact',
      );
      expect(
        tradition.where((id) => id.startsWith('asked-tradition:')),
        isNotEmpty,
        reason: 'the yes-or-no form does not report this fact',
      );
    });

    test('never asks the same question twice', () {
      final round = roundFrom(everything(), length: QuizBuilder.roundLength);
      expect(
        round.map((question) => question.id).toSet(),
        hasLength(round.length),
      );
    });

    test('holds no more than a round’s worth', () {
      expect(
        roundFrom(everything(), length: QuizBuilder.roundLength),
        hasLength(QuizBuilder.roundLength),
      );
    });

    test('asks in Persian when the reader reads Persian', () {
      final round = roundFrom(
        everything(),
        language: AppLanguage.fa,
        length: 12,
      );
      expect(round, isNotEmpty);
      for (final question in round) {
        expect(
          RegExp(r'[؀-ۿ]').hasMatch(question.prompt),
          isTrue,
          reason: '${question.id} asks a Persian reader in English',
        );
      }
    });

    test('offers both formats', () {
      final formats = roundFrom(
        everything(),
        length: 40,
      ).map((question) => question.format).toSet();
      expect(formats, containsAll(QuizFormat.values));
    });
  });

  group('The catalogue of facts', () {
    // The denominator of the reader's level. It has to be a property of the
    // corpus, knowable without playing and stable across rounds — otherwise
    // the top rank moves as questions are answered, and a reader who has
    // answered everything can still be short of it.

    test('every fact a round produces is in the catalogue', () {
      final catalogue = QuizBuilder.factsFor(corpus, everything());
      final missing = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        for (final question in roundFrom(everything(), seed: seed)) {
          if (!catalogue.contains(question.fact)) missing.add(question.fact);
        }
      }
      expect(
        missing,
        isEmpty,
        reason:
            'the builder asks about facts the catalogue does not count, so '
            'the level can never reach the top: ${missing.take(10)}',
      );
    });

    test('the catalogue promises nothing the builder cannot ask', () {
      // The other direction. A fact counted but unaskable is a fact the reader
      // can never master, which is the same defect seen from the other side.
      //
      // Two hundred rounds do not exhaust 1,395 facts, so this asserts the
      // shapes match rather than every entry: every kind of fact the catalogue
      // contains must be one the builder actually produces.
      final catalogue = QuizBuilder.factsFor(corpus, everything());
      final produced = <String>{};
      for (var seed = 0; seed < 200; seed++) {
        for (final question in roundFrom(everything(), seed: seed)) {
          produced.add(question.fact.split(':').first);
        }
      }
      final promised = catalogue.map((fact) => fact.split(':').first).toSet();
      expect(
        promised.difference(produced),
        isEmpty,
        reason: 'the catalogue counts a kind of fact no round ever asks',
      );
    });

    test('is bounded, so a reader can finish it', () {
      // `contemporary` was keyed to a pair of philosophers, and every dated
      // philosopher pairs with every other: 191 of them produced 6,214 facts.
      // A denominator that grows with the square of the corpus is one nobody
      // reaches the end of.
      final catalogue = QuizBuilder.factsFor(corpus, everything());
      expect(catalogue, hasLength(greaterThan(500)));
      expect(
        catalogue,
        hasLength(lessThan(corpus.allEntities.length * 12)),
        reason:
            'the catalogue has ${catalogue.length} facts for '
            '${corpus.allEntities.length} entries, which is not a number '
            'anyone works through',
      );
    });

    test('grows only with what the reader has read', () {
      const plato = EntityRef(EntityKind.philosopher, 'plato');
      final one = QuizBuilder.factsFor(corpus, <EntityRef>{plato});
      final none = QuizBuilder.factsFor(corpus, const <EntityRef>{});

      expect(none, isEmpty);
      expect(one, isNotEmpty);
      expect(
        one.every(
          (fact) => fact.contains('plato') || fact.startsWith('who-said:'),
        ),
        isTrue,
        reason: 'reading one entry counted facts about others: $one',
      );
    });
  });

  group('Variety', () {
    test('a round is not the same six shapes every time', () {
      // The reported complaint: the quiz reads identically each round. Six
      // kinds over eight questions means most rounds hold two of something.
      final kinds = <String>{
        for (final question in across(seeds: 30)) question.id.split(':').first,
      };
      expect(
        kinds,
        hasLength(greaterThanOrEqualTo(12)),
        reason: 'only ${kinds.length} kinds of question exist: $kinds',
      );
    });

    test('both formats keep appearing', () {
      // Choosing one phrasing per fact by lot is what keeps this true. Keeping
      // whichever arrived first would decide it by the order the builders run
      // in, and the yes-or-no form is offered second for both tradition and
      // authorship — so it would have vanished entirely.
      var trueFalse = 0;
      var multiple = 0;
      for (var seed = 0; seed < 20; seed++) {
        for (final question in roundFrom(everything(), seed: seed)) {
          if (question.format == QuizFormat.trueFalse) {
            trueFalse++;
          } else {
            multiple++;
          }
        }
      }
      expect(trueFalse, greaterThan(20));
      expect(multiple, greaterThan(20));
    });
  });

  group('Scoring', () {
    test('counts what was right and keeps what was not', () {
      final round = roundFrom(everything(), length: 4);
      final answers = <int>[
        round[0].answerIndex,
        (round[1].answerIndex + 1) % round[1].options.length,
        round[2].answerIndex,
        (round[3].answerIndex + 1) % round[3].options.length,
      ];

      final result = QuizResult(answers: answers, questions: round);
      expect(result.correct, 2);
      expect(result.total, 4);
      expect(result.missed.map((q) => q.id), <String>[
        round[1].id,
        round[3].id,
      ]);
    });

    test('an unanswered question is not a right one', () {
      final round = roundFrom(everything(), length: 3);
      final result = QuizResult(
        answers: <int>[round.first.answerIndex],
        questions: round,
      );
      expect(result.correct, 1);
      expect(result.missed, hasLength(2));
    });
  });
}
