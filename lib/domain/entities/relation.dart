import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// The kinds of connection the knowledge graph records.
///
/// Each type knows how to read in both directions. This matters because a
/// relation authored once as "Aristotle criticised Plato" has to appear on
/// Plato's page too, and it has to appear there as *criticised by*, not as the
/// same sentence with the names swapped.
enum RelationType {
  /// The subject shaped the object's thought.
  influenced(id: 'influenced', inverseId: 'influenced-by'),

  /// The subject argued against the object's position.
  criticized(id: 'criticized', inverseId: 'criticized-by'),

  /// The subject argued in support of the object's position.
  defended(id: 'defended', inverseId: 'defended-by'),

  /// The subject held a position against the object's.
  ///
  /// Directional, not symmetric. It was declared symmetric, which read
  /// tolerably for school against school but produced nonsense everywhere else:
  /// the corpus has "Nietzsche opposed the categorical imperative", and a
  /// symmetric reading puts "opposed Nietzsche" on the concept's page, as
  /// though a doctrine could take a position against a person. Opposition runs
  /// from whoever holds it.
  opposed(id: 'opposed', inverseId: 'opposed-by'),

  /// The subject extended or built on the object.
  developed(id: 'developed', inverseId: 'developed-by'),

  /// The subject was a less direct spur to the object.
  inspired(id: 'inspired', inverseId: 'inspired-by'),

  /// The subject wrote a direct reply to the object.
  respondedTo(id: 'responded-to', inverseId: 'received-response-from'),

  /// The subject is the author of the object.
  wrote(id: 'wrote', inverseId: 'written-by'),

  /// The subject is a member of the object.
  belongsTo(id: 'belongs-to', inverseId: 'has-member'),

  /// The subject taught the object.
  ///
  /// Teacher and student is the oldest structure in philosophy and the one a
  /// reader most often wants to follow. Recording it as [influenced] loses the
  /// distinction between having read someone and having sat with them.
  taught(id: 'taught', inverseId: 'studied-under'),

  /// The subject founded the object.
  founded(id: 'founded', inverseId: 'founded-by'),

  /// The subject led the object after the previous head.
  ///
  /// School headship is how the Academy, the Lyceum and the Stoa are actually
  /// periodised, and a reader following a school forwards in time is following
  /// this edge.
  succeeded(id: 'succeeded', inverseId: 'was-succeeded-by'),

  /// The subject wrote a commentary on the object.
  ///
  /// Commentary is the primary form of philosophical writing across the
  /// Islamic, Indian, Chinese and medieval Latin traditions — Ibn Rushd on
  /// Aristotle, Śaṅkara on the Brahma Sūtras, Zhu Xi on the Analects. Without
  /// this type those traditions can only be recorded in a vocabulary built for
  /// the treatise, which quietly misdescribes them.
  commentedOn(id: 'commented-on', inverseId: 'has-commentary'),

  /// The subject translated the object.
  ///
  /// Translation is not a clerical step between thinkers. The Graeco-Arabic and
  /// Arabic-Latin movements are why particular arguments reached particular
  /// people at all, and the choices made in them are frequently the whole
  /// philosophical question.
  translated(id: 'translated', inverseId: 'translated-by'),

  /// The subject is why the object survives.
  ///
  /// Most pre-Socratics reach us only as quotations inside later writers. The
  /// doxographer is a real link in the chain and often the only evidence there
  /// is, so the graph should show it rather than presenting a fragment as if it
  /// stood on its own.
  preserved(id: 'preserved', inverseId: 'preserved-by'),

  /// The subject brought the object's opposing positions together.
  synthesized(id: 'synthesized', inverseId: 'synthesized-by'),

  /// The subject read the object in a new way that later readers inherited.
  reinterpreted(id: 'reinterpreted', inverseId: 'reinterpreted-by'),

