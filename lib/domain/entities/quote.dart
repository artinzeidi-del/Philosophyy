import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/attribution.dart';
import 'package:philosophyy/domain/value_objects/entity_ref.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// A quotation.
///
/// ## Why this class is stricter than it looks
///
/// Quotation is where a philosophy product is most likely to mislead. Famous
/// lines circulate detached from their source, reshaped by repetition, and
/// attached to whichever philosopher sounds right. Every quotation here
/// therefore carries an [attribution] status and, where the status claims
/// verification, a [citation] locating it in a text.
///
/// [Quote.isPublishable] encodes the editorial rule that a quotation may not
/// claim to be verified without a citation to point at, so the rule is enforced
/// by a test rather than by an editor remembering it.
class Quote {
  const Quote({
    required this.id,
    required this.text,
    required this.speakerId,
    required this.attribution,
    this.originalText,
    this.transliteration,
    this.workId,
    this.citation,
    this.context,
    this.attributionNote,
    this.actualSource,
    this.conceptIds = const <String>[],
  });

  /// Identifier, unique across quotations.
  final String id;

  /// The quotation, translated.
  final LocalizedText text;

  /// The quotation in the language it was written in, where that is known and
  /// differs from both display languages.
  ///
  /// In the original script. A romanisation belongs in [transliteration]: a
  /// reader shown Greek for Plato and Chinese for Laozi is being told what
  /// the words looked like, and Latin letters for Sanskrit answer a different
  /// question.
  final String? originalText;

  /// [originalText] in Latin letters, for a script the reader may not read.
  ///
  /// The same pair a philosopher carries as `nativeName` and
  /// `transliteration`, for the same reason: one shows the words, the other
  /// lets them be said.
  final String? transliteration;

  /// The philosopher it is attributed to.
  final String speakerId;

  /// The work it comes from, when known.
  final String? workId;

  /// Where exactly it comes from. Required in practice whenever [attribution]
  /// is [AttributionStatus.verified] — see [isPublishable].
  final Citation? citation;

  /// How reliable the attribution is.
  final AttributionStatus attribution;

  /// What was going on around the passage. Quotations detached from context are
  /// the main way philosophy gets flattened into slogans, and the most common
  /// victims — "God is dead", "man is condemned to be free" — mean something
  /// close to the opposite of their popular reading without it.
  final LocalizedText? context;

  /// An explanation of the attribution, shown whenever the status is anything
  /// other than verified.
  final LocalizedText? attributionNote;

  /// For a misattributed quotation, where the line actually comes from, when
  /// that is known.
  final LocalizedText? actualSource;

  /// Concepts the quotation bears on.
  final List<String> conceptIds;

  /// A typed pointer to this quotation.
  EntityRef get ref => EntityRef(EntityKind.quote, id);

  /// A pointer to the attributed speaker.
  EntityRef get speakerRef => EntityRef(EntityKind.philosopher, speakerId);

  /// Whether this quotation satisfies the editorial rules for display.
  ///
  /// A quotation claiming [AttributionStatus.verified] must have a [citation];
  /// anything less than verified must carry an [attributionNote] explaining the
  /// doubt. Both rules exist so that the interface can never show a confident
  /// attribution the content cannot support.
  bool get isPublishable {
    if (attribution == AttributionStatus.verified) return citation != null;
    return attributionNote != null;
  }

  /// Whether the reader must be shown a caveat alongside the words.
  bool get needsCaveat => attribution.requiresWarning;

  /// Whether this quotation may be offered as a shareable card. Sharing a
  /// misattributed line is exactly how misattribution spreads, so the product
  /// declines to make that easy.
  bool get isShareable => attribution.isAttributable;

  @override
  bool operator ==(Object other) => other is Quote && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Quote($id, ${attribution.id})';
}
