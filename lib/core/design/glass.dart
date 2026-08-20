import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';

/// Translucent panels and the glow that marks what is live.
///
/// ## What "glass" means here, and what it does not
///
/// It does not mean a backdrop blur. A real blur on every panel costs more
/// than the rest of the frame on a mid-range phone, and the effect the design
/// actually depends on is cheaper than that: a translucent fill so the canvas
/// shows through, a hairline border a shade lighter than the fill, and a
/// single highlight along the top edge where the light is coming from. That
/// combination is what makes a panel look like a pane laid on the background
/// rather than a rectangle painted onto it.
///
/// ## What the glow is for
///
/// In the reference this is drawn from, colour and glow mean *live*: the
/// primary action glows, the active tab glows, the toast glows in the colour
/// of what it is telling you. Nothing inert glows. That is the rule here too,
/// and it is worth stating because a glow applied to everything is just a
/// blurry interface — the effect only carries meaning while it stays scarce.
abstract final class Glass {
  /// How much of the canvas shows through a panel.
  static double fillOpacity(Brightness brightness) =>
      brightness == Brightness.dark ? 0.62 : 0.78;

  /// How far a light-theme panel is lifted toward white.
  ///
  /// ## Why a panel has to be lighter than the page
  ///
  /// It was `surfaceContainer`, which in this palette is a shade *darker* than
  /// the blush canvas: `#F3E7E1` on `#FBF2ED`. Measured off a screenshot the
  /// browse list came out at 1.04:1 against its own background — a card was
  /// distinguishable from the page only by its hairline, and the whole screen
  /// read as flat.
  ///
  /// Darker is also the wrong direction, and that is the part worth stating.
  /// Glass scatters light back toward whoever is looking at it, so a pane is
  /// always brighter and less saturated than what lies behind it. A surface
  /// darker than its ground reads as a hole cut in the page; no amount of edge
  /// lighting fixes that, because the eye settles the figure-ground question
  /// before it looks at any edge.
  ///
  /// So a light-theme panel is mixed toward white instead. It gains separation
  /// from the canvas, it loses a little of the canvas's warmth exactly as real
  /// frosted glass does, and every word on it gains contrast rather than
  /// losing it.
  ///
  /// The dark theme already had this right — `#1B2A32` on `#121E24` is lighter
  /// than its ground — so it is left alone.
  static const double _lightLift = 0.62;

  /// The fill for a glass panel in the current theme.
  static Color fill(BuildContext context, {Color? tint}) {
    final scheme = Theme.of(context).colorScheme;
    final base = tint ?? scheme.surfaceContainer;
    final lifted = scheme.brightness == Brightness.dark
        ? base
        : Color.lerp(base, Colors.white, _lightLift)!;
    return lifted.withValues(alpha: fillOpacity(scheme.brightness));
  }

