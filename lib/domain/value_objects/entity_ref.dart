/// The kinds of thing the knowledge graph can point at.
///
/// Every member here must have a repository that can resolve it and a route
/// that can display it. Adding a member without both is how dead links get
/// into a reference work, so `test/domain/cross_reference_test.dart` checks the
/// invariant rather than trusting it.
enum EntityKind {
  /// A person.
  philosopher(id: 'philosopher', routeSegment: 'philosophers'),

  /// A school or movement.
  school(id: 'school', routeSegment: 'schools'),

  /// An idea, doctrine, or technical term.
  concept(id: 'concept', routeSegment: 'concepts'),

  /// A written work.
  work(id: 'work', routeSegment: 'works'),

  /// A quotation.
  quote(id: 'quote', routeSegment: 'quotes'),

  /// A reconstructed argument.
  argument(id: 'argument', routeSegment: 'arguments'),

  /// A question philosophers have disagreed about.
  problem(id: 'problem', routeSegment: 'problems'),

  /// A bibliographic source.
  source(id: 'source', routeSegment: 'sources');

  const EntityKind({required this.id, required this.routeSegment});

  /// Stable identifier used in stored content.
  final String id;

  /// The path segment this kind lives under, e.g. `/philosophers/plato`.
  final String routeSegment;

  /// Looks up a kind by its stable [id], or returns `null` if unknown.
  static EntityKind? fromId(String id) {
    for (final kind in EntityKind.values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// A typed pointer to an entity.
///
/// The graph stores references, not objects, so that content can be authored
/// and loaded in any order and a missing target is a detectable integrity
/// failure rather than a null dereference at render time.
class EntityRef implements Comparable<EntityRef> {
  const EntityRef(this.kind, this.id);

  /// Parses the canonical `kind:id` form, returning `null` when malformed or
  /// when the kind is not one this build knows about.
  static EntityRef? tryParse(String value) {
    final separator = value.indexOf(':');
    if (separator <= 0 || separator == value.length - 1) return null;
    final kind = EntityKind.fromId(value.substring(0, separator));
    if (kind == null) return null;
    return EntityRef(kind, value.substring(separator + 1));
  }

  /// What kind of entity is being pointed at.
  final EntityKind kind;

  /// The entity's identifier, unique within its [kind].
  final String id;

  /// The canonical string form, `kind:id`.
  String get canonical => '${kind.id}:$id';

  /// The in-app route this reference resolves to.
  String get route => '/${kind.routeSegment}/$id';

  @override
  int compareTo(EntityRef other) {
    final byKind = kind.index.compareTo(other.kind.index);
    return byKind != 0 ? byKind : id.compareTo(other.id);
  }

  @override
  bool operator ==(Object other) =>
      other is EntityRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => canonical;
}
