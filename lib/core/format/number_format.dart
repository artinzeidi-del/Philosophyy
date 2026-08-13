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
