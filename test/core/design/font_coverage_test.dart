import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Proves every character the content can print has a glyph in a bundled font.
///
/// ## Why this exists
///
/// Nine of the bundled faces exist to print names in their own script and
/// nothing else, and they were shipping whole: seven megabytes of CJK for
/// content that uses eighty-six ideographs, and 1,085 hieroglyphs to draw four.
/// `tool/subset_fonts.py` cuts them down to what the content actually uses.
///
/// That trade is only safe if something notices when the content grows past the
/// subset. Nothing in Flutter does — a missing glyph is not an error, it is an
/// empty box in the middle of somebody's name, and it looks exactly like a
/// rendering quirk. So this reads every character in `assets/content` and every
/// UI string, and fails if no bundled face can draw one.
///
/// Adding a Korean philosopher without re-running the subsetter fails here,
/// which is the whole point.
void main() {
  test('every character the content can print has a glyph', () {
    final characters = _contentCharacters();
    final covered = _coveredByBundledFonts();

    final missing = characters.where((rune) => !covered.contains(rune)).toList()
      ..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'no bundled font has a glyph for '
          '${missing.map(_describe).join(', ')}.\n'
          'If this arrived with new content, run: '
          'python3 tool/subset_fonts.py',
    );
  });

  test('the subsets are actually subsets', () {
    // Guards the other direction: if someone restores a full font, the saving
    // is silently gone and nothing says so. These are name-printing faces; none
    // of them has any business being large.
    const budgetKb = 200;
    final oversized = <String>[];

    for (final directory in _scriptOnlyFamilies) {
      final dir = Directory('assets/fonts/$directory');
      if (!dir.existsSync()) continue;
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.ttf')) continue;
        final kb = file.lengthSync() / 1024;
        if (kb > budgetKb) {
          oversized.add('${file.path} is ${kb.toStringAsFixed(0)} KB');
        }
      }
    }

    expect(
      oversized,
      isEmpty,
      reason:
          'these faces only ever print names and should be subset to the '
          'characters the content uses:\n  ${oversized.join('\n  ')}',
    );
  });
}

/// The families bundled only to print names in their own script.
const _scriptOnlyFamilies = <String>[
  'notoserifcjk',
  'notoserifdevanagari',
  'notoserifbengali',
  'notoserifhebrew',
  'notoserifethiopic',
  'notoseriftibetan',
  'notosansegyptianhieroglyphs',
];

/// Every character the shipped content and the interface strings can display.
Set<int> _contentCharacters() {
  final found = <int>{};

  void walk(Object? node) {
    if (node is String) {
      found.addAll(node.runes);
    } else if (node is Map) {
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  for (final dir in <String>['assets/content', 'lib/l10n']) {
    for (final file in Directory(dir).listSync().whereType<File>()) {
      if (!file.path.endsWith('.json') && !file.path.endsWith('.arb')) continue;
      walk(jsonDecode(file.readAsStringSync()));
    }
  }

  // Control characters are not drawn and have no glyph anywhere.
  found.removeWhere((rune) => rune < 0x20 || (rune >= 0x7F && rune <= 0x9F));
  return found;
}

/// Every codepoint any bundled font can draw.
Set<int> _coveredByBundledFonts() {
  final covered = <int>{};
  for (final entry in Directory('assets/fonts').listSync(recursive: true)) {
    if (entry is! File || !entry.path.endsWith('.ttf')) continue;
    covered.addAll(_cmapOf(entry.readAsBytesSync()));
  }
  // Material's icon font is not in assets/ and supplies the glyphs in the
  // private-use area that `IconData` refers to.
  covered.addAll(
    Iterable<int>.generate(0xF8FF - 0xE000 + 1, (i) => 0xE000 + i),
  );
  covered.addAll(
    Iterable<int>.generate(0xFFFFF - 0xF0000 + 1, (i) => 0xF0000 + i),
  );
  return covered;
}

String _describe(int rune) =>
    'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')} '
    '(${String.fromCharCode(rune)})';

/// The codepoints a TrueType file maps to a real glyph.
///
/// Only the two subtable formats that matter are read: format 4, which every
/// font carries for the basic plane, and format 12, which is what a font needs
/// for anything above it — the hieroglyphs live at U+13000 and are invisible to
/// a reader that only understands format 4.
Set<int> _cmapOf(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final covered = <int>{};

  final tableCount = data.getUint16(4);
  var cmapOffset = -1;
  for (var i = 0; i < tableCount; i++) {
    final record = 12 + i * 16;
    final tag = String.fromCharCodes(bytes.sublist(record, record + 4));
    if (tag == 'cmap') {
      cmapOffset = data.getUint32(record + 8);
      break;
    }
  }
  if (cmapOffset < 0) return covered;

  final subtableCount = data.getUint16(cmapOffset + 2);
  for (var i = 0; i < subtableCount; i++) {
    final record = cmapOffset + 4 + i * 8;
    final subtable = cmapOffset + data.getUint32(record + 4);
    switch (data.getUint16(subtable)) {
      case 4:
        _readFormat4(data, subtable, covered);
      case 12:
        _readFormat12(data, subtable, covered);
    }
  }
  return covered;
}

void _readFormat4(ByteData data, int start, Set<int> covered) {
  final segments = data.getUint16(start + 6) ~/ 2;
  final endCodes = start + 14;
  final startCodes = endCodes + segments * 2 + 2;
  final idDeltas = startCodes + segments * 2;
  final idRangeOffsets = idDeltas + segments * 2;

  for (var s = 0; s < segments; s++) {
    final end = data.getUint16(endCodes + s * 2);
    final begin = data.getUint16(startCodes + s * 2);
    if (begin > end || begin == 0xFFFF) continue;
    final delta = data.getInt16(idDeltas + s * 2);
    final rangeOffset = data.getUint16(idRangeOffsets + s * 2);

    for (var code = begin; code <= end && code != 0xFFFF; code++) {
      int glyph;
      if (rangeOffset == 0) {
        glyph = (code + delta) & 0xFFFF;
      } else {
        // The offset is measured from the idRangeOffset entry itself, which is
        // the one piece of this format that cannot be read literally.
        final index = idRangeOffsets + s * 2 + rangeOffset + (code - begin) * 2;
        if (index + 1 >= data.lengthInBytes) continue;
        glyph = data.getUint16(index);
        if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
      }
      // Glyph 0 is .notdef — the empty box. A font that maps a character to it
      // cannot draw that character, which is exactly what this test is about.
      if (glyph != 0) covered.add(code);
    }
  }
}

void _readFormat12(ByteData data, int start, Set<int> covered) {
  final groups = data.getUint32(start + 12);
  for (var g = 0; g < groups; g++) {
    final record = start + 16 + g * 12;
    final begin = data.getUint32(record);
    final end = data.getUint32(record + 4);
    final firstGlyph = data.getUint32(record + 8);
    if (firstGlyph == 0) continue;
    for (var code = begin; code <= end; code++) {
      covered.add(code);
    }
  }
}
