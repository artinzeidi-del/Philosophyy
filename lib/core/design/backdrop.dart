import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/color_tokens.dart';

/// The product's signature background.
///
/// ## Why the app has a backdrop at all
///
/// A flat surface colour is correct and forgettable. The identity here is "ink
/// and lamplight", and a lamp implies a source — so both themes carry a soft
/// pool of light falling from the top of the screen, where a reading lamp would
/// be. In dark mode it reads as warmth in a dark room; in light mode it reads as
/// the faint warm cast of paper near a window.
///
/// The effect is deliberately near-subliminal. Measured against the flat
/// surface colour it is a few percent of luminance, which is enough to give the
/// screen a centre of gravity and not enough to be noticed as an effect — and,
/// importantly, not enough to disturb the contrast ratios the palette is
/// asserted against, since the glow sits behind content rather than under text
/// that has to stay legible.
///
/// It is two gradients and no blur, because a real blur filter on a full-screen
/// surface costs more than the entire rest of a frame on a mid-range phone.
class LamplightBackdrop extends StatelessWidget {
  const LamplightBackdrop({
    required this.child,
    this.intensity = 1.0,
    super.key,
  });

  /// The screen content, painted over the backdrop.
  final Widget child;

  /// Scales the glow. Screens that are mostly text use less of it; the home
  /// screen, which is the product's face, uses all of it.
  final double intensity;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    // Warm light from above, cooling into the surface colour.
    final warm = isDark ? AppColors.goldLight : AppColors.gold;
    final cool = isDark ? AppColors.lapisLight : AppColors.lapis;

    final warmStrength = (isDark ? 0.085 : 0.055) * intensity;
    final coolStrength = (isDark ? 0.060 : 0.030) * intensity;

    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surface),
      child: DecoratedBox(
        // The lamp: a wide pool falling from above.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.25),
            radius: 1.5,
            colors: <Color>[
              warm.withValues(alpha: warmStrength),
              // Fading to the same hue at zero alpha rather than to
              // transparent black, which would grey the midpoint of the ramp.
              warm.withValues(alpha: 0),
            ],
            stops: const <double>[0, 1],
          ),
        ),
        child: DecoratedBox(
          // A cool counterweight low on the screen, so the warmth reads as
          // directional light rather than as a colour cast over everything.
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 1.4),
              radius: 1.3,
              colors: <Color>[
                cool.withValues(alpha: coolStrength),
                cool.withValues(alpha: 0),
              ],
              stops: const <double>[0, 1],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// A short decorative rule used under a screen's title.
///
/// Two weights of the accent, tapering out — a printer's device rather than a
/// full-width divider, which would cut the page in half.
class TitleRule extends StatelessWidget {
  const TitleRule({this.width = 56, super.key});

  /// The rule's length in logical pixels.
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: <Color>[
              scheme.secondary,
              scheme.secondary.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
