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

  /// The subject held a position opposed to the object's.
  opposed(id: 'opposed', inverseId: 'opposed-by', isSymmetric: true),

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
  Relation get inverted => Relation(
    subject: object,
    type: type,
    object: subject,
    note: note,
    sourceIds: sourceIds,
    isInverseReading: !isInverseReading,
  );

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
