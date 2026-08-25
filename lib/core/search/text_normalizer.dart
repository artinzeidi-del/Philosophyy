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

    // --- Pinyin tone marks ---
    //
    // The third tone was the gap: «ā á à» were all here and «ǎ» was not, so
    // Lǎozǐ, Kǒngzǐ and Lǐ could not be reached by typing Laozi, Kongzi or
    // Li. The four tones of a vowel are one letter to anyone searching.
    'ǎ': 'a', 'ǐ': 'i', 'ǒ': 'o', 'ǔ': 'u',
    'ǖ': 'u', 'ǘ': 'u', 'ǚ': 'u', 'ǜ': 'u',
    'ǹ': 'n', 'ḿ': 'm',

    // --- Vietnamese ---
    //
    // Vietnamese stacks a tone on a vowel that already carries a mark, and
    // Unicode gives each combination its own code point, so none of them
    // decompose to anything already in this table. Trần Nhân Tông was
    // unreachable by typing his name in plain letters.
    'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'ẻ': 'e', 'ẽ': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ỉ': 'i', 'ĩ': 'i',
    'ỏ': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ủ': 'u', 'ũ': 'u', 'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u',
    'ự': 'u',
    'ỳ': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',

    // --- The schwa, which Ethiopic transliteration needs ---
    'ə': 'e', 'ᵊ': 'e',

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

  /// [_characterFolding] again, keyed by code point instead of by string.
  ///
  /// The table above is written with characters because that is the only form
  /// in which it can be read and checked. Looking it up that way cost a string
  /// allocation and a string hash for every character of the corpus, which is
  /// 1.7 million of each per index build. Same table, keyed by the integer the
  /// loop already has.
  static final Map<int, String> _foldingByRune = <int, String>{
    for (final entry in _characterFolding.entries)
      entry.key.runes.first: entry.value,
  };

  /// Collapses runs of whitespace.
  ///
  /// Static because it used to be built inside [normalize]: a fresh `RegExp`
  /// compiled on every one of the corpus's six thousand strings, and again on
  /// every keystroke.
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// Whether [text] is entirely ASCII.
  ///
  /// Every key in the folding table and every range in the regexes above is
  /// outside ASCII, so an ASCII string is already in canonical form apart from
  /// case and spacing. Roughly half the corpus is English prose that never
  /// leaves ASCII, and this lets it skip four regex passes and the folding
  /// loop entirely.
  static bool _isAscii(String text) {
    for (var index = 0; index < text.length; index++) {
      if (text.codeUnitAt(index) > 0x7F) return false;
    }
    return true;
  }

  /// Folds [input] to its canonical matching form.
  ///
  /// The result is lower-case, free of diacritics in every script, with variant
  /// letter forms unified, digits in Latin numerals, and whitespace collapsed.
  static String normalize(String input) {
    if (input.isEmpty) return '';

    var text = input.toLowerCase();

    if (_isAscii(text)) {
      return text.trim().replaceAll(_whitespaceRun, ' ');
    }

    // The zero-width non-joiner separates parts of a Persian compound that a
    // reader will normally type with a space, so it becomes one.
    text = text.replaceAll('\u{200C}', ' ');
    text = text.replaceAll(_zeroWidth, '');

    text = text.replaceAll(_arabicDiacritics, '');
    text = text.replaceAll(_combiningMarks, '');

    final buffer = StringBuffer();
    for (final rune in text.runes) {
      final folded = _foldingByRune[rune];
      if (folded != null) {
        buffer.write(folded);
      } else {
        buffer.writeCharCode(rune);
      }
    }

    return buffer.toString().trim().replaceAll(_whitespaceRun, ' ');
  }

  /// Splits [input] into normalised tokens.
  ///
  /// Empty tokens are dropped, so punctuation and stray separators cannot
  /// produce phantom terms in the index.
  ///
  /// ## Why ASCII is split by hand
  ///
  /// [_tokenSeparators] is a Unicode-property regex, and running it over the
  /// corpus was the single most expensive thing the app did: 788 of the 1,455
  /// milliseconds it took to build the search index, which the reader paid as a
  /// freeze on the first letter they typed. A third of the corpus's strings and
  /// about half its characters are English prose that never leaves ASCII, and
  /// for those the property lookup answers a question two comparisons can.
  ///
  /// The fast path is checked against the general one by a test that tokenises
  /// the whole corpus both ways, rather than trusted because the ranges look
  /// right.
  static List<String> tokenize(String input) {
    final normalized = normalize(input);
    if (normalized.isEmpty) return const <String>[];
    return _scan(normalized) ?? _splitByProperty(normalized);
  }

  static List<String> _splitByProperty(String normalized) => normalized
      .split(_tokenSeparators)
      .where((token) => token.isNotEmpty)
      .toList();

  /// Whether [unit] is a letter or digit in one of the scripts the corpus uses.
  ///
  /// Deliberately narrower than `\p{L}\p{N}`. It has to be: the point is to
  /// answer without a property lookup, and the only way to be sure of an answer
  /// given by hand is to give it for a bounded set. [_isSeparator] covers the
  /// other side, and anything in neither set is unknown — see [_scan].
  static bool _isLetterOrDigit(int unit) =>
      // ASCII, already lower-cased by `normalize`.
      (unit >= 0x61 && unit <= 0x7A) ||
      (unit >= 0x30 && unit <= 0x39) ||
      // Latin-1 and Latin Extended-A/B: mostly folded away already, but a
      // reader can type them, and ÷ and × sit inside the block.
      (unit >= 0x00C0 && unit <= 0x024F && unit != 0x00D7 && unit != 0x00F7) ||
      // Greek, avoiding the ano teleia at 0x0387.
      (unit >= 0x0388 && unit <= 0x03FF && unit != 0x03F6) ||
      // Hebrew letters.
      (unit >= 0x05D0 && unit <= 0x05EA) ||
      // Arabic script: letters, then the Persian and Arabic-Indic digits.
      // The block's punctuation — ، ؛ ؟ ۔ — is excluded by the ranges.
      (unit >= 0x0620 && unit <= 0x064A) ||
      (unit >= 0x0660 && unit <= 0x0669) ||
      (unit >= 0x0671 && unit <= 0x06D3) ||
      unit == 0x06D5 ||
      (unit >= 0x06EE && unit <= 0x06FF) ||
      // Devanagari consonants, vowels and digits — but not the vowel *signs*
      // at 0x093A–0x094F, which are combining marks. `\p{L}\p{N}` does not
      // match a mark, so the regex cuts नागार्जुन into five tokens at every
      // sign, and a range that called them letters produced one. Whether
      // that is the better indexing is a separate question from whether the
      // two paths agree; they are left out, so a word containing one takes
      // the general path and behaviour is unchanged.
      (unit >= 0x0904 && unit <= 0x0939) ||
      (unit >= 0x0966 && unit <= 0x096F) ||
      // CJK unified ideographs.
      (unit >= 0x4E00 && unit <= 0x9FFF);

  /// Whether [unit] certainly separates tokens.
  static bool _isSeparator(int unit) =>
      // ASCII controls, space, and every ASCII punctuation range.
      unit <= 0x2F ||
      (unit >= 0x3A && unit <= 0x40) ||
      (unit >= 0x5B && unit <= 0x60) ||
      (unit >= 0x7B && unit <= 0x7E) ||
      // Latin-1 punctuation and symbols, including « » · and the nbsp.
      (unit >= 0x00A0 && unit <= 0x00BF) ||
      unit == 0x00D7 ||
      unit == 0x00F7 ||
      // Arabic comma, semicolon, question mark, full stop and the ornate
      // marks between them.
      unit == 0x060C ||
      unit == 0x061B ||
      unit == 0x061F ||
      (unit >= 0x066A && unit <= 0x066D) ||
      unit == 0x06D4 ||
      // General punctuation: dashes, quotation marks, the ellipsis, the
      // bullet, the section sign's neighbours. The em dash and curly
      // apostrophe live here, and they are why an ASCII-only fast path never
      // fired on English prose.
      (unit >= 0x2000 && unit <= 0x206F) ||
      // Devanagari danda and double danda.
      unit == 0x0964 ||
      unit == 0x0965 ||
      // CJK punctuation, including the ideographic full stop and comma.
      (unit >= 0x3000 && unit <= 0x303F);

  /// Splits [text] by hand, or returns `null` if it contains a character this
  /// cannot classify.
  ///
  /// ## Why the bail-out
  ///
  /// The regex this replaces was the most expensive thing the app did — 788 of
  /// the 1,455 milliseconds it took to build the index, which the reader paid
  /// as a freeze on the first letter they typed. Replacing a Unicode property
  /// with hand-written ranges trades that cost for the risk of getting a range
  /// wrong, and a wrong range here does not crash: it silently stops indexing
  /// a script.
  ///
  /// So the ranges are not required to be exhaustive. A character in neither
  /// [_isLetterOrDigit] nor [_isSeparator] abandons the scan and the caller
  /// falls back to the property regex for that string. Being narrow costs
  /// speed on strings that use it; being wrong is not on the table.
  ///
  /// The two paths are also compared against each other over the whole corpus
  /// by a test, so a range that is merely *inconsistent* fails rather than
  /// quietly shrinking the index.
  static List<String>? _scan(String text) {
    final tokens = <String>[];
    var start = -1;
    for (var index = 0; index < text.length; index++) {
      final unit = text.codeUnitAt(index);
      if (_isLetterOrDigit(unit)) {
        if (start < 0) start = index;
        continue;
      }
      if (!_isSeparator(unit)) return null;
      if (start >= 0) {
        tokens.add(text.substring(start, index));
        start = -1;
      }
    }
    if (start >= 0) tokens.add(text.substring(start));
    return tokens;
  }

  /// Whether [text] contains any Arabic-script character, used to decide which
  /// language a query is most likely aimed at.
  static bool containsArabicScript(String text) => _arabicScript.hasMatch(text);
}
