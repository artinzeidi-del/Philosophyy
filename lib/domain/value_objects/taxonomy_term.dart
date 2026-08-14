import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// What a taxonomy term classifies.
///
/// This *is* a closed set, and legitimately so: it names the axes the product
/// classifies along, not the values on those axes. Adding a tradition must never
/// require a code change; adding a whole new *kind* of classification is a
/// genuine architectural decision.
enum TaxonomyKind {
  /// A cultural, geographic or linguistic lineage of thought.
  tradition(id: 'tradition'),

  /// A field of philosophical enquiry.
  branch(id: 'branch'),

  /// A period of history.
  era(id: 'era');

  const TaxonomyKind({required this.id});

  /// Stable identifier used in stored content.
  final String id;

  /// Looks up a kind by its stable [id], or returns `null`.
  static TaxonomyKind? fromId(String id) {
    for (final kind in TaxonomyKind.values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// One value in the taxonomy — a tradition, a branch, or an era.
///
/// ## Why this is content and not an enum
///
/// It was an enum, with sixteen traditions and eighteen branches compiled into
/// the binary and switched over exhaustively for their labels. That meant Korean
/// philosophy, Ethiopian philosophy, Mesoamerican thought and every Indigenous
/// tradition could not be *named* by the product without a Dart change and a new
/// release. A reference work whose vocabulary of world traditions is fixed at
/// compile time has decided in advance which philosophies exist.
///
/// There is a second, quieter failure a fixed list produces. A branch list drawn
/// from the Western division of philosophy asks every other tradition to file
/// itself under someone else's categories — Nyāya epistemology under
/// "epistemology", Ubuntu ethics under "ethics". Making branches content lets a
/// tradition carry its own conceptual vocabulary alongside the shared one, which
/// a fixed enum structurally cannot.
class TaxonomyTerm implements Comparable<TaxonomyTerm> {
  const TaxonomyTerm({
    required this.id,
    required this.kind,
    required this.name,
    this.parentId,
    this.order = 0,
    this.note,
  });

  /// Stable identifier, used in stored content, routes and saved filters.
  ///
  /// Renaming a term is safe; changing an id breaks content and saved data.
  final String id;

  /// Which axis this term belongs to.
  final TaxonomyKind kind;

  /// The term's name, in every language it has been authored in.
  final LocalizedText name;

  /// The broader term this one sits under, if any.
  ///
  /// Nesting lets "Mesoamerican" sit under "Indigenous" and "Advaita Vedānta"
  /// under "Indian" without flattening either into the other, so a reader can
  /// browse at whichever level they are thinking at.
  final String? parentId;

  /// Sort position among siblings. Ties fall back to the name.
  final int order;

  /// An optional editorial remark — most usefully, why a term is scoped the way
  /// it is, since the boundaries of a tradition are themselves contested.
  final LocalizedText? note;

  /// Whether this term sits at the top of its tree.
  bool get isRoot => parentId == null;

  @override
  int compareTo(TaxonomyTerm other) {
    final byOrder = order.compareTo(other.order);
    return byOrder != 0 ? byOrder : name.en.compareTo(other.name.en);
  }

  @override
  bool operator ==(Object other) =>
      other is TaxonomyTerm && other.id == id && other.kind == kind;

  @override
  int get hashCode => Object.hash(id, kind);

  @override
  String toString() => 'TaxonomyTerm(${kind.id}:$id)';
}

/// The whole taxonomy, indexed for lookup.
///
/// Held by the corpus and consulted wherever a term id needs a name. Nothing in
/// the interface switches over taxonomy values any more; it asks this.
class Taxonomy {
  Taxonomy(List<TaxonomyTerm> terms)
    : _terms = List.unmodifiable(terms),
      _byId = {for (final term in terms) term.id: term};

  /// An empty taxonomy, used as a loading placeholder and in tests.
  static final Taxonomy empty = Taxonomy(const <TaxonomyTerm>[]);

  final List<TaxonomyTerm> _terms;
  final Map<String, TaxonomyTerm> _byId;

  /// Every term, in the order authored.
  List<TaxonomyTerm> get all => _terms;

  /// How many terms are defined.
  int get length => _terms.length;

  /// The term with this id, or `null` if it is not defined.
  TaxonomyTerm? operator [](String id) => _byId[id];

  /// Whether [id] names a defined term.
  bool contains(String id) => _byId.containsKey(id);

  /// Every term of one kind, in sort order.
  List<TaxonomyTerm> ofKind(TaxonomyKind kind) =>
      _terms.where((term) => term.kind == kind).toList()..sort();

  /// The top-level terms of one kind.
  List<TaxonomyTerm> rootsOf(TaxonomyKind kind) =>
      ofKind(kind).where((term) => term.isRoot).toList();

  /// The terms sitting directly under [parentId].
  List<TaxonomyTerm> childrenOf(String parentId) =>
      _terms.where((term) => term.parentId == parentId).toList()..sort();

  /// The name of [id], or the raw id when the term is unknown.
  ///
  /// Falling back to the id rather than throwing keeps a content mistake from
  /// blanking a screen — and the id is at least legible to a reader, where an
  /// empty chip would be a mystery.
  LocalizedText nameOf(String id) => _byId[id]?.name ?? LocalizedText(en: id);

  /// [id] and every ancestor above it, nearest first.
  ///
  /// Used to answer "is this Indian philosophy?" for a term filed under
  /// "Advaita Vedānta", without the caller needing to know the shape of the
  /// tree.
  List<String> ancestryOf(String id) {
    final chain = <String>[];
    var current = _byId[id];
    final guard = <String>{};
    while (current != null && guard.add(current.id)) {
      chain.add(current.id);
      final parent = current.parentId;
      if (parent == null) break;
      current = _byId[parent];
    }
    return chain;
  }

  /// Whether [id] is [ancestorId] or sits anywhere beneath it.
  bool isUnder(String id, String ancestorId) =>
      ancestryOf(id).contains(ancestorId);

  /// Ids referenced by content that this taxonomy does not define.
  ///
  /// The corpus integrity check uses this: a philosopher tagged with a
  /// tradition nobody defined is exactly the kind of dangling reference that
  /// used to be impossible (because the enum enforced it) and is now possible
  /// (because the vocabulary is open). Opening the taxonomy moves that
  /// guarantee from the compiler to this check, so the check has to exist.
  List<String> unknownAmong(Iterable<String> ids) =>
      ids.where((id) => !contains(id)).toSet().toList()..sort();

  /// Terms whose declared parent does not exist.
  List<String> get orphans => _terms
      .where((term) => term.parentId != null && !contains(term.parentId!))
      .map((term) => term.id)
      .toList();
}
