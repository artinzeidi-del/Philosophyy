import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks on the test suite itself.
///
/// A test that cannot fail is worse than no test: it reports a guarantee the
/// code does not have, and it goes on reporting it while the defect it was
/// written for walks past. These catch the ways an assertion here has actually
/// gone quiet.
void main() {
  final dartFiles = Directory('test')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('a raw string does not escape the dollar it means to anchor with', () {
    // Found the hard way. The guard on quotations given in their original
    // script used `r'^[...]+\$'`, and in a raw Dart string the backslash is
    // literal — so the pattern demanded a dollar sign at the end of the text
    // and matched nothing. The test passed over the two defects it had just
    // been written to catch, and only planting one back showed it.
    //
    // Raw strings do not interpolate, so `$` in one never needs escaping.
    // A `\$` inside one is always either a dead anchor or a dead group
    // reference.
    final offenders = <String>[];
    final rawString = RegExp(r"""r(['"])(?:(?!\1).)*\1""");
    final escapedDollar = String.fromCharCodes(<int>[0x5C, 0x24]);
    for (final file in dartFiles) {
      // This file is the one that names the pattern, in its own comment and
      // in the literal it looks for, so it cannot be its own subject.
      if (file.path.endsWith('suite_hygiene_test.dart')) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        for (final match in rawString.allMatches(lines[i])) {
          if (match.group(0)!.contains(escapedDollar)) {
            offenders.add('${file.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'a raw string escapes a dollar, which makes it literal:\n'
          '${offenders.join("\n")}',
    );
  });

  test('every test file holds at least one expectation', () {
    // A file of setup with nothing asserted is a file that cannot fail.
    final silent = <String>[];
    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      if (!source.contains('void main()')) continue;
      if (!source.contains('expect(') && !source.contains('expectLater(')) {
        silent.add(file.path);
      }
    }
    expect(silent, isEmpty, reason: 'no expectation in:\n${silent.join("\n")}');
  });
}