  /// The subject stated a position later recognised in the object.
  ///
  /// Almost always an interpretive claim rather than a documented one — see
  /// [RelationConfidence], which exists partly for this type.
  anticipated(id: 'anticipated', inverseId: 'anticipated-by'),

  /// The subject cannot be true unless the object is.
  presupposes(id: 'presupposes', inverseId: 'presupposed-by'),

  /// The subject's truth would make the object's true.
  entails(id: 'entails', inverseId: 'entailed-by'),

  /// The subject and object cannot both be held.
  contradicts(id: 'contradicts', inverseId: 'contradicts', isSymmetric: true),

  /// The subject is the wider case of which the object is one instance.
  generalizes(id: 'generalizes', inverseId: 'special-case-of'),

  /// The subject is a case that shows what the object means.
  exemplifies(id: 'exemplifies', inverseId: 'exemplified-by'),

  /// The object is credited to the subject, without that being settled.
  ///
  /// Distinct from [wrote]: authorship being contested is itself a fact worth
  /// recording, and collapsing the two would make the product assert something
  /// the scholarship does not.
  attributedTo(id: 'attributed-to', inverseId: 'has-attributed-work'),

  /// The subject and object exchanged letters.
  corresponded(
    id: 'corresponded',
    inverseId: 'corresponded',
    isSymmetric: true,
  ),

  /// The subject and object were working at the same time.
  contemporaryOf(
    id: 'contemporary-of',
    inverseId: 'contemporary-of',
    isSymmetric: true,
  ),

  /// A connection worth drawing that none of the above captures.
  relatedTo(id: 'related-to', inverseId: 'related-to', isSymmetric: true);

  const RelationType({
    required this.id,
    required this.inverseId,
    this.isSymmetric = false,
  });

  /// Stable identifier used in stored content.
  final String id;

  /// Stable identifier of the reading from the object's side.
  final String inverseId;

  /// Whether the relation reads identically in both directions, in which case
  /// the graph must not present it twice.
  final bool isSymmetric;

  /// Looks up a relation type by its stable [id], or returns `null`.
  static RelationType? fromId(String id) {
    for (final type in RelationType.values) {
      if (type.id == id) return type;
    }
    return null;
  }
}

/// How well established it is that a relation holds.
///
/// A knowledge graph draws every edge the same way, which makes every edge look
/// like the same kind of claim. They are not. "Aristotle studied under Plato" is
/// recorded in antiquity; "Heraclitus influenced Hegel" is a reading, argued for
/// and disagreed with. Presenting the second in the same line weight as the
/// first is how a reference work manufactures a consensus that does not exist —
/// and influence claims are exactly where philosophy's own histories are most
/// contested.
///
/// This is the graph's counterpart to [AttributionStatus] on quotations and
/// [ClaimType] on prose. The product's rule is the same in all three places:
/// show the disagreement, do not smooth it away.
enum RelationConfidence {
  /// A text says so — the philosopher's own statement, or an ancient report.
  documented(id: 'documented', order: 0),

  /// Standard in the scholarship, without resting on one located passage.
  accepted(id: 'accepted', order: 1),

  /// Argued for and generally found persuasive, but a reading.
  probable(id: 'probable', order: 2),

  /// Scholars actively disagree that the connection holds.
  contested(id: 'contested', order: 3),

  /// Suggested, on thin evidence. Worth recording, not worth relying on.
  speculative(id: 'speculative', order: 4);

  const RelationConfidence({required this.id, required this.order});

  /// Stable identifier used in stored content.
  final String id;

  /// Sort order from best to least established.
  final int order;

  /// Whether the connection may be presented to a reader without qualification.
  bool get isEstablished =>
      this == RelationConfidence.documented ||
      this == RelationConfidence.accepted;

  /// Whether the interface must mark the edge rather than drawing it plainly.
  bool get requiresMarking => !isEstablished;

