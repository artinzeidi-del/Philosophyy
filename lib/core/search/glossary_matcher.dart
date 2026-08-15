import 'package:philosophyy/domain/entities/glossary_term.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';

/// Where a glossary term occurs in a passage of prose.
class GlossaryMatch implements Comparable<GlossaryMatch> {
  const GlossaryMatch({
    required this.term,
    required this.start,
    required this.end,
  });

  /// The term found.
  final GlossaryTerm term;

  /// Character offset where the word begins.
  final int start;

  /// Character offset just past where it ends.
  final int end;

  @override
  int compareTo(GlossaryMatch other) => start.compareTo(other.start);

  @override
  String toString() => 'GlossaryMatch(${term.id}, $start–$end)';
}

/// Finds glossary terms inside authored prose.
///
/// ## Why the matching is this conservative
///
/// A reader who taps a word expects the word they tapped. Two failure modes
/// would each be worse than missing a term: marking a fragment inside a longer
/// word — `canon` inside `canonical`, `عرض` inside `عرضه` — and marking the
/// same word so often that the page turns into a field of links and stops
/// reading as prose.
///
/// So: matches must fall on word boundaries, the longest term wins where two
/// overlap, and each term is marked only the first time it appears in a
/// section. The first occurrence is the one a reader meets before they know
/// what it means; the fifth is noise.
abstract final class GlossaryMatcher {
  /// Characters that may not sit directly against a match.
  ///
  /// Letters and digits in any script, plus the two joiners Persian sets
  /// inside words — a term followed by a zero-width non-joiner is in the
  /// middle of a Persian compound, not standing alone.
  static bool _isWordCharacter(String character) {
    if (character.isEmpty) return false;
    final code = character.runes.first;
    if (code == 0x200C || code == 0x200D) return true;
    return RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(character);
  }

  static bool _standsAlone(String text, int start, int end) {
    if (start > 0 && _isWordCharacter(text[start - 1])) return false;
    if (end < text.length && _isWordCharacter(text[end])) return false;
    return true;
  }

  /// Every term worth marking in [text], in reading order and without overlaps.
  static List<GlossaryMatch> findIn(
    String text,
    Iterable<GlossaryTerm> glossary,
    AppLanguage language,
  ) {
    final candidates = <GlossaryMatch>[];
    final lower = text.toLowerCase();

    for (final term in glossary) {
      // Longest form first, so "thought experiment" is preferred over
      // "experiment" when a term carries both.
      final forms = term.surfaceFormsFor(language.code)
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final form in forms) {
        final needle = form.toLowerCase();
        if (needle.length < 3) continue;
        final at = lower.indexOf(needle);
        if (at < 0) continue;
        if (!_standsAlone(text, at, at + needle.length)) {
          // Try the next occurrence rather than giving up: the first hit may
          // be inside a longer word while a later one stands alone.
          var next = lower.indexOf(needle, at + 1);
          while (next >= 0 && !_standsAlone(text, next, next + needle.length)) {
            next = lower.indexOf(needle, next + 1);
          }
          if (next < 0) continue;
          candidates.add(
            GlossaryMatch(term: term, start: next, end: next + needle.length),
          );
          break;
        }
        candidates.add(
          GlossaryMatch(term: term, start: at, end: at + needle.length),
        );
        break;
      }
    }

    // Longest match wins where two overlap, and each term appears once.
    candidates.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return (b.end - b.start).compareTo(a.end - a.start);
    });

    final result = <GlossaryMatch>[];
    final used = <String>{};
    var cursor = 0;
    for (final match in candidates) {
      if (match.start < cursor) continue;
      if (!used.add(match.term.id)) continue;
      result.add(match);
      cursor = match.end;
    }
    return result;
  }
}
