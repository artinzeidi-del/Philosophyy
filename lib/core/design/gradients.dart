import 'package:flutter/material.dart';

/// The gradient ramp used by feature surfaces.
///
/// ## Why gradients at all
///
/// A palette applied flatly produces a screen of rectangles: correct, legible,
/// and completely inert. The product is a reference work, not a utility, and a
/// reader who opens it should feel invited rather than filed. Depth is what
/// supplies that, and it costs nothing in legibility if the text on top is
/// drawn from a single guaranteed foreground.
///
/// ## The rule these follow
///
/// Every gradient here runs between two tones of the *same* palette family and
/// ends dark enough that [onGradient] — one warm off-white — clears WCAG AA on
/// the lightest stop as well as the darkest. That is what makes the ramp safe
/// to hand to arbitrary content: a caller never has to think about whether its
/// label will disappear at one end. `test/core/design/contrast_test.dart`
/// asserts it, because a ramp that is only checked at the ends is a ramp that
/// fails in the middle.
///
/// The ramp is ordered so that consecutive items differ visibly. Categories
/// take their band from [forIndex], which means a list of them reads as a
/// deliberate sequence rather than as a colour picker emptied onto a page.
abstract final class AppGradients {
  /// The single foreground colour every gradient in this file is built to
  /// carry. Warm rather than pure white, to match the reading surfaces.
  static const Color onGradient = Color(0xFFF6F1EE);

  /// A dimmer foreground for secondary text on a gradient.
  ///
  /// It labels captions and metadata, which are set small, so it is held to
  /// the 4.5:1 body-text bar rather than the 3:1 one — and against the stops
  /// as the sheen leaves them, not as they are declared. Measured the other
  /// way it looked safe and was 2.89:1 on the hero card.
  static const Color onGradientMuted = Color(0xFFE8E1DD);

  static const List<List<Color>> _ramp = <List<Color>>[
    // Ember, banked down until it can carry the foreground.
    <Color>[Color(0xFF96351F), Color(0xFF551C12)],
    // Magenta, the hottest band, from the reference's active states.
    <Color>[Color(0xFF8A2E52), Color(0xFF4A1329)],
    // Plum, the bridge from the warm half to the cool.
    <Color>[Color(0xFF60406E), Color(0xFF321F3C)],
    // Deep sea, the cool identity.
    <Color>[Color(0xFF1F5F5A), Color(0xFF0D3230)],
    // Steel blue, cool enough to reset the eye.
    <Color>[Color(0xFF2C5673), Color(0xFF13293A)],
    // Slate, the quietest band, closest to the surfaces themselves.
    <Color>[Color(0xFF3D5460), Color(0xFF1C2C34)],
  ];

  /// How many distinct bands the ramp holds.
  static int get length => _ramp.length;

  /// The band at [index], wrapping so any list length is safe to colour.
  static LinearGradient forIndex(int index) => LinearGradient(
    colors: _ramp[index.abs() % _ramp.length],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// A stable band for [seed], so the same entity keeps the same colour
  /// wherever it appears rather than changing as a list is reordered.
  static LinearGradient forSeed(String seed) =>
      forIndex(seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit));

  /// The gradient for the one hero surface on a screen.
  ///
  /// Three stops rather than two, and it runs the long way, so a full-width
  /// card shows the whole transition instead of a corner of it.
  static const LinearGradient hero = LinearGradient(
    colors: <Color>[Color(0xFF96351F), Color(0xFF6E2A48), Color(0xFF17323C)],
    stops: <double>[0, 0.52, 1],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// The gradient behind a quotation, in the cool half of the palette.
  static const LinearGradient quotation = LinearGradient(
    colors: <Color>[Color(0xFF1F5F5A), Color(0xFF0D3230)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// The shadow a gradient surface casts.
  ///
  /// Tinted rather than grey: a neutral shadow under a coloured card reads as
  /// dirt, and the tint is what makes the card look lit rather than pasted on.
  static List<BoxShadow> shadowFor(Color tint, {bool strong = false}) =>
      <BoxShadow>[
        BoxShadow(
          color: tint.withValues(alpha: strong ? 0.34 : 0.22),
          blurRadius: strong ? 28 : 18,
          offset: Offset(0, strong ? 12 : 8),
          spreadRadius: strong ? -6 : -4,
        ),
      ];

  /// Every colour used in the ramp, for the contrast test to sweep.
  static List<Color> get allStops => <Color>[
    for (final band in _ramp) ...band,
    ...hero.colors,
    ...quotation.colors,
  ];
}

/// A gentle radial wash placed behind a gradient surface's content.
///
/// The reference this is modelled on puts a soft light source in one corner of
/// every feature card. It is the difference between a rectangle filled with a
/// gradient and a card that looks lit, and it costs one `DecoratedBox`.
class GradientSheen extends StatelessWidget {
  const GradientSheen({
    this.alignment = const Alignment(0.9, -0.9),
    this.radius = 0.9,
    this.strength = peakStrength,
    this.child,
    super.key,
  });

  /// The strongest a sheen is allowed to be, and its default.
  ///
  /// Exposed so the contrast test can measure the ramp as it is painted rather
  /// than as it is declared.
  static const double peakStrength = 0.10;

  /// Where the light falls.
  final Alignment alignment;

  /// How far it spreads, as a fraction of the box's shortest side.
  final double radius;

  /// Peak opacity at the centre of the wash.
  ///
  /// Kept low deliberately. The sheen lightens whatever is under it, and the
  /// foregrounds on a gradient are chosen against the *lightened* stop — so
  /// every point of strength here is paid for in how dark the ramp has to be.
  final double strength;

  final Widget? child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: alignment,
        radius: radius,
        colors: <Color>[
          AppGradients.onGradient.withValues(alpha: strength),
          AppGradients.onGradient.withValues(alpha: 0),
        ],
      ),
    ),
    child: child,
  );
}

/// The tint used for a gradient surface's shadow in the current theme.
Color gradientShadowTint(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFF04090C)
    : const Color(0xFF432B23);