  /// The hairline that defines a panel's edge.
  ///
  /// A shade of the foreground rather than of the outline token: on a
  /// translucent fill the border has to be visible against whatever the canvas
  /// happens to be behind it, and the outline token is tuned against the
  /// opaque surface.
  static Color border(BuildContext context, {double strength = 1}) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.onSurface.withValues(
      alpha: (scheme.brightness == Brightness.dark ? 0.14 : 0.10) * strength,
    );
  }

  /// The highlight along a panel's top edge, where the canvas light is.
  static Color topHighlight(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.onSurface.withValues(
      alpha: scheme.brightness == Brightness.dark ? 0.10 : 0.06,
    );
  }

  /// The fill for a glass surface, as a lit gradient rather than a flat colour.
  ///
  /// ## Why the flat fill was not enough
  ///
  /// [fill] gives a panel the right colour and, on a canvas the same hue as the
  /// panel, almost nothing else: on a phone a list of cards came out as
  /// rectangles a shade darker than the page. Nothing was wrong with the
  /// translucency — there was simply nothing behind it worth seeing through to,
  /// and a pane with no light on it does not read as a pane.
  ///
  /// A pane is legible because its top edge catches the light. A gradient costs
  /// one; a backdrop blur costs a frame.
  ///
  /// ## Why the light stops a third of the way down
  ///
  /// The first version ran the whole height, and in the dark theme that lifted
  /// the panel from `#46464a` to `#4c4c4f` — enough to drop a settings label
  /// from 4.50:1 to 4.38:1 and fail the painted-contrast sweep. A lit edge is
  /// an edge: past the top of a panel there is nothing left to light, and
  /// running the gradient on merely repaints the surface a lighter colour under
  /// every word on it.
  ///
  /// The dark theme takes a sixth of the light the light theme does, for the
  /// same reason: text on dark is light, so anything that lifts the surface
  /// costs contrast, while on a pale surface it costs nothing.
  ///
  /// ## The rim and the shade
  ///
  /// Everything above got a pane that was lit and still read as a rectangle: a
  /// screenshot of the browse list came out as a column of faintly tinted
  /// boxes. What was missing is what actually makes glass legible, and it is
  /// visible in any reference photograph of the material — a **specular rim**,
  /// a bright hairline where the top edge turns and catches the light, and a
  /// **shade** at the bottom where the pane's own thickness darkens what shows
  /// through. The soft lit third supplies neither: it is a wash, and a wash has
  /// no edge.
  ///
  /// Both are folded into this one gradient rather than added as extra layers,
  /// so every surface already calling it is fixed at once and nothing pays for
  /// another paint. The rim occupies the top 1.8% of a panel and the shade the
  /// bottom 4%; card padding is [Spacing.lg], so on any panel large enough to
  /// hold a word, no text ever sits on either band. That is what makes this
  /// safe where the full-height version was not.
  static LinearGradient surfaceGradient(BuildContext context, {Color? tint}) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final base = fill(context, tint: tint);

    // White in the light theme; the foreground in the dark one, where white
    // blows out into a grey haze instead of reading as a lit edge. Mixed at the
    // base's own opacity so the pane does not become more solid at the top than
    // at the bottom.
    final light = (dark ? scheme.onSurface : Colors.white).withValues(
      alpha: base.a,
    );
    final dim = Color.lerp(base, Colors.black.withValues(alpha: base.a), 0.06)!;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const <double>[0, 0.018, 0.34, 0.96, 1],
      colors: <Color>[
        // The rim. Much brighter than the wash below it, and thin enough that
        // it reads as an edge rather than as the panel being a lighter colour.
        //
        // Light theme only. A bright rim in the dark theme is the same mistake
        // the full-height gradient made — the painted-contrast sweep reads
        // every colour in a gradient as a possible background for the text on
        // it, and rightly, since nothing here knows where the words will land.
        // A rim lifted toward the foreground took the rank banner to 4.23:1.
        //
        // Dark glass does not want it anyway. A pane on a near-black ground is
        // read by its border, not by a highlight: there is no bright room above
        // the surface to catch. So the dark theme keeps the wash it had, and
        // the shade below still gives it the thickness.
        Color.lerp(base, light, dark ? 0.05 : 0.85)!,
        Color.lerp(base, light, dark ? 0.05 : 0.30)!,
        base,
        base,
        // The shade: the pane's own thickness, seen through the bottom edge.
        dim,
      ],
    );
  }

  /// The shadow that lifts a surface off the page.
  ///
  /// ## Why two shadows
  ///
  /// One shadow is a drop shadow and looks stuck on. Real objects cast two: a
  /// tight, darker one where they meet the surface, and a wide, faint one from
  /// the light in the room. The pair is what reads as an object resting on
  /// something rather than a rectangle with a grey edge.
  ///
  /// Kept deliberately light. On a near-black canvas a black shadow is
  /// invisible and a lighter one reads as a smudge, so in the dark theme the
  /// contact shadow does nearly all the work and the ambient one is faint.
  ///
  /// ## Why the light theme leans on this harder than it looks like it should
  ///
  /// The blush canvas is `#FBF2ED` — within a whisker of white. A panel lighter
  /// than that canvas tops out at 1.06:1 against it even if it is pure white,
  /// so on this palette **luminance cannot separate a card from the page**.
  /// Measured off a screenshot, the browse list sits at 1.02:1.
  ///
  /// That is not a reason to darken the panels — a surface darker than its
  /// ground reads as a hole, see [_lightLift]. It is the reason the shadow has
  /// to do the separating instead, which is exactly what a photograph of white
  /// objects on a white table shows: the edge you see is the shadow. The light
  /// values here were raised until the cards read as resting on the page rather
  /// than printed into it.
  static List<BoxShadow> lift(BuildContext context, {double strength = 1}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: (dark ? 0.30 : 0.08) * strength),
        blurRadius: 8 * strength,
        offset: Offset(0, 2 * strength),
        spreadRadius: -1,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: (dark ? 0.16 : 0.07) * strength),
        blurRadius: 28 * strength,
        offset: Offset(0, 10 * strength),
        spreadRadius: -6,
      ),
    ];
  }

  /// The surface that marks the one thing currently selected.
  ///
  /// A sweep running from almost nothing to the accent at its trailing edge,
  /// over a bloom in the same colour, inside a hairline. A flat tint reads as
  /// a button; a sweep brighter at one end reads as lit, which is what makes
  /// the current destination look current rather than merely filled.
  ///
  /// It lives here because it was written twice. The floating bar had the lit
  /// sweep and the desktop rail had a flat `secondaryContainer` fill, so the
  /// same product said "you are here" two different ways depending on the
  /// width of the window. One decoration, two callers, and no way for them to
  /// drift again.
  ///
  /// The bright end stops short of full strength on purpose: Persian mirrors
  /// the row, so a label cannot be relied on to fall at the dark end, and a
  /// label legible only because of where it happens to sit is not legible.
  /// The bloom outside the shape supplies the brightness the fill gives up.
  static BoxDecoration active(
    Color colour, {
    required BorderRadius radius,
    double strength = 1,
  }) => BoxDecoration(
    borderRadius: radius,
    gradient: LinearGradient(
      begin: AlignmentDirectional.centerStart,
      end: AlignmentDirectional.centerEnd,
      stops: const <double>[0, 0.8, 1],
      colors: <Color>[
        colour.withValues(alpha: 0.16 * strength),
        colour.withValues(alpha: 0.30 * strength),
        colour.withValues(alpha: 0.38 * strength),
      ],
    ),
    border: Border.all(color: colour.withValues(alpha: 0.32 * strength)),
    boxShadow: glow(colour, strength: 0.55 * strength),
  );

  /// A coloured bloom, for something that is live.
  ///
  /// Two shadows rather than one: a tight, brighter core and a wide, faint
  /// halo. A single blur reads as a drop shadow that happens to be coloured;
  /// the pair reads as light coming off the object.
  static List<BoxShadow> glow(Color colour, {double strength = 1}) =>
      <BoxShadow>[
        BoxShadow(
          color: colour.withValues(alpha: 0.34 * strength),
          blurRadius: 12 * strength,
          spreadRadius: -2,
        ),
        BoxShadow(
          color: colour.withValues(alpha: 0.18 * strength),
          blurRadius: 30 * strength,
          spreadRadius: 2,
        ),
      ];
}

