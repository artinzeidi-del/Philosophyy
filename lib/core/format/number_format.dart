import 'package:philosophyy/domain/value_objects/app_language.dart';

/// Renders numbers in the digits the reader's language actually uses.
///
/// Persian text sets numbers in Persian-Indic digits. Showing `1037` inside a
/// Persian sentence is the typographic equivalent of switching alphabet
/// mid-word: legible, but visibly foreign. Years are never grouped with
/// separators in either language, so this deliberately does not use a
/// thousands separator.
abstract final class AppNumbers {
  static const List<String> _persianDigits = <String>[
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];

  /// Rewrites any Latin digits in [text] into the digits [language] uses.
  ///
  /// ## Why this is needed at all
  ///
  /// `flutter gen-l10n` formats the numbers inside plural messages itself, and
  /// it formats them in Latin digits regardless of locale. So every counted
  /// string in the product — "3 results", "5 items", "2 objections", "Step 1
  /// of 9" — arrived in a Persian sentence with Western numerals, which is the
  /// typographic equivalent of switching alphabet mid-word. The date formatter
  /// had been patching this one string at a time; this does it for any of them.
  static String localizeDigits(String text, AppLanguage language) {
    if (language != AppLanguage.fa) return text;
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        buffer.write(_persianDigits[rune - 0x30]);
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Formats [value] in the digits used by [language].
  static String format(int value, AppLanguage language) {
    final digits = value.abs().toString();
    final sign = value < 0 ? '-' : '';
    if (language != AppLanguage.fa) return '$sign$digits';

    final buffer = StringBuffer(sign);
    for (final codeUnit in digits.codeUnits) {
      buffer.write(_persianDigits[codeUnit - 0x30]);
    }
    return buffer.toString();
  }
}
