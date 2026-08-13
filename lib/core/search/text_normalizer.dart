/// Folds text into a canonical form for indexing and matching.
///
/// ## Why this is not a one-line `toLowerCase()`
///
/// A bilingual philosophy reference has three scripts to deal with and each
/// breaks naive matching in its own way.
///
/// **Persian and Arabic.** The same word is routinely written with different
/// code points depending on the keyboard: Arabic yeh `ي` against Persian yeh
/// `ی`, Arabic kaf `ك` against Persian keheh `ک`, alef with or without its
/// hamza. Optional vowel marks may or may not be typed. Words may be joined by
/// a zero-width non-joiner that a reader searching for the same word will
/// usually type as a space. Without folding all of that together, a reader who
/// types `ابن سينا` on an Arabic keyboard finds nothing, while the identical
/// query typed on a Persian keyboard succeeds.
///
/// **Transliterated Latin.** Scholarly transliteration is full of macrons and
/// under-dots — `Ibn Sīnā`, `Muḥammad`, `Śaṅkara`. Nobody types those into a
/// search box, so they must fold to their plain letters.
///
/// **Greek.** Philosophical vocabulary is quoted in Greek with full
/// accentuation (`εὐδαιμονία`), which readers type without accents if they type
/// it at all, and final sigma varies with position.
///
/// Every transformation here is lossy on purpose: the output is a matching key,
/// never something shown to a reader.
abstract final class TextNormalizer {
  /// Characters that vanish entirely: Arabic vowel marks and other combining
  /// signs, the kashida used to stretch a line, and the hamza carried alone.
  static final RegExp _arabicDiacritics = RegExp(
    '['
    '\u{064B}-\u{065F}' // fathatan through the sukun and superscript marks
    '\u{0670}' // superscript alef
    '\u{06D6}-\u{06ED}' // Qur'anic annotation marks
    '\u{0640}' // tatweel / kashida
    '\u{0621}' // lone hamza
    ']',
    unicode: true,
  );

  /// Combining diacritical marks, which arrive already separated in text that
  /// was composed in decomposed form.
  static final RegExp _combiningMarks = RegExp(
    '[\u{0300}-\u{036F}]',
    unicode: true,
  );

  /// Zero-width characters and bidirectional-control marks, which carry no
  /// meaning for matching but do break naive string comparison.
  static final RegExp _zeroWidth = RegExp(
    '[\u{200B}\u{200D}\u{200E}\u{200F}\u{FEFF}]',
    unicode: true,
  );

  /// Any Arabic-script code point, across the base block, the supplement,
  /// and the presentation forms.
  static final RegExp _arabicScript = RegExp(
    '['
    '\u{0600}-\u{06FF}'
    '\u{0750}-\u{077F}'
    '\u{08A0}-\u{08FF}'
    '\u{FB50}-\u{FDFF}'
    '\u{FE70}-\u{FEFF}'
    ']',
    unicode: true,
  );

  /// Runs of anything that is not a letter or a digit, in any script.
  static final RegExp _tokenSeparators = RegExp(
    r'[^\p{L}\p{N}]+',
    unicode: true,
  );

