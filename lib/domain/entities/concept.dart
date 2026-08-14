import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// A philosophical concept.
///
/// [examples] and [counterexamples] are first-class rather than buried in prose
/// because they are how a concept is actually learned. A definition of
/// *eudaimonia* tells a newcomer very little; a case that is eudaimonic and a
/// case that looks eudaimonic but is not tell them a great deal.
class Concept implements KnowledgeEntity {
  const Concept({
    required this.id,
    required this.name,
    required this.oneLine,
    required this.shortDefinition,
    this.nativeTerm,
    this.transliteration,
    this.alsoKnownAs = const <String>[],
    this.traditions = const <String>{},
    this.branches = const <String>{},
    this.article = Article.empty,
    this.examples = const <LocalizedText>[],
    this.counterexamples = const <LocalizedText>[],
    this.relatedConceptIds = const <String>[],
    this.opposingConceptIds = const <String>[],
    this.philosopherIds = const <String>[],
    this.workIds = const <String>[],
    this.citations = const <Citation>[],
  });

  @override
  final String id;

  @override
  final LocalizedText name;

  @override
  final LocalizedText oneLine;

  /// A careful definition, one or two sentences, written for a reader who has
  /// already decided they want the precise version.
  final LocalizedText shortDefinition;

  /// The term in its original language, e.g. `εὐδαιμονία`, `وجود`, `道`.
  final String? nativeTerm;

  /// A Latin-letter transliteration of [nativeTerm].
  final String? transliteration;

  /// Other names the concept travels under, including rival translations —
  /// which for philosophical terms are often the whole argument.
  final List<String> alsoKnownAs;

  @override
  final Set<String> traditions;

  @override
  final Set<String> branches;

  @override
  final Article article;

  /// Cases that fall under the concept.
  final List<LocalizedText> examples;

  /// Cases that do not, especially ones commonly mistaken for it.
  final List<LocalizedText> counterexamples;

  /// Concepts that illuminate this one.
  final List<String> relatedConceptIds;

  /// Concepts this one is defined against.
  final List<String> opposingConceptIds;

  /// Philosophers central to this concept.
  final List<String> philosopherIds;

  /// Works where the concept is developed.
  final List<String> workIds;

  @override
  final List<Citation> citations;

  @override
  EntityRef get ref => EntityRef(EntityKind.concept, id);

  @override
  Iterable<String> get searchableStrings sync* {
    yield* name.allVariants;
    final native = nativeTerm;
    if (native != null) yield native;
    final latin = transliteration;
    if (latin != null) yield latin;
    yield* alsoKnownAs;
    yield* oneLine.allVariants;
    yield* shortDefinition.allVariants;
  }

  @override
  bool operator ==(Object other) => other is Concept && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Concept($id, ${name.en})';
}
