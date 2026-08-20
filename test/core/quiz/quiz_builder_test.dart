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

  group('Every question is answerable from the corpus', () {
    test('the named answer is among the options exactly once', () {
      final problems = <String>[];
      for (final question in roundFrom(everything())) {
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

    test('every question points at an entry that exists', () {
      final problems = <String>[
        for (final question in roundFrom(everything()))
          if (corpus.resolve(question.source) == null)
            '${question.id}: cites ${question.source}, which is not in the corpus',
      ];
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('no option is empty and no prompt is a bare template', () {
      final problems = <String>[];
      for (final question in roundFrom(everything())) {
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
      for (final question in roundFrom(everything())) {
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
      for (final question in roundFrom(everything())) {
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
      for (final question in roundFrom(everything())) {
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
      for (final question in roundFrom(everything())) {
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
      for (final question in roundFrom(everything())) {
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
      for (final question in roundFrom(everything())) {
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
      expect(checked, lessThanOrEqualTo(withTeaching));
      expect(refutedByDates, greaterThan(0), reason: 'no false form was built');
    });

    test(
      '"does X belong to Y" answered no names a term the entry is not in',
      () {
        var checked = 0;
        for (final question in roundFrom(everything())) {
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
