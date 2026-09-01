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
    required this.fact,
    required this.format,
    required this.prompt,
    required this.options,
    required this.answerIndex,
    required this.source,
    this.detail,
  }) : assert(answerIndex >= 0, 'a question must have an answer');

  /// Identifier, stable for the same question and the same reading language.
  ///
  /// Used as a widget key, and as what the reader's record of mastered
  /// questions is kept in.
  final String id;

  /// What the question is really about, independent of how it is asked.
  ///
  /// ## Why this is not the id
  ///
  /// Reported from use: a round asked which tradition Ibn Sīnā belongs to, and
  /// two questions later asked whether he belongs to the Chinese one. The
  /// second was free, because the first had just answered it.
  ///
  /// Both were deduplicated correctly — by id, and their ids differ, because
  /// one is `which-tradition:ibn-sina` and the other
  /// `asked-tradition:ibn-sina:chinese`. Two ways of asking one thing are two
  /// questions and one fact, and it is the fact a round must not repeat.
  ///
  /// So every builder states the fact its question turns on —
  /// `tradition:ibn-sina` for both of those — and a round holds at most one
  /// question per fact.
  final String fact;

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

  /// Everything wrong with this question, as sentences a developer can act on.
  ///
  /// ## Why this is one list rather than a guard at each build site
  ///
  /// A question about a Chinese concept once offered "Mozi" as two of its four
  /// options, because the philosopher and the book named after him are
  /// distinct entries with one display name, and the builder sampled entries
  /// while the reader sees names. The guard in place at the time rejected a
  /// decoy that matched the answer and said nothing about two decoys that
  /// matched each other.
  ///
  /// Patching that one case would have left the rest of the family: an option
  /// that is blank, an answer index pointing past the end, a choice with only
  /// two real alternatives, two options differing by a stray space. Each is a
  /// screen the reader would be right to call broken, and each was reachable.
  /// So the whole family is stated in one place, checked once, and tested.
  List<String> get problems {
    final found = <String>[];
    if (options.isEmpty) {
      found.add('has no options');
    }
    if (answerIndex < 0 || answerIndex >= options.length) {
      found.add('answerIndex $answerIndex is outside 0..${options.length - 1}');
    }
    if (options.any((option) => option.trim().isEmpty)) {
      found.add('has a blank option');
    }

    // Compared as a reader sees them: leading and trailing space, runs of
    // space, and case are differences nobody can act on.
    String seen(String option) =>
        option.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final distinct = options.map(seen).toSet();
    if (distinct.length != options.length) {
      found.add('offers the same option more than once');
    }
    final expected = format == QuizFormat.trueFalse ? 2 : 4;
    if (options.length != expected) {
      found.add(
        'a ${format.name} question needs $expected options, '
        'has ${options.length}',
      );
    }
    return found;
  }

  /// Whether this question can be put to a reader.
  bool get isWellFormed => problems.isEmpty;

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
