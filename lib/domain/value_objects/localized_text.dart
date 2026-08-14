import 'package:philosophyy/domain/value_objects/app_language.dart';

/// A single authored string, held in every language it has been written in.
///
/// ## Why there is a map here and not just two fields
///
/// This used to be exactly `{required String en, String? fa}`. The two shipped
/// languages were named in the type, and everything that consumed the class —
/// the resolver, the search-variant getter, the JSON mapper — switched over
/// those two fields exhaustively. That put a ceiling in the wrong place: an
/// entry could not carry a third language *at all*, even as data waiting for
/// an interface, without editing this file and four others.
///
/// [translations] holds any further language, keyed by BCP-47 subtag, and every
/// consumer goes through [forCode]. The mapper reads whatever a content file
/// offers, so authoring an Arabic or French translation is a content change.
/// Displaying it additionally needs an [AppLanguage] value, an ARB file and a
/// font — real work, but work about the interface rather than about this class.
///
/// ## Why English and Persian keep named fields
///
/// English is the authoring pivot: written first, guaranteed present, and the
/// fallback when nothing else is. Making it a required field is the compiler
/// enforcing an editorial rule that would otherwise need a runtime check.
///
/// Persian is the other language the product actually ships — with a font, a
/// type scale and translated chrome. Naming it is not a claim that Persian
/// outranks other languages; it is that "has this been translated yet" is asked
/// of Persian constantly, by [isTranslated] and by the editorial coverage
/// checks, and answering it through a map lookup would read worse everywhere.
///
/// When a Persian translation genuinely does not exist yet, pass `null` rather
/// than duplicating the English — [isTranslated] then lets the interface be
/// honest about it instead of silently showing English to a Persian reader as
/// though it had been translated.
class LocalizedText {
  const LocalizedText({
    required this.en,
    this.fa,
    this.translations = const <String, String>{},
  });

  /// The English text. Always present — it is the authoring pivot.
  final String en;

  /// The Persian text, or `null` when no translation has been authored.
  final String? fa;

  /// Any further languages, keyed by BCP-47 subtag.
  ///
  /// Content may carry a language before the interface can display it; that is
  /// the point. Nothing here is privileged over anything else in it.
  final Map<String, String> translations;

  /// Every language subtag this string has authored text in.
  Iterable<String> get languages sync* {
    yield AppLanguage.en.code;
    if (_isPresent(fa)) yield AppLanguage.fa.code;
    for (final entry in translations.entries) {
      if (_isPresent(entry.value)) yield entry.key;
    }
  }

  /// The text authored in [code], or `null` when there is none.
  ///
  /// Blank and whitespace-only strings count as absent. A translation field
  /// left as `""` is an untranslated entry, and treating it as translated is
  /// how a reader ends up staring at an empty heading.
  String? forCode(String code) {
    if (code == AppLanguage.en.code) return _isPresent(en) ? en : null;
    if (code == AppLanguage.fa.code) return _isPresent(fa) ? fa : null;
    final text = translations[code];
    return _isPresent(text) ? text : null;
  }

  /// Whether a genuine Persian translation exists.
  bool get isTranslated => hasTranslationFor(AppLanguage.fa);

  /// Whether [language] has authored text of its own.
  bool hasTranslationFor(AppLanguage language) =>
      forCode(language.code) != null;

  /// The text to display in [language], falling back to English when no
  /// translation has been authored.
  String resolve(AppLanguage language) => forCode(language.code) ?? en;

  /// The language the text returned by [resolve] is actually written in, which
  /// differs from the requested language whenever a fallback occurred.
  AppLanguage resolvedLanguage(AppLanguage requested) =>
      hasTranslationFor(requested) ? requested : AppLanguage.en;

  /// Every authored variant, for indexing by the search engine.
  ///
  /// All languages, not only the two the interface offers: a name authored in a
  /// language the app cannot yet display is still worth finding by, and a
  /// reader who types it is looking for exactly this entry.
  Iterable<String> get allVariants sync* {
    for (final code in languages) {
      final text = forCode(code);
      if (text != null) yield text;
    }
  }

  static bool _isPresent(String? text) =>
      text != null && text.trim().isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (other is! LocalizedText) return false;
    if (other.en != en || other.fa != fa) return false;
    if (other.translations.length != translations.length) return false;
    for (final entry in translations.entries) {
      if (other.translations[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    en,
    fa,
    Object.hashAllUnordered(
      translations.entries.map((entry) => Object.hash(entry.key, entry.value)),
    ),
  );

  @override
  String toString() {
    final extra = translations.isEmpty ? '' : ', $translations';
    return 'LocalizedText(en: $en, fa: $fa$extra)';
  }
}
