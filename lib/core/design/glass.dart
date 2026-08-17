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

  /// The fill for a glass panel in the current theme.
  static Color fill(BuildContext context, {Color? tint}) {
    final scheme = Theme.of(context).colorScheme;
    final base = tint ?? scheme.surfaceContainer;
    return base.withValues(alpha: fillOpacity(scheme.brightness));
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
        color: Glass.fill(context, tint: tint),
        borderRadius: borderRadius,
        border: Border.all(
          color: Glass.border(context, strength: borderStrength),
        ),
        boxShadow: glow == null
            ? null
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
    duration: const Duration(milliseconds: 1100 * _passes),
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
