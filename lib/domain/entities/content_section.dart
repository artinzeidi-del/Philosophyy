import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';
import 'package:philosophyy/domain/value_objects/taxonomy.dart';

/// One authored passage of an article.
///
/// Articles are built from sections rather than from a single blob of prose for
/// two reasons. Progressive disclosure needs to show a reader only the sections
/// at or below their chosen depth, and academic honesty needs each passage to
/// carry its own [claimType] and [citations] — a single article routinely mixes
/// settled fact with contested interpretation, and the reader is entitled to
/// know which sentence is which.
class ContentSection {
  const ContentSection({
    required this.id,
    required this.body,
    this.heading,
    this.depth = ContentDepth.standard,
    this.claimType = ClaimType.fact,
    this.citations = const <Citation>[],
    this.attributedTo,
  });

  /// Identifier, unique within the containing article. Used as an anchor for
  /// deep links and for restoring reading position.
  final String id;

  /// The prose.
  final LocalizedText body;

  /// An optional heading. Sections without one continue the previous section.
  final LocalizedText? heading;

  /// The depth at which this section becomes relevant. A reader on
  /// [ContentDepth.quick] sees only quick sections; one on
  /// the deepest level sees everything.
  final ContentDepth depth;

  /// What kind of claim this passage makes.
  final ClaimType claimType;

  /// Sources supporting the passage.
  final List<Citation> citations;

  /// For a passage stating a particular scholar's position, the name of the
  /// scholar whose reading it is.
  final String? attributedTo;

  /// Whether this section should be shown to a reader reading at [readerDepth].
  bool isVisibleAt(ContentDepth readerDepth) =>
      depth.order <= readerDepth.order;

  /// Whether the interface must mark this passage as something other than
  /// settled fact.
  bool get needsEpistemicMarking => claimType.requiresMarking;

  @override
  bool operator ==(Object other) => other is ContentSection && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ContentSection($id, ${depth.id}, ${claimType.id})';
}

/// An article: the set of sections making up the prose of an entity's entry,
/// together with the operations progressive disclosure needs.
class Article {
  const Article({this.sections = const <ContentSection>[]});

  /// An article with no prose yet.
  static const Article empty = Article();

  /// The sections, in reading order.
  final List<ContentSection> sections;

  /// Whether any prose has been authored.
  bool get isEmpty => sections.isEmpty;

  /// The sections a reader at [depth] should see.
  List<ContentSection> at(ContentDepth depth) =>
      sections.where((section) => section.isVisibleAt(depth)).toList();

  /// The deepest depth at which this article has anything new to offer, so the
  /// interface can avoid inviting a reader deeper into an empty room.
  ContentDepth get deepestAuthoredDepth {
    var deepest = ContentDepth.quick;
    for (final section in sections) {
      if (section.depth.order > deepest.order) deepest = section.depth;
    }
    return deepest;
  }

  /// Whether reading past [from] would actually reveal more text.
  bool hasMoreBeyond(ContentDepth from) =>
      deepestAuthoredDepth.order > from.order;

  /// Every citation used anywhere in the article, de-duplicated, in order of
  /// first appearance.
  List<Citation> get allCitations {
    final seen = <Citation>{};
    final ordered = <Citation>[];
    for (final section in sections) {
      for (final citation in section.citations) {
        if (seen.add(citation)) ordered.add(citation);
      }
    }
    return ordered;
  }

  /// Whether every non-factual passage carries at least one source, which is
  /// the minimum the content policy demands before an article may be published.
  bool get meetsCitationPolicy => sections
      .where((section) => section.claimType != ClaimType.fact)
      .every((section) => section.citations.isNotEmpty);
}
