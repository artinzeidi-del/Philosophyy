import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the design system the only place design decisions are made.
///
/// ## Why a test rather than a convention
///
/// A design system holds for exactly as long as nobody is in a hurry. Every
/// colour, radius and duration in this app is meant to come from
/// `lib/core/design`, and the way that stops being true is never a decision —
/// it is one screen, once, with a literal that looked close enough. By the time
/// it is visible the palette has three near-identical greys in it and no way to
/// change them together.
///
/// So the rule is checked instead of stated. These are cheap greps, and they
/// have already caught the one real drift: the floating navigation bar carried
/// its own near-black and its own idle grey, both of them genuine palette
/// decisions living outside the palette.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  /// The design layer is where literals are allowed — it is what defines them.
  bool isDesignLayer(File file) =>
      file.path.startsWith('lib/core/design/') ||
      file.path.startsWith('lib/l10n/generated/');

  List<String> offences(RegExp pattern, {bool Function(String line)? allow}) {
    final found = <String>[];
    for (final file in dartFiles) {
      if (isDesignLayer(file)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (!pattern.hasMatch(line)) continue;
        if (allow != null && allow(line)) continue;
        found.add('${file.path}:${i + 1}  ${line.trim()}');
      }
    }
    return found;
  }

  test('no screen mixes its own colour', () {
    final found = offences(RegExp(r'Color\(0x'));
    expect(
      found,
      isEmpty,
      reason:
          'these belong in lib/core/design/color_tokens.dart, where they can '
          'be changed once and checked for contrast:\n  ${found.join('\n  ')}',
    );
  });

  test('no screen reaches for a Material palette colour', () {
    final found = offences(
      RegExp(r'\bColors\.[a-z]'),
      // `transparent`, and white or black at an explicit alpha, are structural
      // rather than palette choices: a scrim, an ink layer, a hairline over an
      // arbitrary background. They belong to no theme and mean the same in
      // both.
      allow: (line) =>
          line.contains('Colors.transparent') ||
          line.contains('Colors.white.withValues') ||
          line.contains('Colors.black.withValues'),
    );
    expect(
      found,
      isEmpty,
      reason:
          'Material\'s stock palette is not this product\'s palette:\n  '
          '${found.join('\n  ')}',
    );
  });

  test('no screen invents its own animation timing', () {
    final found = offences(
      RegExp(r'Duration\((milliseconds|seconds):'),
      // A named constant at the top of a file is a considered decision with a
      // place to write down why. An inline literal inside a widget is not.
      allow: (line) => line.contains('static const'),
    );
    expect(
      found,
      isEmpty,
      reason:
          'timings come from MotionTokens so that "reduce motion" can turn '
          'them all off at once:\n  ${found.join('\n  ')}',
    );
  });

  test('no screen hardcodes a corner radius', () {
    final found = offences(RegExp(r'Radius\.circular\(\s*\d'));
    expect(
      found,
      isEmpty,
      reason:
          'radii come from Radii, so the product has one shape language:\n  '
          '${found.join('\n  ')}',
    );
  });
}