  /// Looks up a confidence by its stable [id], or returns `null` if unknown.
  static RelationConfidence? fromId(String id) {
    for (final confidence in RelationConfidence.values) {
      if (confidence.id == id) return confidence;
    }
    return null;
  }
}

/// A single edge in the knowledge graph.
///
/// Relations are authored in one direction and read in both. [Relation.inverted]
/// produces the view from the other endpoint so that traversal code never has
/// to special-case direction.
class Relation {
  const Relation({
    required this.subject,
    required this.type,
    required this.object,
    this.confidence = RelationConfidence.accepted,
    this.note,
    this.sourceIds = const <String>[],
    this.isInverseReading = false,
  });

  /// The entity the relation is authored from.
  final EntityRef subject;

  /// What kind of connection this is.
  final RelationType type;

  /// The entity the relation points at.
  final EntityRef object;

  /// How well established it is that this connection holds.
  ///
  /// Defaults to [RelationConfidence.accepted] rather than to the strongest
  /// value: an edge whose status nobody recorded is standard scholarship at
  /// best, and defaulting to `documented` would let unmarked content claim more
  /// than it can support. A [RelationConfidence.documented] edge must cite a
  /// source, which [isSupported] checks and the corpus integrity check enforces.
  final RelationConfidence confidence;

  /// An optional sentence explaining the connection, which is usually more
  /// valuable to a reader than the bare edge.
  final LocalizedText? note;

  /// Identifiers of sources supporting the claim that this relation holds.
  final List<String> sourceIds;

  /// Whether this instance is the reading from the object's side, in which case
  /// the interface should use the relation type's inverse label.
  final bool isInverseReading;

  /// Whether this relation touches [ref] at either end.
  bool touches(EntityRef ref) => subject == ref || object == ref;

  /// The endpoint that is not [ref], or `null` when [ref] is not an endpoint.
  EntityRef? other(EntityRef ref) {
    if (subject == ref) return object;
    if (object == ref) return subject;
    return null;
  }

  /// This relation as seen from [object]'s side.
  ///
  /// Everything that makes the edge a claim about the world — its confidence,
  /// its note, its sources — travels with it. The graph used to build the
  /// symmetric case by hand instead of using this, and that copy silently
  /// omitted the confidence: an edge marked `probable` on one philosopher's
  /// page appeared unmarked on the other's, which is precisely the manufactured
  /// consensus the confidence field exists to prevent.
  ///
  /// A symmetric relation is *not* an inverse reading. "Contradicts" reads the
  /// same from either end, so the forward label is the correct one from both
  /// and the flag must not flip.
  Relation get inverted => Relation(
    subject: object,
    type: type,
    object: subject,
    confidence: confidence,
    note: note,
    sourceIds: sourceIds,
    isInverseReading: type.isSymmetric ? isInverseReading : !isInverseReading,
  );

  /// Whether the evidence attached to this edge supports the claim it makes.
  ///
  /// A `documented` relation asserts that a text says so, and must name the
  /// text. A `contested` or `speculative` one asserts that someone has argued
  /// it, and must say who — either by citing a source or by explaining itself
  /// in [note]. An edge that claims certainty it cannot show is worse than no
  /// edge, because a reader has no way to tell it apart from one that can.
  bool get isSupported => switch (confidence) {
    RelationConfidence.documented => sourceIds.isNotEmpty,
    RelationConfidence.accepted => true,
    RelationConfidence.probable ||
    RelationConfidence.contested ||
    RelationConfidence.speculative => sourceIds.isNotEmpty || note != null,
  };

  /// The stable identifier of the label to show for this reading.
  String get labelId => isInverseReading ? type.inverseId : type.id;

  @override
  bool operator ==(Object other) =>
      other is Relation &&
      other.subject == subject &&
      other.type == type &&
      other.object == object &&
      other.isInverseReading == isInverseReading;

  @override
  int get hashCode => Object.hash(subject, type, object, isInverseReading);

  @override
  String toString() => '$subject --${type.id}--> $object';
}
