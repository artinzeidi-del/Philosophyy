/// How confident the product is that a quotation belongs to the person it is
/// attributed to.
///
/// Popular philosophy quotation is riddled with misattribution, and a reference
/// work that repeats it without comment is part of the problem. Every quotation
/// in this product carries one of these, and the interface shows it — including
/// [misattributed], because the most useful thing a reference can do with a
/// famous fake is to say plainly that it is one.
enum AttributionStatus {
  /// Traced to a specific passage in a primary source.
  verified(id: 'verified', order: 0),

  /// Consistent with the attributed author's work and accepted by scholarship,
  /// but not pinned to a located passage.
  probable(id: 'probable', order: 1),

  /// Scholars actively disagree about whether this is authentic.
  disputed(id: 'disputed', order: 2),

  /// Known to belong to someone else, or to no one — recorded so the record
  /// can be corrected rather than repeated.
  misattributed(id: 'misattributed', order: 3),

  /// No source has been traced.
  unknown(id: 'unknown', order: 4);

  const AttributionStatus({required this.id, required this.order});

  /// Stable identifier used in stored content.
  final String id;

  /// Sort order from most to least reliable.
  final int order;

  /// Whether the quotation may be presented as the author's own words.
  bool get isAttributable =>
      this == AttributionStatus.verified || this == AttributionStatus.probable;

  /// Whether the interface must warn the reader before they share or quote it.
  bool get requiresWarning =>
      this == AttributionStatus.disputed ||
      this == AttributionStatus.misattributed ||
      this == AttributionStatus.unknown;

  /// Looks up a status by its stable [id], or returns `null` if unknown.
  static AttributionStatus? fromId(String id) {
    for (final status in AttributionStatus.values) {
      if (status.id == id) return status;
    }
    return null;
  }
}

/// The epistemic status of an authored claim.
///
/// Reference writing constantly slides between "Aristotle was born in Stagira",
/// "Aristotle is best read as a naturalist", and "scholars disagree about
/// whether the *Categories* is authentic" — three very different kinds of
/// sentence presented in the same voice. Tagging them keeps the distinction
/// visible to the reader instead of collapsing it into a uniform tone of
/// authority.
enum ClaimType {
  /// Uncontested and source-backed.
  fact(id: 'fact'),

  /// A defensible reading, presented as a reading.
  interpretation(id: 'interpretation'),

  /// A point on which the scholarship genuinely divides, presented with its
  /// competing positions.
  scholarlyDisagreement(id: 'scholarly-disagreement'),

  /// A proposal offered as a hypothesis, not established.
  hypothesis(id: 'hypothesis'),

  /// A claim in circulation that the evidence does not support.
  disputed(id: 'disputed');

  const ClaimType({required this.id});

  /// Stable identifier used in stored content.
  final String id;

  /// Whether the interface must visibly mark this claim rather than letting it
  /// pass as settled fact.
  bool get requiresMarking => this != ClaimType.fact;

  /// Looks up a claim type by its stable [id], or returns `null` if unknown.
  static ClaimType? fromId(String id) {
    for (final type in ClaimType.values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// The kind of source a citation points at.
///
/// Ordered by the hierarchy the content policy applies: a claim backed by a
/// primary text is on firmer ground than one backed by a general encyclopedia,
/// and the ordering makes that machine-checkable rather than a matter of
/// editorial memory.
enum SourceKind {
  /// The philosopher's own text, in the original language.
  primaryText(id: 'primary-text', rank: 0),

  /// A critical or scholarly edition of a primary text.
  scholarlyEdition(id: 'scholarly-edition', rank: 1),

  /// A translation of a primary text.
  translation(id: 'translation', rank: 2),

  /// A peer-reviewed article.
  journalArticle(id: 'journal-article', rank: 3),

  /// An academic monograph.
  monograph(id: 'monograph', rank: 4),

  /// A major scholarly reference work.
  referenceWork(id: 'reference-work', rank: 5),

  /// A university-hosted or otherwise institutionally backed resource.
  academicResource(id: 'academic-resource', rank: 6);

  const SourceKind({required this.id, required this.rank});

  /// Stable identifier used in stored content.
  final String id;

  /// Position in the source-quality hierarchy; lower is stronger.
  final int rank;

  /// Looks up a source kind by its stable [id], or returns `null` if unknown.
  static SourceKind? fromId(String id) {
    for (final kind in SourceKind.values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}
