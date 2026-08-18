import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/historical_date.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// A bibliographic record.
///
/// ## The rule that governs this class
///
/// Nothing in a [Source] may ever be invented. A plausible-looking citation is
/// worse than no citation, because it survives checking by everyone who does
/// not check it. Fields whose value is not known are left `null`; they are not
/// filled with something that looks right. That applies with particular force
/// to [identifier], [pages] and [year].
///
/// This is the single most important integrity constraint in the codebase.
class Source {
  const Source({
    required this.id,
    required this.kind,
    required this.title,
    this.authors = const <String>[],
    this.authorsFa = const <String>[],
    this.year,
    this.publisher,
    this.edition,
    this.translator,
    this.url,
    this.identifier,
    this.pages,
    this.license,
    this.rightsNote,
  });

  /// Identifier, unique across sources.
  final String id;

  /// Where this sits in the source-quality hierarchy.
  final SourceKind kind;

  /// The work's title.
  final LocalizedText title;

  /// Author or editor names, as printed.
  final List<String> authors;

  /// The same names in Persian.
  ///
  /// A citation under a Persian article used to read «Plato · جمهوری · 507b»:
  /// the work translated, the author left in Latin, in the middle of a
  /// right-to-left line. Held separately rather than as a [LocalizedText]
  /// because there can be several authors and they are localised as a set.
  final List<String> authorsFa;

  /// The author names to print in [language], falling back to the English
  /// forms when no Persian rendering has been recorded.
  List<String> authorsIn(AppLanguage language) =>
      language == AppLanguage.fa && authorsFa.isNotEmpty ? authorsFa : authors;

  /// Year of this edition or of composition, when known.
  final HistoricalYear? year;

  /// Publisher, when known.
  final String? publisher;

  /// Edition statement, when the edition matters — which for primary texts and
  /// translations it almost always does.
  final String? edition;

  /// Translator, for a [SourceKind.translation].
  final String? translator;

  /// A stable public URL, when one exists.
  final String? url;

  /// A DOI, ISBN or similar. Left `null` unless the actual identifier is known;
  /// never reconstructed from memory or pattern.
  final String? identifier;

  /// Page range, when the citation is to specific pages and those pages are
  /// actually known.
  final String? pages;

  /// The licence the material is available under, where the product reproduces
  /// any of it.
  final String? license;

  /// Any attribution or usage condition attached to the material.
  final String? rightsNote;

  /// Whether this source may be treated as primary evidence.
  bool get isPrimary =>
      kind == SourceKind.primaryText || kind == SourceKind.scholarlyEdition;

  @override
  bool operator ==(Object other) => other is Source && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Source($id, ${title.en})';
}

/// A pointer into a [Source] at a specific place.
///
/// Philosophy cites by canonical locator rather than by page — Stephanus
/// numbers for Plato, Bekker for Aristotle, the A/B pagination for Kant — which
/// is why [locator] is free text rather than a page number: those locators are
/// stable across every edition and translation, and a page number is not.
class Citation {
  const Citation({required this.sourceId, this.locator, this.note});

  /// The [Source] this points at.
  final String sourceId;

  /// Where in the source, in that source's own canonical scheme, e.g.
  /// `Republic 514a`, `Nicomachean Ethics 1097b`, `Critique of Pure Reason
  /// A51/B75`.
  final String? locator;

  /// An optional remark about what the cited passage shows.
  final LocalizedText? note;

  @override
  bool operator ==(Object other) =>
      other is Citation &&
      other.sourceId == sourceId &&
      other.locator == locator;

  @override
  int get hashCode => Object.hash(sourceId, locator);

  @override
  String toString() =>
      locator == null ? 'Citation($sourceId)' : 'Citation($sourceId $locator)';
}
