import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// One step of the guided introduction.
///
/// ## Why this is content rather than a screen
///
/// The order is the teaching. Which step comes before which is the editorial
/// claim the whole feature rests on — that you cannot usefully be told what an
/// argument is before you have been told what a claim is — and a claim of that
/// kind belongs in the corpus, where it can be revised, reviewed and
/// translated, rather than in a widget tree.
class PrimerStep {
  const PrimerStep({
    required this.id,
    required this.title,
    required this.body,
    this.question,
    this.reads = const <EntityRef>[],
    this.citations = const <Citation>[],
  });

  /// Identifier, unique across the primer.
  final String id;

  /// The step's heading.
  final LocalizedText title;

  /// The teaching itself.
  final LocalizedText body;

  /// Something for the reader to try, where the step is better answered than
  /// read.
  final LocalizedText? question;

  /// Entries that show the step being done, in the order to meet them.
  final List<EntityRef> reads;

  /// Where the account comes from.
  final List<Citation> citations;

  @override
  bool operator ==(Object other) => other is PrimerStep && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PrimerStep($id)';
}
