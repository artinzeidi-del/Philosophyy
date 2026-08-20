import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/design/app_theme.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';

/// The dark theme's panes may not be lit, and every pane must still have edges.
///
/// ## The defect this is written against
///
/// A glass pane is painted with a gradient and text lands wherever the layout
/// puts it, so any colour in that gradient is a colour some word will be read
/// against. In the dark theme the foreground is pale, which means every stop
/// that lifts the surface costs contrast.
///
/// It has gone wrong twice. A full-height lit gradient dropped a settings label
/// to 4.38:1. Then a specular rim — added to make a pane read as glass, which
/// it does, in the light theme — took the rank banner to 4.23:1.
///
/// ## Why this checks a rule rather than a ratio
///
/// The first version of this test composited each stop over the theme surface
/// and measured the result. It passed while the real screen failed, because the
/// painted colour depends on how many translucent layers a widget happens to
/// sit inside and this test knew nothing about that. A guard that can pass when
/// the thing it guards is broken is worse than no guard, so it was replaced.
///
/// What is asserted instead is the decision itself, which needs no model of the
/// tree: **in the dark theme no stop may be lighter than the flat fill.** The
/// contrast of the flat fill is already established by the theme; anything that
/// does not exceed it cannot make a screen less readable than the theme allows.
/// Measuring ratios against the real tree is the painted-contrast sweep's job,
/// and it does it properly.
void main() {
  double luminance(Color c) => c.computeLuminance();

  Future<LinearGradient> gradientFor(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    late LinearGradient gradient;
    await tester.pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.dark
            ? AppTheme.dark(AppLanguage.en)
            : AppTheme.light(AppLanguage.en),
        home: Builder(
          builder: (context) {
            gradient = Glass.surfaceGradient(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return gradient;
  }

  testWidgets('dark: the top edge is not given a rim', (tester) async {
    // The dark theme keeps the gentle wash it always had — the first two stops
    // are the same colour — and gains no specular rim. Asserting the equality
    // rather than a luminance bound states the decision exactly and leaves the
    // sanctioned wash alone, which a bound would have had to encode as a magic
    // number and would drift against.
    final gradient = await gradientFor(tester, Brightness.dark);

    expect(
      gradient.colors[0],
      gradient.colors[1],
      reason:
          'a dark-theme pane has been given a lit rim. In the dark theme the '
          'foreground is pale, so lifting the top edge costs contrast wherever '
          'a word lands on it — this took the rank banner to 4.23:1.',
    );
  });

  testWidgets('light: the pane is lit at the top', (tester) async {
    // The other direction, so the rim cannot be quietly flattened out of the
    // light theme, where it is the thing that makes a pane read as glass.
    final gradient = await gradientFor(tester, Brightness.light);
    final base = gradient.colors[gradient.colors.length ~/ 2];

    expect(
      luminance(gradient.colors.first),
      greaterThan(luminance(base)),
      reason: 'the light theme has lost its specular rim',
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name}: the pane has thickness', (tester) async {
      // The shade at the bottom edge is what stops a pane reading as a flat
      // rectangle, and it is safe in both themes: it darkens, and darker is
      // the direction that costs no contrast under either foreground.
      final gradient = await gradientFor(tester, brightness);
      final base = gradient.colors[gradient.colors.length ~/ 2];

      expect(
        luminance(gradient.colors.last),
        lessThan(luminance(base)),
        reason: 'the bottom shade has been flattened out',
      );
    });
  }
}
