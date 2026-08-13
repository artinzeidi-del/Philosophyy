/// The languages the product ships in.
///
/// The app is bilingual by construction, not English-first with a translation
/// layer bolted on: every piece of authored content carries both languages, and
/// [AppLanguage] is the key used to resolve it.
enum AppLanguage {
  /// Persian — written right-to-left.
  fa(code: 'fa', isRightToLeft: true, endonym: 'فارسی'),

  /// English — written left-to-right.
  en(code: 'en', isRightToLeft: false, endonym: 'English');

  const AppLanguage({
    required this.code,
    required this.isRightToLeft,
    required this.endonym,
  });

  /// BCP-47 language subtag.
  final String code;

  /// Whether text in this language flows right-to-left.
  final bool isRightToLeft;

  /// The language's name written in the language itself.
  final String endonym;

  /// Resolves a language subtag, falling back to [AppLanguage.en] when the
  /// platform reports a locale the product does not ship.
  static AppLanguage fromCode(String? code) {
    if (code == null) return AppLanguage.en;
    final normalized = code.toLowerCase().split(RegExp('[-_]')).first;
    for (final language in AppLanguage.values) {
      if (language.code == normalized) return language;
    }
    return AppLanguage.en;
  }
}
