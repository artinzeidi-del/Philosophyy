import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/design/typography.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';

/// Proves the bundled faces can actually print the content that ships.
///
/// A reference work that cannot print the name of the philosopher it has an
/// article about has failed at its first job — and it fails silently, as a row
/// of empty boxes that no test written about *behaviour* would ever catch. This
/// has already happened twice here: polytonic Greek rendered as `▯πίκτητος`
/// because Spectral covers modern Greek but not Greek Extended, and 孔子
/// rendered as two boxes because nothing bundled carried a single CJK glyph.
///
/// So the fonts themselves are the thing under test. Every character in every
/// authored string is looked up in the character maps of the fonts actually
/// listed in `pubspec.yaml`, through the fallback chain the app actually uses.
void main() {
  late Map<String, Set<int>> coverage;
  late String allContent;

  setUpAll(() {
    coverage = <String, Set<int>>{
      for (final entry in _fontFiles.entries)
        entry.key: _codepointsIn(File(entry.value)),
    };
    allContent = Directory('assets/content')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .map((file) => file.readAsStringSync())
        .join('\n');
  });

  group('Bundled fonts', () {
    test('every declared font file exists and parses', () {
      for (final entry in _fontFiles.entries) {
        expect(
          File(entry.value).existsSync(),
          isTrue,
          reason: '${entry.key}: ${entry.value} is missing',
        );
        expect(
          coverage[entry.key],
          isNotEmpty,
          reason: '${entry.key}: no character map could be read',
        );
      }
    });

    test('the CJK faces carry the scripts they are bundled for', () {
      // Guards the specific mistake of wiring up a font that turns out to be
      // the wrong subset: an SC face with no hanzi, a KR face with no hangul.
      expect(coverage['NotoSerifSC'], contains('孔'.runes.first));
      expect(coverage['NotoSerifJP'], contains('あ'.runes.first));
      expect(coverage['NotoSerifJP'], contains('ア'.runes.first));
      expect(coverage['NotoSerifKR'], contains('한'.runes.first));
    });

    test('the Devanagari face carries Sanskrit', () {
      // शून्यता — a term the corpus already uses, which shipped as boxes.
      for (final character in 'शून्यता'.runes) {
        expect(coverage['NotoSerifDevanagari'], contains(character));
      }
    });

    test('the Greek face carries Greek Extended, not just modern Greek', () {
      // Ἐ — the character that shipped as an empty box in Ἐπίκτητος.
      expect(coverage['GFSDidot'], contains(0x1F18));
    });
  });

  group('Authored content', () {
    for (final language in AppLanguage.values) {
      test('renders in ${language.name} with no missing glyph', () {
        final chain = <String>[
          AppTypography.contentFamily(language),
          ...AppTypography.fallbacksFor(language),
        ];
        final missing = _uncovered(allContent, chain, coverage);
        expect(
          missing,
          isEmpty,
          reason:
              'these characters would render as empty boxes for a '
              '${language.name} reader: ${_describe(missing)}\n'
              'The fallback chain is ${chain.join(' → ')}. If the characters '
              'are CJK, re-run tool/subset_cjk_fonts.py; otherwise a face for '
              'the script needs bundling.',
        );
      });
    }

    test('interface strings render in both languages', () {
      final arb = Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.arb'))
          .map((file) => file.readAsStringSync())
          .join('\n');
      expect(arb, isNotEmpty, reason: 'no ARB files were found to check');

      for (final language in AppLanguage.values) {
        final chain = <String>[
          AppTypography.chromeFamily(language),
          ...AppTypography.fallbacksFor(language),
        ];
        expect(
          _uncovered(arb, chain, coverage),
          isEmpty,
          reason: 'interface text has no glyph in ${language.name}',
        );
      }
    });
  });
}

/// The font files as declared in `pubspec.yaml`, by family name.
///
/// Listed here rather than parsed out of the pubspec so that a family being
/// dropped from the pubspec fails this test loudly instead of quietly reducing
/// what it checks.
const Map<String, String> _fontFiles = <String, String>{
  'Spectral': 'assets/fonts/spectral/Spectral-Regular.ttf',
  'Vazirmatn': 'assets/fonts/vazirmatn/Vazirmatn-Regular.ttf',
  'GFSDidot': 'assets/fonts/gfsdidot/GFSDidot-Regular.ttf',
  'NotoSerifSC': 'assets/fonts/notoserifcjk/NotoSerifSC-Subset.ttf',
  'NotoSerifJP': 'assets/fonts/notoserifcjk/NotoSerifJP-Subset.ttf',
  'NotoSerifKR': 'assets/fonts/notoserifcjk/NotoSerifKR-Subset.ttf',
  'NotoSerifDevanagari':
      'assets/fonts/notoserifdevanagari/NotoSerifDevanagari-Regular.ttf',
};

