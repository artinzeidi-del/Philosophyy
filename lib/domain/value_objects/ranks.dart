/// The ladder a reader climbs by answering questions about what they have read.
///
/// ## Why progress is counted in facts and not in answers
///
/// A fact is a thing the corpus records — that Ibn Sīnā belongs to the Islamic
/// tradition, that Kant wrote the first Critique. The quiz can ask about one in
/// several ways, and someone who knows it knows it however it is asked. Counting
/// answers instead would mean the same knowledge could be banked twice by
/// meeting it in its other phrasing, and the ladder would measure persistence
/// rather than reading.
///
/// ## Why the denominator is the whole corpus
///
/// It has to be a number that does not move. Measured against what the reader
/// has read so far, the top would arrive the moment they had mastered a handful
/// of entries and then retreat as they read more — so climbing would go
/// backwards for doing exactly what the app is for.
///
/// Against the whole corpus there is also no state where the reader has nothing
/// left to answer and is short of the top: running out of questions means
/// having read everything and mastered every fact in it, which is the top.
abstract final class Ranks {
  /// The share of the corpus each rank begins at.
  ///
  /// Nine entries, so nine ranks. The gaps widen: the first few arrive quickly,
  /// because a ladder whose first rung takes a week is a ladder nobody steps
  /// on, and the last is the whole corpus exactly — which is the point of the
  /// scale rather than a rounding of it. A reader who has answered everything
  /// there is to answer is at the top, and nothing else is.
  static const List<double> thresholds = <double>[
    0, // Novice, from the first launch
    0.02,
    0.06,
    0.12,
    0.22,
    0.36,
    0.54,
    0.76,
    1, // and the last rank needs all of it
  ];

  /// How many ranks there are.
  static int get count => thresholds.length;

  /// The highest rank, as an index.
  static int get top => thresholds.length - 1;

  /// The rank index for [mastered] facts out of [total].
  ///
  /// Returns the top rank when [total] is zero: with nothing to answer there is
  /// nothing left to answer, and reporting a beginner in a corpus with no
  /// questions in it would be a rank nobody could ever leave.
  static int levelFor(int mastered, int total) {
    if (total <= 0) return top;
    final share = mastered / total;
    var level = 0;
    for (var index = 1; index < thresholds.length; index++) {
      // `>=` so that reaching a threshold exactly is reaching the rank, which
      // is what makes the last one attainable at all.
      if (share >= thresholds[index]) level = index;
    }
    return level;
  }

  /// How far along the current rank the reader is, from 0 to 1.
  ///
  /// At the top rank this is 1: there is no next rung to be part of the way to,
  /// and a bar that sits empty forever once the ladder is finished reads as a
  /// reset rather than as an arrival.
  static double progressWithin(int mastered, int total) {
    if (total <= 0) return 1;
    final level = levelFor(mastered, total);
    if (level >= top) return 1;
    final share = mastered / total;
    final from = thresholds[level];
    final to = thresholds[level + 1];
    if (to <= from) return 1;
    return ((share - from) / (to - from)).clamp(0, 1);
  }

  /// How many more facts the reader needs for the next rank, or `null` at the
  /// top.
  ///
  /// Rounded up, because a reader told they need half a question would be
  /// right to wonder what that meant.
  static int? factsToNext(int mastered, int total) {
    if (total <= 0) return null;
    final level = levelFor(mastered, total);
    if (level >= top) return null;
    final needed = (thresholds[level + 1] * total).ceil();
    return needed <= mastered ? 1 : needed - mastered;
  }
}
