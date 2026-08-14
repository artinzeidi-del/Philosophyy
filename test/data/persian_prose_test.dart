import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Holds the Persian text to the standard a reader actually needs.
///
/// This product is meant for anyone, not only for people who already read
/// philosophy. Persian makes that easy to get wrong in two ways, and both are
/// invisible unless something checks.
///
/// The first is orthography. A missing or misplaced zero-width non-joiner is
/// not a typo a spell-checker catches — the words still render, they just
/// render wrong, and only a Persian reader notices.
///
/// The second is register. Persian has a literary layer that is perfectly
/// correct and quietly excludes people: `برهان آورد` where `استدلال کرد` says
/// the same thing, `واپسین` where `آخرین` does. Depth belongs in what the
/// sentence claims, not in how ornate the vocabulary is.
void main() {
  /// Every string of authored **Persian** that ships, with the field it came
  /// from.
  ///
  /// Scoped by field name rather than by "does it contain Arabic-script
  /// characters", because the corpus deliberately carries Arabic — original
  /// titles, and now an `ar` translation alongside the Persian one. Arabic
  /// spelled by Persian rules would be simply wrong, so the first version of
  /// this test, which checked every Arabic-script string it could find,
  /// reported the Arabic originals as errors.
  final strings = <({String file, String path, String text})>[];

  setUpAll(() {
    void walk(Object? node, String file, String path, String? key) {
      if (node is Map<String, Object?>) {
        for (final entry in node.entries) {
          walk(entry.value, file, '$path.${entry.key}', entry.key);
        }
      } else if (node is List) {
        for (var i = 0; i < node.length; i++) {
          walk(node[i], file, '$path[$i]', key);
        }
      } else if (node is String && _isPersianField(file, key)) {
        strings.add((file: file, path: path, text: node));
      }
    }

    for (final directory in <String>['assets/content', 'lib/l10n']) {
      for (final file in Directory(directory).listSync().whereType<File>()) {
        if (!file.path.endsWith('.json') && !file.path.endsWith('.arb')) {
          continue;
        }
        walk(jsonDecode(file.readAsStringSync()), file.path, r'$', null);
      }
    }
    expect(strings, isNotEmpty, reason: 'no Persian text was found to check');
  });

  group('Orthography', () {
    test('the zero-width non-joiner is used correctly', () {
      // A doubled ZWNJ, or one adjacent to a space or a full stop, is always a
      // mistake: it does nothing there except widen the gap by a hair, so it
      // survives proofreading and misaligns the text forever.
      final problems = <String>[];
      for (final entry in strings) {
        for (final rule in const <(String, String)>[
          ('‌‌', 'two zero-width non-joiners in a row'),
          ('‌ ', 'a zero-width non-joiner before a space'),
          (' ‌', 'a zero-width non-joiner after a space'),
          ('‌.', 'a zero-width non-joiner before a full stop'),
          ('‌،', 'a zero-width non-joiner before a comma'),
        ]) {
          if (entry.text.contains(rule.$1)) {
            problems.add('${entry.file} ${entry.path}: ${rule.$2}');
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('spacing and punctuation are clean', () {
      final problems = <String>[];
      for (final entry in strings) {
        if (entry.text.contains('  ')) {
          problems.add('${entry.file} ${entry.path}: a double space');
        }
        if (RegExp('[؀-ۿ] +[،؛.]').hasMatch(entry.text)) {
          problems.add(
            '${entry.file} ${entry.path}: a space before punctuation',
          );
        }
        if (entry.text.trim() != entry.text) {
          problems.add(
            '${entry.file} ${entry.path}: leading or trailing space',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('Persian text uses Persian letters and digits', () {
      // Arabic yeh and kaf look almost identical to their Persian counterparts
      // and sort, search and line-break differently. They are correct inside a
      // name or title quoted in Arabic, which is why only running Persian prose
      // is checked here.
      final problems = <String>[];
      for (final entry in strings) {
        for (final rule in const <(String, String)>[
          ('ي', 'Arabic yeh ي instead of Persian ی'),
          ('ك', 'Arabic kaf ك instead of Persian ک'),
          ('ة', 'teh marbuta ة, which Persian writes as ه or ت'),
        ]) {
          if (entry.text.contains(rule.$1)) {
            problems.add('${entry.file} ${entry.path}: ${rule.$2}');
          }
        }
        if (RegExp('[٠-٩]').hasMatch(entry.text)) {
          problems.add(
            '${entry.file} ${entry.path}: Arabic-Indic digits ٠١٢ instead of '
            'Persian ۰۱۲',
          );
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });
  });

  group('Register', () {
    test('plain words are used where a plain word exists', () {
      // Not a ban on difficult ideas — a ban on making an ordinary idea sound
      // difficult. Each of these has an everyday synonym that means exactly the
      // same thing, and the entry is no shallower for using it.
      const literary = <String, String>{
        'برهان آورد': 'استدلال کرد',
        'برهان می‌آورد': 'استدلال می‌کند',
        'واپسین': 'آخرین',
        'می‌آغازد': 'آغاز می‌شود',
        'درمی‌گذشت': 'رد می‌شد',
        'درمی‌گذرد': 'رد می‌شود',
      };
      final problems = <String>[];
      for (final entry in strings) {
        for (final swap in literary.entries) {
          if (entry.text.contains(swap.key)) {
            problems.add(
              '${entry.file} ${entry.path}: "${swap.key}" — say '
              '"${swap.value}" instead',
            );
          }
        }
      }
      expect(problems, isEmpty, reason: problems.join('\n'));
    });

    test('a philosophical objection is always called اعتراض', () {
      // The domain model has an Objection type and the corpus reconstructs
      // arguments with named objections. Drifting between اعتراض and ایراد for
      // the same thing — which happened once, inside a single sentence — makes
      // the vocabulary of the reconstruction unreliable.
      final objections = strings.where(
        (entry) => entry.path.contains('objections'),
      );
      expect(objections, isNotEmpty);
      for (final entry in objections) {
        expect(
          entry.text.contains('ایراد'),
          isFalse,
          reason:
              '${entry.file} ${entry.path} calls an objection ایراد; the term '
              'used everywhere else is اعتراض',
        );
      }
    });
  });
}

/// Whether a leaf holds authored Persian.
///
/// In content, that is exactly the `fa` fields: `en` is English, `ar` is
/// Arabic, and `nativeName`, `originalTitle` and `transliteration` are quoted in
/// whatever language the thing is actually named in. In `app_fa.arb` every value
/// is Persian by definition.
bool _isPersianField(String file, String? key) =>
    file.endsWith('app_fa.arb') ? true : key == 'fa';
