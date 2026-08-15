import 'package:philosophyy/domain/entities/source.dart';
import 'package:philosophyy/domain/value_objects/localized_text.dart';

/// A word that stops a reader.
///
/// ## Why this is a separate thing from a concept
///
/// A concept entry is an entry: it has an article, a tradition, philosophers who
/// hold it and works that state it. A glossary term is smaller and does a
/// different job — it is the answer to "what does that word mean" delivered
/// without leaving the sentence. `Substance` needs one; so do `a priori`,
/// `dialectic` and `elenchus`, none of which are entries and none of which a
/// reader can be assumed to know.
///
/// The two are linked rather than merged: a term that does have an entry
/// carries [conceptId], so the box offering the meaning can also offer the
/// article.
class GlossaryTerm implements Comparable<GlossaryTerm> {
  const GlossaryTerm({
    required this.id,
    required this.term,
    required this.shortDefinition,
    this.longDefinition,
    this.nativeTerm,
    this.transliteration,
    this.aliases = const <String>[],
    this.conceptId,
    this.citations = const <Citation>[],
  });

  /// Identifier, unique across the glossary.
  final String id;

  /// The word itself, in each language.
  final LocalizedText term;

  /// One sentence. What the box shows first.
  final LocalizedText shortDefinition;

  /// A paragraph, for the glossary screen and for a reader who wants more
  /// without opening a whole article.
  final LocalizedText? longDefinition;

  /// The word in its original script, where it has one.
  final String? nativeTerm;

  /// A romanisation of [nativeTerm].
  final String? transliteration;

  /// Other spellings and inflections that should also be recognised in prose.
  ///
  /// Held as content rather than derived, because the endings that matter
  /// differ per language and per word: English needs plurals, Persian needs
  /// the ezāfe and the plural suffixes, and guessing produces false matches
  /// that are worse than a missed one.
  final List<String> aliases;

  /// The concept entry for this term, when the corpus has one.
  final String? conceptId;

  /// Where the definition comes from.
  final List<Citation> citations;

  /// Every surface form worth recognising in the prose of a language.
  List<String> surfaceFormsFor(String languageCode) => <String>[
    if (languageCode == 'fa') ...<String>[
      ?term.fa,
      ...aliases.where(_isArabicScript),
    ] else ...<String>[
      term.en,
      ...aliases.where((alias) => !_isArabicScript(alias)),
    ],
  ].where((form) => form.trim().isNotEmpty).toList();

  static bool _isArabicScript(String text) =>
      text.runes.any((rune) => rune >= 0x0600 && rune <= 0x06FF);

  @override
  int compareTo(GlossaryTerm other) =>
      term.en.toLowerCase().compareTo(other.term.en.toLowerCase());

  @override
  bool operator ==(Object other) => other is GlossaryTerm && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'GlossaryTerm($id)';
}
