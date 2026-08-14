/// Traditions and branches are NOT defined here.
///
/// They used to be — two enums, sixteen traditions and eighteen branches, fixed
/// at compile time. The scope audit found that this made Korean, Ethiopian,
/// Mesoamerican and every Indigenous tradition unnameable without a Dart change.
/// They are now content: see `assets/content/taxonomy.json` and
/// `TaxonomyTerm`/`Taxonomy` in `taxonomy_term.dart`.
///
/// What remains below is genuinely closed. [ContentDepth] and [LearningLevel]
/// describe how the *product* presents and paces material; they are product
/// decisions with behaviour attached, not a vocabulary of the world.
library;

/// How deeply a piece of content treats its subject.
///
/// The same subject is written at several depths rather than once at a
/// compromise depth, so a curious newcomer and a graduate student can read the
/// same entry without either being failed by it.
enum ContentDepth {
  /// A few sentences. What this is and why it matters.
  quick(id: 'quick', order: 0),

  /// The default treatment: several paragraphs with examples.
  standard(id: 'standard', order: 1),

  /// Full treatment including objections and historical development.
  deep(id: 'deep', order: 2),

  /// Scholarly treatment with apparatus, disagreement, and citations.
  research(id: 'research', order: 3);

  const ContentDepth({required this.id, required this.order});

  /// Stable identifier used in stored content and URLs.
  final String id;

  /// Sort order from shallowest to deepest.
  final int order;

  /// Looks up a depth by its stable [id], or returns `null` if unknown.
  static ContentDepth? fromId(String id) {
    for (final depth in ContentDepth.values) {
      if (depth.id == id) return depth;
    }
    return null;
  }
}

/// The reader's own level, used to choose defaults and pace learning.
enum LearningLevel {
  /// No prior background assumed.
  beginner(id: 'beginner', order: 0),

  /// Comfortable with the vocabulary and the major figures.
  intermediate(id: 'intermediate', order: 1),

  /// Reads primary texts and follows technical argument.
  advanced(id: 'advanced', order: 2),

  /// Works with the scholarly literature directly.
  research(id: 'research', order: 3);

  const LearningLevel({required this.id, required this.order});

  /// Stable identifier used in stored preferences.
  final String id;

  /// Sort order from least to most experienced.
  final int order;

  /// The content depth this reader should be shown by default.
  ContentDepth get defaultDepth => switch (this) {
    LearningLevel.beginner => ContentDepth.quick,
    LearningLevel.intermediate => ContentDepth.standard,
    LearningLevel.advanced => ContentDepth.deep,
    LearningLevel.research => ContentDepth.research,
  };

  /// Looks up a level by its stable [id], or returns `null` if unknown.
  static LearningLevel? fromId(String id) {
    for (final level in LearningLevel.values) {
      if (level.id == id) return level;
    }
    return null;
  }
}
