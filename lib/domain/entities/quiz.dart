import 'package:philosophyy/domain/value_objects/entity_ref.dart';

/// The shape of a question.
enum QuizFormat {
  /// Two options: the statement holds, or it does not.
  trueFalse,

  /// Four options, exactly one of them right.
  multipleChoice,
}

/// One question, with its answer and the entry the answer comes from.
///
/// ## Why a question carries where it came from
///
/// A quiz that only says "wrong" has told the reader the least useful half of
/// what it knows. [source] is the entry the answer is stated in, so a reader who
/// gets it wrong — or right and wants to know why — is one tap from the passage
/// rather than left to search for it.
///
/// It also keeps the app honest. A question that cannot name the entry its
/// answer comes from is a question nobody checked, and this type makes that
/// impossible to write.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.format,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.source,
    this.detail,
  }) : assert(answerIndex >= 0, 'a question must have an answer');

  /// Identifier, stable for the same fact and the same reading language.
  ///
  /// Used to keep a question from being asked twice in one round, and as a
  /// widget key so answering one does not redraw the rest.
  final String id;

  /// Whether this is a yes-or-no question or a choice of four.
  final QuizFormat format;

  /// The question, already in the reader's language.
  final String prompt;

  /// What the reader may choose between.
  final List<String> options;

  /// Which of [options] is right.
  final int answerIndex;

  /// The entry whose article states the answer.
  final EntityRef source;

  /// A sentence from the corpus explaining the connection, where one exists.
  ///
  /// Shown after answering. Relations in the corpus often carry a note that is
  /// more use to a reader than the bare fact, and this is where it earns its
  /// keep.
  final String? detail;

  /// The right answer, as text.
  String get answer => options[answerIndex];

  /// Whether [index] is the right answer.
  bool isCorrect(int index) => index == answerIndex;

  @override
  String toString() => 'QuizQuestion($id, $format, answer: $answer)';
}

/// How a reader did on one round.
class QuizResult {
  const QuizResult({required this.answers, required this.questions});

  /// The index the reader chose for each question, in the order asked.
  final List<int> answers;

  /// The questions asked.
  final List<QuizQuestion> questions;

  /// How many were answered correctly.
  int get correct {
    var total = 0;
    for (var index = 0; index < questions.length; index++) {
      if (index < answers.length &&
          questions[index].isCorrect(answers[index])) {
        total++;
      }
    }
    return total;
  }

  /// How many were asked.
  int get total => questions.length;

  /// The questions the reader got wrong, so the screen can point at what to
  /// read rather than only at a number.
  List<QuizQuestion> get missed => <QuizQuestion>[
    for (var index = 0; index < questions.length; index++)
      if (index >= answers.length ||
          !questions[index].isCorrect(answers[index]))
        questions[index],
  ];

  @override
  String toString() => 'QuizResult($correct/$total)';
}
