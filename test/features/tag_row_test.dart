import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/design/app_theme.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/features/shared/entity_widgets.dart';

/// A tag is as wide as its word.
///
/// ## The defect this is written against
///
/// [TagChip] wraps its pill in a box that enforces a finger-sized tap target.
/// That box was a `Container` with an `alignment`, which is not the same thing
/// as a `Container` without one: given an alignment and bounded constraints, a
/// `Container` expands to fill them. The parent is a `Wrap`, which offers the
/// whole row, so every tappable tag took a line to itself — four one-word tags
/// running down the side of a phone that fits three across.
///
/// The whole suite passed. Nothing overflowed, nothing was unreadable, no
/// contrast changed and no semantics were lost. It was found by looking at a
/// screenshot of a concept page at 320 points.
///
/// So the property is asserted directly: a row of short tags must occupy fewer
/// lines than it has tags.
void main() {
  Future<void> pumpTags(
    WidgetTester tester,
    List<String> labels, {
    required double width,
    required bool tappable,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppLanguage.en),
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final label in labels)
                      TagChip(label: label, onTap: tappable ? () {} : null),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// How many distinct rows the tags ended up on.
  int rowCount(WidgetTester tester) => tester
      .widgetList(find.byType(TagChip))
      .toList()
      .asMap()
      .keys
      .map(
        (i) => tester.getTopLeft(find.byType(TagChip).at(i)).dy.roundToDouble(),
      )
      .toSet()
      .length;

  const tags = <String>['Ethics', 'Analytic', 'American'];

  testWidgets('tappable tags share a row when they fit', (tester) async {
    await pumpTags(tester, tags, width: 320, tappable: true);
    expect(
      rowCount(tester),
      lessThan(tags.length),
      reason:
          'every tag claimed its own line: the tap-target wrapper is '
          'expanding to the width of the row instead of the width of the pill',
    );
  });

  testWidgets('a tappable tag is no wider than the same tag inert', (
    tester,
  ) async {
    // The tightest statement of the bug. Adding an onTap must change the hit
    // area, not the footprint.
    await pumpTags(tester, tags, width: 320, tappable: false);
    final inert = <double>[
      for (var i = 0; i < tags.length; i++)
        tester.getSize(find.byType(TagChip).at(i)).width,
    ];

    await pumpTags(tester, tags, width: 320, tappable: true);
    final live = <double>[
      for (var i = 0; i < tags.length; i++)
        tester.getSize(find.byType(TagChip).at(i)).width,
    ];

    for (var i = 0; i < tags.length; i++) {
      expect(
        live[i],
        closeTo(inert[i], 1),
        reason:
            '"${tags[i]}" is ${live[i]} wide when tappable and ${inert[i]} '
            'when not',
      );
    }
  });

  testWidgets('the finger target survives', (tester) async {
    // The other half: the wrapper exists to make a 25-pixel label reachable,
    // and a fix that shrinks it back has traded one defect for another.
    await pumpTags(tester, tags, width: 320, tappable: true);
    for (var i = 0; i < tags.length; i++) {
      expect(
        tester.getSize(find.byType(TagChip).at(i)).height,
        greaterThanOrEqualTo(minimumTapTarget),
        reason: '"${tags[i]}" is too small to hit',
      );
    }
  });

  testWidgets('the same holds right to left', (tester) async {
    await pumpTags(
      tester,
      const <String>['اخلاق', 'تحلیلی', 'آمریکایی'],
      width: 320,
      tappable: true,
      direction: TextDirection.rtl,
    );
    expect(rowCount(tester), lessThan(3));
  });
}
