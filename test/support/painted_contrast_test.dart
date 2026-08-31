import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'painted_contrast.dart';

/// The harness that measures painted contrast reports what it measured.
///
/// It shortened every paragraph to 48 characters before recording it, so that
/// failure messages stayed readable. But callers use the same record to answer
/// "did you measure this string?" — the check that stops a contrast test from
/// passing against the wrong screen. Any string longer than 48 characters
/// could not be found, so a quiz round that happened to offer a long book
/// title failed a screen that was perfectly readable. It failed on some runs
/// and not others, because the round is built from a clock-seeded shuffle.
void main() {
  const long =
      'Treatise on Demonstrations of Problems of Algebra and Balancing';

  Future<PaintedContrast> measure(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Text(text, style: const TextStyle(color: Colors.black)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return PaintedContrast.measure(tester);
  }

  testWidgets('a long paragraph is recorded whole', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final measured = await measure(tester, long);
    expect(long.length, greaterThan(48), reason: 'or this proves nothing');
    expect(
      measured.findings.map((finding) => finding.text),
      contains(long),
      reason: 'the caller cannot ask about a string the harness cut short',
    );
  });

  testWidgets('but a failure message says it short', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final measured = await measure(tester, long);
    final finding = measured.findings.firstWhere((it) => it.text == long);
    expect(finding.shortText, endsWith('…'));
    expect(finding.shortText.length, lessThan(long.length));
    expect(finding.toString(), contains(finding.shortText));
    expect(
      finding.toString(),
      isNot(contains(long)),
      reason: 'a message that prints the whole paragraph is unreadable',
    );
  });
}
