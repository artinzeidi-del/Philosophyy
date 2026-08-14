import 'package:philosophyy/domain/entities/content_section.dart';
import 'package:philosophyy/domain/entities/knowledge_entity.dart';
import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// One division of a work — a book, part, chapter or section.
///
/// Works of philosophy are cited and navigated by their own internal structure,
/// not by page, so the structure is modelled rather than flattened.
class WorkDivision {
  const WorkDivision({
    required this.id,
    required this.title,
    this.summary,
    this.locator,
    this.children = const <WorkDivision>[],
  });

  /// Identifier, unique within the work.
  final String id;

  /// The division's title or number.
  final LocalizedText title;

  /// What happens in this division.
  final LocalizedText? summary;

  /// The canonical locator for this division, e.g. `514a–520a` or `Book II`.
  final String? locator;

  /// Nested divisions.
  final List<WorkDivision> children;

  /// This division and everything beneath it, depth-first.
  Iterable<WorkDivision> get flattened sync* {
    yield this;
    for (final child in children) {
      yield* child.flattened;
    }
  }

  @override
  bool operator ==(Object other) => other is WorkDivision && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A written work.
class Work implements KnowledgeEntity {
  const Work({
    required this.id,
    required this.name,
    required this.oneLine,
    required this.authorId,
    this.originalTitle,
    this.transliteration,
    this.alsoKnownAs = const <String>[],
    this.composed,
    this.traditions = const <String>{},
    this.branches = const <String>{},
    this.article = Article.empty,
    this.structure = const <WorkDivision>[],
    this.conceptIds = const <String>[],
    this.argumentIds = const <String>[],
    this.editionSourceIds = const <String>[],
    this.citations = const <Citation>[],
  });

  @override
  final String id;

  @override
  final LocalizedText name;

  @override
  final LocalizedText oneLine;

  /// The philosopher who wrote it.
  final String authorId;

  /// The title in its original language, e.g. `Πολιτεία`, `الإشارات والتنبيهات`.
  final String? originalTitle;

  /// A Latin-letter transliteration of [originalTitle].
  final String? transliteration;

  /// Other titles the work is known by, including rival translations.
  final List<String> alsoKnownAs;

  /// When it was written. A range, because for most works before the modern
  /// period a single year would be a false precision.
  final HistoricalRange? composed;

  @override
  final Set<String> traditions;

  @override
  final Set<String> branches;

  @override
  final Article article;

  /// The work's internal divisions.
  final List<WorkDivision> structure;

  /// Concepts developed in the work.
  final List<String> conceptIds;

  /// Arguments the work advances.
  final List<String> argumentIds;

  /// Editions and translations, as [Source] identifiers.
  final List<String> editionSourceIds;

  @override
  final List<Citation> citations;

  @override
  EntityRef get ref => EntityRef(EntityKind.work, id);

  /// Every division at every level, depth-first, for building a table of
  /// contents.
  Iterable<WorkDivision> get allDivisions =>
      structure.expand((division) => division.flattened);

  @override
  Iterable<String> get searchableStrings sync* {
    yield* name.allVariants;
    final original = originalTitle;
    if (original != null) yield original;
    final latin = transliteration;
    if (latin != null) yield latin;
    yield* alsoKnownAs;
    yield* oneLine.allVariants;
  }

  @override
  bool operator ==(Object other) => other is Work && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Work($id, ${name.en})';
}
