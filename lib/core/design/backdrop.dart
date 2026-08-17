import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/color_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';

/// The product's signature background.
///
/// ## Why the app has a backdrop at all
///
/// A flat surface colour is correct and forgettable. The identity is an ember
/// against deep water, and the canvas is where that is stated: warm light in
/// one corner, cool green-blue in the opposite one, with the surface colour
/// holding the middle. It gives every screen a direction of light, which is
/// what makes the panels on top read as lit objects rather than as fills.
///
/// ## Why it settles rather than loops
///
/// The lights drift into place when a screen appears and then hold. A looping
/// wash was the first version and it was wrong twice over. It puts permanent
/// motion in the periphery of a screen somebody is reading on, which is a
/// known vestibular trigger and flatly contradicts this codebase's own rule
/// that motion explains a change rather than decorating one. And it never
/// settles, so every widget test that waits for the interface to come to rest
/// waits forever — which is how it was found.
///
/// Arriving is a change, so animating the arrival is honest: the canvas
/// resolves under the content as the page comes in, and then the screen is
/// still. It stops dead when the reader has asked for reduced motion, and the
/// wash is fainter on screens that are mostly prose.
///
/// It is gradients and no blur, because a real blur filter on a full-screen
/// surface costs more than the entire rest of a frame on a mid-range phone.
class LamplightBackdrop extends StatefulWidget {
  const LamplightBackdrop({
    required this.child,
    this.intensity = 1.0,
    super.key,
  });

  /// The screen content, painted over the backdrop.
  final Widget child;

  /// Scales the wash. Screens that are mostly text use less of it; the home
  /// screen, which is the product's face, uses all of it.
  final double intensity;

  @override
  State<LamplightBackdrop> createState() => _LamplightBackdropState();
}

class _LamplightBackdropState extends State<LamplightBackdrop>
    with SingleTickerProviderStateMixin {
  /// Slow enough to read as the light settling rather than as a transition.
  static const Duration _settle = Duration(milliseconds: 1400);

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: _settle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolved here rather than in initState because it comes from MediaQuery,
    // and it can change while the app is running.
    if (Motion.isReduced(context)) {
      _drift.value = 1;
    } else if (_drift.status == AnimationStatus.dismissed) {
      _drift.forward();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    // The wash stays far enough below the surface colour that it cannot move a
    // contrast ratio the palette is asserted against. In light mode that
    // ceiling is much lower: a warm wash on warm paper greys the text long
    // before it becomes visible as an effect.
    final warmStrength = (isDark ? 0.20 : 0.06) * widget.intensity;
    final coolStrength = (isDark ? 0.24 : 0.05) * widget.intensity;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _drift,
        // Built once and reused across every frame of the drift: the content
        // is the expensive part and none of it depends on the animation.
        child: widget.child,
        builder: (context, child) {
          // Eased, and the two lights travel different distances from
          // different directions, so the canvas resolves rather than slides.
          final t = Curves.easeOutCubic.transform(_drift.value);
          final warm = Alignment(
            -0.85 + 0.30 * (1 - t),
            -1.05 - 0.18 * (1 - t),
          );
          final cool = Alignment(1.05 + 0.26 * (1 - t), 0.95 + 0.20 * (1 - t));
          final arrival = 0.35 + 0.65 * t;

          return DecoratedBox(
            decoration: BoxDecoration(color: scheme.surface),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: warm,
                  radius: 1.35,
                  colors: <Color>[
                    AppColors.auroraWarm.withValues(
                      alpha: warmStrength * arrival,
                    ),
                    // Fading to the same hue at zero alpha rather than to
                    // transparent black, which would grey the midpoint.
                    AppColors.auroraWarm.withValues(alpha: 0),
                  ],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: cool,
                    radius: 1.5,
                    colors: <Color>[
                      AppColors.auroraCool.withValues(
                        alpha: coolStrength * arrival,
                      ),
                      AppColors.auroraCool.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
