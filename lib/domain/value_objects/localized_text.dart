import 'package:philosophyy/domain/value_objects/app_language.dart';

/// A single authored string held in every language the product ships.
///
/// Content is authored bilingually. When a translation genuinely does not exist
/// yet, pass `null` for [fa] rather than duplicating the English — [isTranslated]
/// then lets the interface be honest about it instead of silently showing
/// English text to a Persian reader as though it had been translated.
class LocalizedText {
  const LocalizedText({required this.en, this.fa});

  /// The English text. Always present — it is the authoring pivot.
  final String en;

  /// The Persian text, or `null` when no translation has been authored.
  final String? fa;

  /// Whether a genuine Persian translation exists.
  bool get isTranslated {
    final persian = fa;
    return persian != null && persian.trim().isNotEmpty;
  }

  /// Whether [language] has authored text of its own.
  bool hasTranslationFor(AppLanguage language) => switch (language) {
    AppLanguage.en => true,
    AppLanguage.fa => isTranslated,
  };

  /// The text to display in [language], falling back to English when the
  /// Persian translation is missing.
  String resolve(AppLanguage language) => switch (language) {
    AppLanguage.en => en,
    AppLanguage.fa => isTranslated ? fa! : en,
  };

  /// The language the text returned by [resolve] is actually written in, which
  /// differs from the requested language whenever a fallback occurred.
  AppLanguage resolvedLanguage(AppLanguage requested) =>
      hasTranslationFor(requested) ? requested : AppLanguage.en;

  /// Every authored variant, for indexing by the search engine.
  Iterable<String> get allVariants sync* {
    yield en;
    if (isTranslated) yield fa!;
  }

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && other.en == en && other.fa == fa;

  @override
  int get hashCode => Object.hash(en, fa);

  @override
  String toString() => 'LocalizedText(en: $en, fa: $fa)';
}
