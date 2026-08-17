import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:philosophyy/core/design/contrast.dart';
import 'package:philosophyy/core/design/decorative.dart';

/// Measures the contrast of text as it is actually painted.
///
/// ## Why this exists
///
/// `contrast_test.dart` checks the pairs the *palette* declares, and it has
/// never been wrong about them. Two screens still shipped unreadable, and both
/// escaped for the same reason: the surface underneath the text was not a
/// palette pair. Settings drew its labels in a colour the theme forgot to name,
/// so they came out black on the dark surface; an article's title was drawn in
/// `onSurface` over a masthead the screen painted itself.
///
/// Neither is a palette error. Both are visible in a screenshot and invisible
/// to any test that reasons about tokens, because the failure is in the
/// *pairing* a particular screen happens to produce. So this walks the real
/// render tree of a real screen, finds every piece of text, works out what is
/// painted behind it, and measures what a reader would actually see.
///
/// ## What it can and cannot resolve
///
/// It composites the fills it finds on the ancestors of each paragraph — solid
/// colours, gradients, and the `Material` layers underneath them — from the
/// nearest outward until they are opaque. Where a gradient is involved it
/// measures against the *worst* of its stops, because text has to survive the
/// whole sweep and not just its midpoint.
///
/// It cannot resolve text over an image, over a shader, or over a background
/// that never becomes opaque before the root. Those are reported as skipped
/// rather than passed: a check that quietly measures nothing is worse than no
/// check, so callers assert on the number it managed to resolve.
class PaintedContrast {
  const PaintedContrast._(this.findings, this.skipped);

  /// One entry per resolvable piece of text.
  final List<PaintedText> findings;

  /// How many paragraphs could not be resolved to an opaque background.
  final int skipped;

  /// Measures every paragraph currently on screen.
  static PaintedContrast measure(WidgetTester tester) {
    final findings = <PaintedText>[];
    var skipped = 0;

    for (final element in find.byType(RichText).evaluate()) {
      final render = element.renderObject;
      if (render is! RenderParagraph) continue;

      // Ornament is exempt from the contrast requirement, but only the app can
      // say what is ornament — see `Decorative`. Inferring it from
      // `ExcludeSemantics` was wrong twice: Flutter's `Icon` wraps every glyph
      // in one, so this measured no icons at all, and the navigation bar
      // excludes its label only to stop a screen reader saying the destination
      // twice.
      if (_isDecorative(element)) continue;
      if (render.text case final TextSpan span) {
        final text = span.toPlainText(
          includeSemanticsLabels: false,
          includePlaceholders: false,
        );
        if (text.trim().isEmpty) continue;

        final colour = span.style?.color;
        if (colour == null || colour.a == 0) {
          skipped++;
          continue;
        }

        final backgrounds = _backgroundsBehind(render);
        if (backgrounds.isEmpty) {
          skipped++;
          continue;
        }

        // An icon is drawn as a glyph, so it arrives here looking exactly like
        // a one-character paragraph. WCAG holds it to the non-text bar of 3:1
        // rather than the 4.5:1 body text has to clear, and measuring it as
        // text would fail every screen for something that is not wrong.
        final isIcon = _iconFamilies.contains(span.style?.fontFamily);

        // The style's own size decides which bar applies to real text: WCAG
        // lets large text sit at 3:1, and a display heading is easier to read.
        final size = span.style?.fontSize ?? 14;
        final bold = (span.style?.fontWeight?.value ?? 400) >= 700;
        final large = isIcon || size >= 24 || (size >= 18.66 && bold);

        for (final background in backgrounds) {
          findings.add(
            PaintedText(
              text: text.length > 48 ? '${text.substring(0, 48)}…' : text,
              foreground: colour,
              background: background,
              largeText: large,
            ),
          );
        }
      }
    }

    return PaintedContrast._(findings, skipped);
  }

  /// Every finding that fails its WCAG AA bar.
  List<PaintedText> get failures =>
      findings.where((finding) => !finding.passes).toList();

