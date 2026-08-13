import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

/// One numbered step in a reconstructed argument.
class ArgumentStatement {
  const ArgumentStatement({
    required this.id,
    required this.text,
    this.gloss,
    this.citation,
  });

  /// Identifier, unique within the argument. Used for referring to a premise
  /// from an objection.
  final String id;

  /// The claim, stated as precisely as the reconstruction allows.
  final LocalizedText text;

  /// A plain-language restatement for a reader meeting the argument for the
  /// first time.
  final LocalizedText? gloss;

  /// Where the philosopher states or implies this step.
  final Citation? citation;

  @override
  bool operator ==(Object other) =>
      other is ArgumentStatement && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// An objection to an argument, with the replies it has drawn.
class Objection {
  const Objection({
    required this.id,
    required this.text,
    this.targetStatementIds = const <String>[],
    this.raisedByPhilosopherId,
    this.replies = const <LocalizedText>[],
    this.citations = const <Citation>[],
  });

  /// Identifier, unique within the argument.
  final String id;

  /// The objection.
  final LocalizedText text;

  /// Which steps of the argument it attacks. An objection that does not say
  /// which premise it denies is rhetoric rather than philosophy, so this is
  /// modelled explicitly.
  final List<String> targetStatementIds;

  /// Who raised it, when it belongs to a identifiable philosopher.
  final String? raisedByPhilosopherId;

  /// Replies made on the argument's behalf.
  final List<LocalizedText> replies;

  /// Sources for the objection and its replies.
  final List<Citation> citations;

  @override
  bool operator ==(Object other) => other is Objection && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A reconstructed philosophical argument.
///
/// Arguments are modelled as structure rather than prose so the product can do
/// things prose cannot: show an argument's premises one at a time, let a reader
/// see which premise an objection denies, and compare two arguments' shapes.
class Argument {
  const Argument({
    required this.id,
    required this.name,
    required this.oneLine,
    required this.premises,
    required this.conclusion,
    this.assumptions = const <LocalizedText>[],
    this.objections = const <Objection>[],
    this.proponentIds = const <String>[],
    this.opponentIds = const <String>[],
    this.workId,
    this.conceptIds = const <String>[],
    this.branches = const <PhilosophyBranch>{},
    this.citations = const <Citation>[],
  });

  /// Identifier, unique across arguments.
  final String id;

  /// The argument's usual name, e.g. "The Ontological Argument".
  final LocalizedText name;

  /// What the argument tries to show, in one sentence.
  final LocalizedText oneLine;

  /// The premises, in order.
  final List<ArgumentStatement> premises;

  /// What the premises are meant to establish.
  final ArgumentStatement conclusion;

  /// Commitments the argument needs but does not state — often where the real
  /// disagreement lives.
  final List<LocalizedText> assumptions;

  /// Objections raised against it.
  final List<Objection> objections;

  /// Philosophers who advanced it.
  final List<String> proponentIds;

  /// Philosophers who argued against it.
  final List<String> opponentIds;

  /// The work it appears in, when it belongs to one.
  final String? workId;

  /// Concepts it turns on.
  final List<String> conceptIds;

  /// The branches it belongs to.
  final Set<PhilosophyBranch> branches;

  /// Sources for the reconstruction.
  final List<Citation> citations;

  /// A typed pointer to this argument.
  EntityRef get ref => EntityRef(EntityKind.argument, id);

  /// The objections aimed at [statementId].
  List<Objection> objectionsTo(String statementId) => objections
      .where((objection) => objection.targetStatementIds.contains(statementId))
      .toList();

  /// Objections that attack the argument as a whole rather than a named step.
  List<Objection> get generalObjections => objections
      .where((objection) => objection.targetStatementIds.isEmpty)
      .toList();

  /// Whether every objection points at a premise that actually exists.
  ///
  /// An objection referring to a premise that was renamed or removed leaves the
  /// reader with a dangling argument, so this is asserted in tests.
  bool get hasWellFormedObjections {
    final statementIds = premises.map((premise) => premise.id).toSet()
      ..add(conclusion.id);
    return objections.every(
      (objection) => objection.targetStatementIds.every(statementIds.contains),
    );
  }

  @override
  bool operator ==(Object other) => other is Argument && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Argument($id, ${name.en})';
}