/// A translucent panel with a hairline edge and a lit top.
///
/// The building block every grouped surface in the product is made of. It
/// takes its own padding so that the border and the content cannot drift apart
/// as callers each choose their own.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.borderRadius = Radii.surfaceRadius,
    this.tint,
    this.glowColour,
    this.glowStrength = 1,
    this.borderStrength = 1,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  /// Overrides the fill's base colour, before its translucency is applied.
  final Color? tint;

  /// When set, the panel is treated as live and blooms in this colour.
  final Color? glowColour;

  final double glowStrength;

  /// Scales the hairline. Nested panels use less of it, so an edge inside an
  /// edge does not read as a double rule.
  final double borderStrength;

  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final glow = glowColour;

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: Glass.surfaceGradient(context, tint: tint),
        borderRadius: borderRadius,
        border: Border.all(
          color: Glass.border(context, strength: borderStrength),
        ),
        // A live panel blooms; an inert one is merely lifted. Both at once and
        // the bloom reads as a shadow with a colour cast.
        boxShadow: glow == null
            ? Glass.lift(context)
            : Glass.glow(glow, strength: glowStrength),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          // The lit top edge: a very short gradient, not a second border, so
          // it reads as the panel catching the light rather than as a stripe.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const <double>[0, 0.18],
              colors: <Color>[
                Glass.topHighlight(context),
                Glass.topHighlight(context).withValues(alpha: 0),
              ],
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap == null) {
      return semanticLabel == null
          ? panel
          : Semantics(label: semanticLabel, child: panel);
    }
    return PressableSurface(
      onTap: onTap,
      borderRadius: borderRadius,
      semanticLabel: semanticLabel,
      child: panel,
    );
  }
}

/// Wraps a child in a bloom that breathes.
///
/// Used on the one thing on a screen that is asking to be acted on. The pulse
/// runs three times when the screen arrives and then rests at full glow. It is
/// bounded on purpose: an indefinite pulse is motion in the periphery of a
/// page somebody is reading, and it also never lets the interface come to
/// rest, so every widget test that waits for that waits forever.
///
/// Under reduced motion the glow sits at its resting value from the first
/// frame rather than disappearing — the glow carries the meaning, the movement
/// only draws the eye to it.
class PulsingGlow extends StatefulWidget {
  const PulsingGlow({
    required this.child,
    required this.colour,
    this.borderRadius = Radii.cardRadius,
    this.strength = 1,
    super.key,
  });

  final Widget child;
  final Color colour;
  final BorderRadius borderRadius;
  final double strength;

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  /// Three there-and-back passes, then rest.
  static const int _passes = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionTokens.pulse * _passes,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.isReduced(context)) {
      _controller.value = 1;
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  /// The glow's strength at the controller's current position: a decaying
  /// wave that finishes at rest rather than stopping wherever it happens to
  /// be when the last pass ends.
  double get _wave {
    final t = _controller.value;
    final swing = (1 - t) * 0.22;
    final phase = t * _passes * 2 * math.pi;
    return 1 - swing * (1 - math.cos(phase)) / 2;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        boxShadow: Glass.glow(widget.colour, strength: widget.strength * _wave),
      ),
      child: child,
    ),
  );
}