  /// The colours that could be painted behind [render].
  ///
  /// A list rather than one colour, because a gradient behind the text is
  /// several backgrounds at once and the text has to clear all of them.
  ///
  /// The paints are collected outward until one of them is fully opaque, then
  /// folded back toward the text: each paint's stops are composited onto every
  /// candidate the paints behind it produced. Folding is what makes the answer
  /// right, and two earlier versions got it wrong in opposite directions.
  ///
  /// One composited each layer onto the layer immediately behind it. The app's
  /// washes fade to their own hue at zero alpha rather than to transparent
  /// black, so that returned the hue at full strength — a background never on
  /// screen — and reported every screen as failing.
  ///
  /// The next reported the opaque ground *and* each wash over it as separate
  /// candidates. That is right for a gradient, where different points really
  /// do show different stops, and wrong for a stack: the navigation bar is a
  /// near-opaque black over the page, and listing the page as a candidate
  /// failed a white label against paper it is nowhere near.
  static List<Color> _backgroundsBehind(RenderObject render) {
    // Nearest first.
    final paints = <List<Color>>[];

    RenderObject? node = render.parent;
    while (node != null) {
      final fills = _fillsOf(node).where((colour) => colour.a > 0).toList();
      if (fills.isNotEmpty) {
        paints.add(fills);
        if (fills.every((colour) => colour.a >= 1.0)) break;
      }
      node = node.parent;
    }

    if (paints.isEmpty) return const <Color>[];
    if (!paints.last.every((colour) => colour.a >= 1.0)) {
      // Nothing opaque was found before the root, so what a reader sees here
      // depends on something this cannot resolve.
      return const <Color>[];
    }

    var candidates = paints.last;
    for (final paint in paints.reversed.skip(1)) {
      final folded = <Color>{};
      for (final stop in paint) {
        for (final behind in candidates) {
          folded.add(Contrast.composite(stop, behind));
        }
      }
      candidates = folded.toList();
    }
    return candidates;
  }

  /// Whether [element] sits inside a [Decorative].
  static bool _isDecorative(Element element) {
    var decorative = false;
    element.visitAncestorElements((ancestor) {
      if (ancestor.widget is Decorative) {
        decorative = true;
        return false;
      }
      return true;
    });
    return decorative;
  }

  /// Font families whose glyphs are icons rather than words.
  static const Set<String> _iconFamilies = <String>{
    'MaterialIcons',
    'CupertinoIcons',
  };

  /// The colours [node] paints, if it paints any.
  static List<Color> _fillsOf(RenderObject node) {
    if (node is RenderDecoratedBox) {
      final decoration = node.decoration;
      if (decoration is BoxDecoration) {
        final gradient = decoration.gradient;
        if (gradient is LinearGradient) return gradient.colors;
        if (gradient is RadialGradient) return gradient.colors;
        final colour = decoration.color;
        if (colour != null && colour.a > 0) return <Color>[colour];
      }
      return const <Color>[];
    }
    if (node is RenderPhysicalModel) {
      return node.color.a > 0 ? <Color>[node.color] : const <Color>[];
    }
    if (node is RenderPhysicalShape) {
      return node.color.a > 0 ? <Color>[node.color] : const <Color>[];
    }
    return const <Color>[];
  }
}

/// One measured piece of text.
class PaintedText {
  const PaintedText({
    required this.text,
    required this.foreground,
    required this.background,
    required this.largeText,
  });

  final String text;
  final Color foreground;
  final Color background;
  final bool largeText;

  /// What a reader sees, once translucency is flattened.
  double get ratio =>
      Contrast.ratio(Contrast.composite(foreground, background), background);

  double get required =>
      largeText ? Contrast.aaLargeText : Contrast.aaNormalText;

  bool get passes => ratio >= required;

  @override
  String toString() =>
      '"$text" is ${ratio.toStringAsFixed(2)}:1 '
      '(needs ${required.toStringAsFixed(1)}:1) — '
      '${_hex(foreground)} on ${_hex(background)}';

  static String _hex(Color colour) =>
      '#${(colour.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