  /// Single-character substitutions applied before tokenisation.
  ///
  /// Kept as an explicit table rather than a Unicode decomposition because Dart
  /// has no built-in NFD, and because several of these — teh marbuta to heh,
  /// alef maksura to yeh — are orthographic conventions rather than
  /// decompositions and would survive normalisation anyway.
  static const Map<String, String> _characterFolding = <String, String>{
    // --- Arabic script: unify the variants keyboards disagree about ---
    'ي': 'ی', // Arabic yeh -> Persian yeh
    'ى': 'ی', // alef maksura -> Persian yeh
    'ئ': 'ی', // yeh with hamza
    'ك': 'ک', // Arabic kaf -> Persian keheh
    'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', // alef with any hamza or madda
    'ؤ': 'و', // waw with hamza
    'ة': 'ه', // teh marbuta -> heh
    'ۀ': 'ه', // heh with yeh above
    'ه‍': 'ه',

    // --- Arabic-Indic and Persian digits -> Latin ---
    '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
    '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
    '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',

    // --- Latin transliteration: macrons, under-dots, and the rest ---
    'ā': 'a', 'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
    'ă': 'a', 'ą': 'a', 'ạ': 'a', 'ả': 'a',
    'ē': 'e', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ě': 'e', 'ę': 'e',
    'ẹ': 'e', 'ė': 'e',
    'ī': 'i', 'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'į': 'i', 'ị': 'i',
    'ō': 'o', 'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ő': 'o',
    'ø': 'o', 'ọ': 'o',
    'ū': 'u', 'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ů': 'u', 'ű': 'u',
    'ų': 'u', 'ụ': 'u',
    'ṣ': 's', 'ś': 's', 'š': 's', 'ş': 's', 'ș': 's',
    'ḥ': 'h', 'ħ': 'h', 'ḫ': 'h',
    'ṭ': 't', 'ţ': 't', 'ț': 't', 'ť': 't',
    'ẓ': 'z', 'ż': 'z', 'ž': 'z', 'ź': 'z',
    'ç': 'c', 'č': 'c', 'ć': 'c',
    'ñ': 'n', 'ń': 'n', 'ň': 'n', 'ṇ': 'n', 'ṅ': 'n', 'ṃ': 'm',
    'ġ': 'g', 'ğ': 'g', 'ǧ': 'g',
    'ḍ': 'd', 'đ': 'd', 'ď': 'd', 'ḏ': 'd',
    'ṛ': 'r', 'ř': 'r', 'ṝ': 'r',
    'ý': 'y', 'ÿ': 'y', 'ŷ': 'y',
    'ł': 'l', 'ļ': 'l', 'ḷ': 'l',
    'ṯ': 't', 'ẕ': 'z',
    'ʿ': '', 'ʾ': '', 'ʹ': '', 'ʻ': '', '‘': '', '’': '', 'ʼ': '',

    // --- Greek: strip accents, unify final sigma ---
    'ά': 'α', 'έ': 'ε', 'ή': 'η', 'ί': 'ι', 'ό': 'ο', 'ύ': 'υ', 'ώ': 'ω',
    'ϊ': 'ι', 'ϋ': 'υ', 'ΐ': 'ι', 'ΰ': 'υ',
    'ᾶ': 'α', 'ῆ': 'η', 'ῖ': 'ι', 'ῦ': 'υ', 'ῶ': 'ω',
    'ἀ': 'α', 'ἁ': 'α', 'ἄ': 'α', 'ἅ': 'α', 'ἂ': 'α', 'ἃ': 'α',
    'ἐ': 'ε', 'ἑ': 'ε', 'ἔ': 'ε', 'ἕ': 'ε',
    'ἠ': 'η', 'ἡ': 'η', 'ἤ': 'η', 'ἥ': 'η', 'ἦ': 'η', 'ἧ': 'η',
    'ἰ': 'ι', 'ἱ': 'ι', 'ἴ': 'ι', 'ἵ': 'ι', 'ἶ': 'ι', 'ἷ': 'ι',
    'ὀ': 'ο', 'ὁ': 'ο', 'ὄ': 'ο', 'ὅ': 'ο',
    'ὐ': 'υ', 'ὑ': 'υ', 'ὔ': 'υ', 'ὕ': 'υ', 'ὖ': 'υ', 'ὗ': 'υ',
    'ὠ': 'ω', 'ὡ': 'ω', 'ὤ': 'ω', 'ὥ': 'ω', 'ὦ': 'ω', 'ὧ': 'ω',
    'ῳ': 'ω', 'ῃ': 'η', 'ᾳ': 'α',
    'ς': 'σ',

    // --- Latin ligatures ---
    'æ': 'ae', 'œ': 'oe', 'ß': 'ss',
  };

  /// Folds [input] to its canonical matching form.
  ///
  /// The result is lower-case, free of diacritics in every script, with variant
  /// letter forms unified, digits in Latin numerals, and whitespace collapsed.
  static String normalize(String input) {
    if (input.isEmpty) return '';

    var text = input.toLowerCase();

    // The zero-width non-joiner separates parts of a Persian compound that a
    // reader will normally type with a space, so it becomes one.
    text = text.replaceAll('\u{200C}', ' ');
    text = text.replaceAll(_zeroWidth, '');

    text = text.replaceAll(_arabicDiacritics, '');
    text = text.replaceAll(_combiningMarks, '');

    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(_characterFolding[character] ?? character);
    }

    return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Splits [input] into normalised tokens.
  ///
  /// Empty tokens are dropped, so punctuation and stray separators cannot
  /// produce phantom terms in the index.
  static List<String> tokenize(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return const <String>[];
    return normalized
        .split(_tokenSeparators)
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// Whether [text] contains any Arabic-script character, used to decide which
  /// language a query is most likely aimed at.
  static bool containsArabicScript(String text) => _arabicScript.hasMatch(text);
}
