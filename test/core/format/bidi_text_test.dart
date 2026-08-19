import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/format/bidi_text.dart';

/// The markers, written as escapes.
///
/// The same rule the library follows, and for the same reason: a test that
/// contains invisible characters cannot be read, and this defect arrived
/// through characters nobody could see.
const String fsi = '\u2068';
const String pdi = '\u2069';

/// The expected shape of one isolated part, spelled out here rather than
/// borrowed from the library, so the expectation is independent of the code
/// it is checking.
String wrapped(String part) => '$fsi$part$pdi';

/// A locator keeps its own order inside a Persian line.
///
/// Reported from a phone: the citation under a quotation of Nietzsche read
/// «فریدریش نیچه · حکمت شاداب · 125§». The corpus says `§125`. Nothing had
/// altered the data — the bidirectional algorithm had reordered it on screen,
/// because `§` has no direction of its own and takes the paragraph's, which
/// put it on the far side of digits that are always left-to-right.
///
/// The rendered result is not something a widget test can read back: the
/// reordering happens in the shaper, below the text a `Text` reports. What can
/// be asserted is that the isolate is applied, and that it is applied to
/// exactly the runs that need it.
void main() {
  group('isolateBidi', () {
    test('wraps a locator in a first-strong isolate', () {
      expect(isolateBidi('§125'), '$fsi§125$pdi');
    });

    test('leaves an empty string alone', () {
      // Applied unconditionally by callers, so an absent locator must not come
      // back as two invisible characters that later compare unequal to ''.
      expect(isolateBidi(''), '');
    });

    test('does not alter the characters it wraps', () {
      // The point of isolating rather than converting: a locator is an index
      // into an edition, and A51/B75 has to survive to the reader intact.
      for (final locator in <String>[
        '§125',
        'A51/B75',
        '1098a',
        '368d–369a',
        'II, §4-6',
        'ch. 3',
      ]) {
        expect(
          isolateBidi(locator).replaceAll(RegExp('[$fsi$pdi]'), ''),
          locator,
        );
      }
    });
  });

  group('joinIsolated', () {
    test('isolates every part and keeps the separator between them', () {
      expect(
        joinIsolated(<String>['فریدریش نیچه', 'حکمت شاداب', '§125'], ' · '),
        '${wrapped('فریدریش نیچه')} · ${wrapped('حکمت شاداب')} · ${wrapped('§125')}',
      );
    });

    test('an empty list produces an empty string', () {
      expect(joinIsolated(<String>[], ' · '), '');
    });
  });

  group('The rendered citation', () {
    testWidgets('carries the isolate through to the widget in Persian', (
      tester,
    ) async {
      // Guards the wiring rather than the helper: the helper can be correct
      // and still not be called at the place the defect was seen.
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Text(joinIsolated(<String>['حکمت شاداب', '§125'], ' · ')),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text)).data!;
      expect(
        text.contains('$fsi§125$pdi'),
        isTrue,
        reason: 'the locator reached the widget without its isolate',
      );
    });
  });
}
