/// The branches of philosophy the product organises content by.
///
/// The list is deliberately broad. A reference that recognises only the five
/// classical branches quietly tells a reader interested in, say, philosophy of
/// technology that their question is not philosophy.
///
/// Each member carries a stable [id] used in stored content and deep links.
/// Renaming a member is safe; changing an [id] breaks saved data and links.
enum PhilosophyBranch {
  /// What there is, and what it is to be.
  metaphysics(id: 'metaphysics'),

  /// Knowledge, justification, and the limits of both.
  epistemology(id: 'epistemology'),

  /// How one ought to live and act.
  ethics(id: 'ethics'),

  /// Valid inference and the structure of argument.
  logic(id: 'logic'),

  /// Beauty, art, and aesthetic judgement.
  aesthetics(id: 'aesthetics'),

  /// Authority, justice, rights, and the state.
  politicalPhilosophy(id: 'political-philosophy'),

  /// Consciousness, intentionality, and the mental.
  philosophyOfMind(id: 'philosophy-of-mind'),

  /// Meaning, reference, and communication.
  philosophyOfLanguage(id: 'philosophy-of-language'),

  /// The methods, status, and claims of the sciences.
  philosophyOfScience(id: 'philosophy-of-science'),

  /// Religious belief, argument, and experience.
  philosophyOfReligion(id: 'philosophy-of-religion'),

  /// Society, culture, and collective life.
  socialPhilosophy(id: 'social-philosophy'),

  /// Existence, freedom, absurdity, and meaning.
  existentialPhilosophy(id: 'existential-philosophy'),

  /// Technology's effect on human life and agency.
  philosophyOfTechnology(id: 'philosophy-of-technology'),

  /// Law, obligation, and legal interpretation.
  philosophyOfLaw(id: 'philosophy-of-law'),

  /// Teaching, learning, and formation.
  philosophyOfEducation(id: 'philosophy-of-education'),

  /// Historical explanation, progress, and narrative.
  philosophyOfHistory(id: 'philosophy-of-history'),

  /// The nature of mathematical objects and truth.
  philosophyOfMathematics(id: 'philosophy-of-mathematics'),

  /// Value, exchange, and economic method.
  philosophyOfEconomics(id: 'philosophy-of-economics');

  const PhilosophyBranch({required this.id});

  /// Stable identifier used in stored content and URLs.
  final String id;

  /// Looks up a branch by its stable [id], or returns `null` if unknown.
  static PhilosophyBranch? fromId(String id) {
    for (final branch in PhilosophyBranch.values) {
      if (branch.id == id) return branch;
    }
    return null;
  }
}

/// The traditions the product covers.
///
/// These overlap by design — Avicenna belongs to both [islamic] and [persian],
/// and Maimonides to both [islamic] (in context) and [jewish]. Traditions are
/// therefore a set on each entity, never a single classification, because
/// forcing a single one falsifies the history.
enum Tradition {
  /// Classical Greek philosophy.
  ancientGreek(id: 'ancient-greek'),

  /// Roman philosophy.
  roman(id: 'roman'),

  /// Post-Aristotelian Greek schools: Stoic, Epicurean, Sceptic, Cynic.
  hellenistic(id: 'hellenistic'),

  /// Latin Christian and scholastic philosophy of the Middle Ages.
  medieval(id: 'medieval'),

  /// Philosophy in the Islamic world.
  islamic(id: 'islamic'),

  /// The Persian philosophical tradition.
  persian(id: 'persian'),

  /// Jewish philosophy.
  jewish(id: 'jewish'),

  /// Christian philosophical theology.
  christian(id: 'christian'),

  /// Indian philosophy, orthodox and heterodox alike.
  indian(id: 'indian'),

  /// Chinese philosophy.
  chinese(id: 'chinese'),

  /// Japanese philosophy.
  japanese(id: 'japanese'),

  /// African and Africana philosophy.
  african(id: 'african'),

  /// Latin American philosophy.
  latinAmerican(id: 'latin-american'),

  /// Modern and continental European philosophy.
  european(id: 'european'),

  /// American philosophy, including pragmatism.
  american(id: 'american'),

  /// Philosophy from roughly the mid-twentieth century onward.
  contemporary(id: 'contemporary');

  const Tradition({required this.id});

  /// Stable identifier used in stored content and URLs.
  final String id;

  /// Looks up a tradition by its stable [id], or returns `null` if unknown.
  static Tradition? fromId(String id) {
    for (final tradition in Tradition.values) {
      if (tradition.id == id) return tradition;
    }
    return null;
  }
}

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
