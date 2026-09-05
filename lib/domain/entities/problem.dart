import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/relation.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// One stance taken on a philosophical problem.
///
/// A position is not an argument and not a school. It is the answer a group of
/// people give to one question — compatibilism about free will, nominalism
/// about universals — and it is the thing arguments are *for*. Modelling it
/// separately is what lets a problem's page show the disagreement as a shape
/// rather than as a list of names: two positions, the arguments each rests on,
/// and the people on each side.
class Position {
  const Position({
    required this.id,
    required this.name,
    required this.summary,
    this.philosopherIds = const <String>[],
    this.argumentIds = const <String>[],
    this.schoolIds = const <String>[],
    this.citations = const <Citation>[],
    this.attribution = RelationConfidence.accepted,
    this.attributionNote,
  });

  /// Identifier, unique within the problem.
  final String id;

  /// What the position is called.
  final LocalizedText name;

  /// The stance in one sentence, stated as its holders would state it.
  ///
  /// Written from inside rather than about: a position summarised by its
  /// opponents is a straw man with a citation.
  final LocalizedText summary;

  /// Philosophers who hold it.
  final List<String> philosopherIds;

  /// Arguments advanced for it.
  final List<String> argumentIds;

  /// Schools identified with it.
  final List<String> schoolIds;

  /// Sources for the attribution of the position.
  final List<Citation> citations;

  /// How securely the stance belongs to the people named as holding it.
  ///
  /// Positions are assigned by later readers as often as they are declared.
  /// Nobody in the ancient world called themselves a compatibilist, and a
  /// philosopher can be the clearest exponent of a view they never stated as a
  /// view. Recording that is the difference between reporting a position and
  /// inventing a party.
  final RelationConfidence attribution;

  /// Why the attribution is anything other than straightforward.
  ///
  /// Required by the mapper whenever [attribution] is weaker than accepted.
  final LocalizedText? attributionNote;

  /// Whether the stance can be stated as its holders' own without qualifying.
  bool get hasSettledAttribution =>
      attribution == RelationConfidence.documented ||
      attribution == RelationConfidence.accepted;

  @override
  bool operator ==(Object other) => other is Position && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Position($id, ${name.en})';
}

/// A question philosophers have disagreed about, with the shape of the
/// disagreement.
///
/// ## Why this exists as its own kind
///
/// A concept is a notion — substance, karma, the harm principle. A problem is a
/// question with rival answers, and the answers are what a reader wants. The
/// corpus could already say what the ontological argument is and what the
/// problem of evil is; it could not say that both are moves in one long
/// argument about whether there is a God, or show a reader who has just read
/// Anselm where to find the reply.
///
/// This is the join the knowledge graph was missing. Every other kind connects
/// outward to related things; a problem connects *rival* things, and records
/// which side each is on.
class Problem implements KnowledgeEntity {
  const Problem({
    required this.id,
    required this.name,
    required this.oneLine,
    required this.question,
    this.positions = const <Position>[],
    this.argumentIds = const <String>[],
    this.conceptIds = const <String>[],
    this.workIds = const <String>[],
    this.traditions = const <String>{},
    this.branches = const <String>{},
    this.article = Article.empty,
    this.citations = const <Citation>[],
  });

  @override
  final String id;

  @override
  final LocalizedText name;

  @override
  final LocalizedText oneLine;

  /// The question itself, stated as a question.
  ///
  /// Separate from [oneLine], which says why it matters. A problem whose
  /// question cannot be written as one sentence is usually two problems.
  final LocalizedText question;

  /// The rival answers, in no privileged order.
  ///
  /// Order is presentation, not ranking: a reference that lists the position it
  /// finds convincing first has taken a side without saying so.
  final List<Position> positions;

  /// Arguments that bear on the problem without belonging to one position —
  /// the ones that reframe the question rather than answer it.
  final List<String> argumentIds;

  /// Concepts the problem turns on.
  final List<String> conceptIds;

  /// Works where the problem is set out or advanced.
  final List<String> workIds;

  @override
  final Set<String> traditions;

  @override
  final Set<String> branches;

  @override
  final Article article;

  @override
  final List<Citation> citations;

  @override
  EntityRef get ref => EntityRef(EntityKind.problem, id);

  @override
  Iterable<String> get searchableStrings sync* {
    yield* name.allVariants;
    yield* oneLine.allVariants;
    yield* question.allVariants;
    for (final position in positions) {
      yield* position.name.allVariants;
    }
  }

  /// Every argument the problem reaches, whether through a position or not.
  Set<String> get allArgumentIds => <String>{
    ...argumentIds,
    for (final position in positions) ...position.argumentIds,
  };

  /// Every philosopher named on any side.
  Set<String> get allPhilosopherIds => <String>{
    for (final position in positions) ...position.philosopherIds,
  };

  @override
  bool operator ==(Object other) => other is Problem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Problem($id, ${name.en})';
}
