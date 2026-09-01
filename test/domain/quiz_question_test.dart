import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/domain/entities/quiz.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// What makes a question unfit to put to a reader.
///
/// The builder skips any question that fails these, so each case below is a
/// screen no reader will see. They are listed one at a time because they were
/// found one at a time: a round about a Chinese concept offered "Mozi" as two
/// of its four options, since the philosopher and the book named after him are
/// distinct entries with one display name. The guard in place then rejected a
/// decoy matching the answer and said nothing about two decoys matching each
/// other, and patching that alone would have left the rest of the family
/// reachable.
void main() {
  const source = EntityRef(EntityKind.concept, 'wu-wei');

  QuizQuestion choice(List<String> options, {int answerIndex = 0}) =>
      QuizQuestion(
        id: 'q',
        fact: 'f',
        format: QuizFormat.multipleChoice,
        prompt: 'Which one?',
        options: options,
        answerIndex: answerIndex,
        source: source,
      );

  const good = <String>['Laozi', 'Zhuangzi', 'Mozi', 'Han Feizi'];

  group('A question a reader may be asked', () {
    test('four distinct options with the answer among them', () {
      final question = choice(good);
      expect(question.problems, isEmpty);
      expect(question.isWellFormed, isTrue);
      expect(question.answer, 'Laozi');
    });

    test('two options for a yes-or-no question', () {
      const question = QuizQuestion(
        id: 'q',
        fact: 'f',
        format: QuizFormat.trueFalse,
        prompt: 'Did he?',
        options: <String>['Yes', 'No'],
        answerIndex: 1,
        source: source,
      );
      expect(question.problems, isEmpty);
    });
  });

  group('A question the builder must skip', () {
    test('one that offers the same option twice', () {
      expect(
        choice(<String>['Mozi', 'Zhuangzi', 'Mozi', 'Han Feizi']).problems,
        contains(contains('same option more than once')),
      );
    });

    test('one whose options differ only by case', () {
      expect(
        choice(<String>['Mozi', 'Zhuangzi', 'MOZI', 'Han Feizi']).problems,
        contains(contains('same option more than once')),
        reason: 'a reader cannot act on a difference in capitals',
      );
    });

    test('one whose options differ only by spacing', () {
      expect(
        choice(<String>['Han Feizi', 'Zhuangzi', 'Han  Feizi ', 'Mozi'])
            .problems,
        contains(contains('same option more than once')),
      );
    });

    test('one with a blank option', () {
      expect(
        choice(<String>['Laozi', '   ', 'Mozi', 'Han Feizi']).problems,
        contains(contains('blank option')),
      );
    });

    test('one whose answer index points past the end', () {
      expect(
        choice(good, answerIndex: 4).problems,
        contains(contains('outside')),
        reason: 'reading the answer would throw before the screen was drawn',
      );
    });

    test('one with too few alternatives to be a choice of four', () {
      expect(
        choice(<String>['Laozi', 'Zhuangzi', 'Mozi']).problems,
        contains(contains('needs 4 options')),
        reason:
            'three options where the reader expects four tells them something '
            'has gone wrong without saying what',
      );
    });

    test('one with no options at all', () {
      expect(
        choice(const <String>[]).problems,
        containsAll(<Matcher>[contains('no options'), contains('outside')]),
      );
    });
  });
}
