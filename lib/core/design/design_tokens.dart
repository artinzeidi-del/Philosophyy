import 'package:flutter/widgets.dart';

/// The spacing scale.
///
/// Every gap in the product comes from this scale. Ad-hoc padding values are
/// what make an interface feel subtly incoherent, so there are no magic numbers
/// in widget code — only these names.
abstract final class Spacing {
  /// 2 — hairline separation inside dense controls.
  static const double xxs = 2;

  /// 4 — between tightly related items such as a label and its icon.
  static const double xs = 4;

  /// 8 — the default gap inside a component.
  static const double sm = 8;

  /// 12 — between related components.
  static const double md = 12;

  /// 16 — the default screen gutter and card padding.
  static const double lg = 16;

  /// 24 — between distinct groups on a screen.
  static const double xl = 24;

  /// 32 — between major sections.
  static const double xxl = 32;

  /// 48 — around a screen's emotional focal point.
  static const double xxxl = 48;
}

/// The corner-radius scale.
abstract final class Radii {
  /// 6 — chips, tags and other small surfaces.
  static const double sm = 6;

  /// 12 — the default for cards and inputs.
  static const double md = 12;

  /// 20 — large feature surfaces and sheets.
  static const double lg = 20;

  /// 28 — modal sheets and dialogs.
  static const double xl = 28;

  /// Fully rounded — pills and avatars.
  static const double pill = 999;

  /// Convenience [BorderRadius] for [md].
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));

  /// Convenience [BorderRadius] for [lg].
  static const BorderRadius surfaceRadius = BorderRadius.all(
    Radius.circular(lg),
  );
}

/// Motion durations and curves.
///
/// Motion here is used to explain a change of state, never to decorate. All
/// durations are short enough that the interface never makes the reader wait
/// on an animation, and every consumer must respect the platform's
/// reduce-motion setting — see `Motion.duration` in core/design/motion.dart.
abstract final class MotionTokens {
  /// 120ms — a control acknowledging a press.
  static const Duration instant = Duration(milliseconds: 120);

  /// 200ms — the default for state changes within a screen.
  static const Duration quick = Duration(milliseconds: 200);

  /// 320ms — entering and leaving screens.
  static const Duration moderate = Duration(milliseconds: 320);

  /// 520ms — a deliberate, once-per-screen reveal.
  static const Duration deliberate = Duration(milliseconds: 520);

  /// 1100ms — one there-and-back of anything that breathes.
  ///
  /// The period of the loading shimmer and of the arrival glow. Both were
  /// carrying their own copy of this number, which is how two things that are
  /// meant to pulse together drift apart.
  static const Duration pulse = Duration(milliseconds: 1100);

  /// The standard easing for elements entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// The standard easing for elements leaving the screen.
  static const Curve exit = Curves.easeInCubic;

  /// The standard easing for a change that both starts and ends on screen.
  static const Curve standard = Curves.easeInOutCubic;

  // Reduced-motion handling lives in `Motion.duration` (core/design/motion.dart)
  // so there is exactly one way to ask the question.
}

/// Elevation levels, expressed as the shadows the design system permits.
///
/// Both themes use light, wide shadows rather than dark, tight ones; the dark
/// theme leans on surface tint instead of shadow, because shadows read poorly
/// on near-black backgrounds.
abstract final class Elevations {
  /// Flat against the background.
  static const double none = 0;

  /// A card lifted just off the background.
  static const double card = 1;

  /// A raised, interactive surface.
  static const double raised = 3;

  /// A floating surface such as a menu.
  static const double floating = 6;

  /// A modal surface.
  static const double modal = 12;
}

/// Layout breakpoints.
///
/// The product is designed for reading, so the constraint that matters most is
/// measure — the line length of body text — not device class.
abstract final class Breakpoints {
  /// Below this width, a single column with full-width components.
  static const double compact = 600;

  /// Tablet and small desktop: two columns become viable.
  static const double medium = 900;

  /// Large desktop: a persistent navigation rail plus content plus context.
  static const double expanded = 1240;

  /// The maximum width of a body-text column, in logical pixels.
  ///
  /// Roughly 66 characters at the reader's default size, which is the range
  /// typographic convention treats as comfortable for sustained reading.
  static const double readingMeasure = 680;

  /// The maximum width of non-reading content such as card grids.
  static const double contentMaxWidth = 1100;
}