/// Characters no test can hold a font responsible for.
///
/// Roboto is the platform chrome face and is not bundled, so its coverage
/// cannot be read from a file; ASCII is the part of it every system font has.
/// Whitespace, control characters and the ZWNJ are formatting rather than
/// glyphs — the ZWNJ in particular is central to Persian and is deliberately
/// not drawn by anything.
bool _isExempt(int codepoint) =>
    codepoint < 0x80 ||
    codepoint == 0x200C ||
    codepoint == 0x200D ||
    codepoint == 0x200E ||
    codepoint == 0x200F ||
    codepoint == 0xFEFF;

/// The characters of [text] that no font in [chain] can draw.
Set<int> _uncovered(
  String text,
  List<String> chain,
  Map<String, Set<int>> coverage,
) {
  final covered = <int>{for (final family in chain) ...?coverage[family]};
  return <int>{
    for (final codepoint in text.runes)
      if (!_isExempt(codepoint) && !covered.contains(codepoint)) codepoint,
  };
}

String _describe(Set<int> codepoints) => codepoints
    .take(20)
    .map(
      (c) =>
          'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')} '
          '(${String.fromCharCode(c)})',
    )
    .join(', ');

/// Every Unicode codepoint a font can draw, read from its `cmap` table.
///
/// A minimal `cmap` reader rather than a dependency: the alternative is either
/// trusting the font's own name, which is what let the Greek and CJK boxes
/// ship, or adding a font-parsing package for one table. Formats 4 and 12 are
/// the two that matter — 4 for the Basic Multilingual Plane and 12 for
/// everything above it.
Set<int> _codepointsIn(File file) {
  final bytes = ByteData.sublistView(file.readAsBytesSync());
  final codepoints = <int>{};

  var offset = 0;
  // A TrueType Collection wraps one or more fonts; take the first.
  if (bytes.lengthInBytes > 16 &&
      utf8.decode(
            Uint8List.sublistView(file.readAsBytesSync(), 0, 4),
            allowMalformed: true,
          ) ==
          'ttcf') {
    offset = bytes.getUint32(12);
  }

  final numTables = bytes.getUint16(offset + 4);
  var cmapOffset = -1;
  for (var i = 0; i < numTables; i++) {
    final record = offset + 12 + i * 16;
    final tag = String.fromCharCodes(<int>[
      bytes.getUint8(record),
      bytes.getUint8(record + 1),
      bytes.getUint8(record + 2),
      bytes.getUint8(record + 3),
    ]);
    if (tag == 'cmap') {
      cmapOffset = bytes.getUint32(record + 8);
      break;
    }
  }
  if (cmapOffset < 0) return codepoints;

  final numSubtables = bytes.getUint16(cmapOffset + 2);
  for (var i = 0; i < numSubtables; i++) {
    final encoding = cmapOffset + 4 + i * 8;
    final subtable = cmapOffset + bytes.getUint32(encoding + 4);
    switch (bytes.getUint16(subtable)) {
      case 4:
        final segCount = bytes.getUint16(subtable + 6) ~/ 2;
        final ends = subtable + 14;
        final starts = ends + segCount * 2 + 2;
        final deltas = starts + segCount * 2;
        final rangeOffsets = deltas + segCount * 2;
        for (var seg = 0; seg < segCount; seg++) {
          final end = bytes.getUint16(ends + seg * 2);
          final start = bytes.getUint16(starts + seg * 2);
          if (start > end || start == 0xFFFF) continue;
          final delta = bytes.getInt16(deltas + seg * 2);
          final rangeOffset = bytes.getUint16(rangeOffsets + seg * 2);
          for (var c = start; c <= end; c++) {
            final int glyph;
            if (rangeOffset == 0) {
              glyph = (c + delta) & 0xFFFF;
            } else {
              final index =
                  rangeOffsets + seg * 2 + rangeOffset + (c - start) * 2;
              if (index + 1 >= bytes.lengthInBytes) continue;
              final raw = bytes.getUint16(index);
              glyph = raw == 0 ? 0 : (raw + delta) & 0xFFFF;
            }
            if (glyph != 0) codepoints.add(c);
          }
        }
      case 12:
        final groups = bytes.getUint32(subtable + 12);
        for (var g = 0; g < groups; g++) {
          final group = subtable + 16 + g * 12;
          final start = bytes.getUint32(group);
          final end = bytes.getUint32(group + 4);
          // Whole planes would blow up the set; these fonts never declare one.
          if (end - start > 0x10000) continue;
          for (var c = start; c <= end; c++) {
            codepoints.add(c);
          }
        }
    }
  }
  return codepoints;
}
