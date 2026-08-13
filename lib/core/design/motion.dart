import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';

/// Motion primitives.
///
/// ## The rule everything here follows
///
/// Motion explains a change; it never decorates one. Content arrives with a
/// short rise and fade because that tells the eye where the page begins and in
/// what order to read it. Nothing bounces, nothing spins, and nothing makes the
/// reader wait: the longest duration in the system is just over half a second,
/// and it is used once per screen.
///
/// Every animation in this file collapses to zero when the platform reports
/// that the reader has asked for reduced motion. That is checked by
/// `test/core/design/motion_test.dart`, because an accessibility setting that
/// is honoured by most of an interface is not honoured at all — the one screen
/// that ignores it is the one that causes the migraine.
abstract final class Motion {
  /// Whether the platform says this reader wants motion kept to a minimum.
  static bool isReduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero if the reader has asked for reduced motion.
  static Duration duration(BuildContext context, Duration duration) =>
      isReduced(context) ? Duration.zero : duration;
}

/// Fades and lifts its child into place.
///
/// [index] staggers items in a list. The delay is expressed as an [Interval]
/// inside one controller rather than by starting a timer, so the animation is
/// deterministic, settles predictably in tests, and cannot leave a widget
/// half-arrived if it is disposed mid-flight.
class EntranceAnimation extends StatefulWidget {
  const EntranceAnimation({
    required this.child,
    this.index = 0,
    this.distance = 16,
    this.duration = MotionTokens.moderate,
    this.stagger = const Duration(milliseconds: 55),
    this.maxStaggeredItems = 8,
    super.key,
  });

  /// The content to bring in.
  final Widget child;

  /// Position in a list, used to stagger arrival.
  final int index;

  /// How far the child rises, in logical pixels.
  final double distance;

  /// How long one item takes to arrive.
  final Duration duration;

  /// The gap between consecutive items.
  final Duration stagger;

  /// Items beyond this index arrive together.
  ///
  /// Without a cap, the fortieth item in a list would wait two seconds before
  /// appearing, and a reader who scrolls fast would watch an empty screen fill
  /// in behind them.
  final int maxStaggeredItems;

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, widget.maxStaggeredItems);
    final delay = widget.stagger * steps;
    final total = delay + widget.duration;

    _controller = AnimationController(vsync: this, duration: total);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        total.inMicroseconds == 0
            ? 0
            : delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: MotionTokens.enter,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion is resolved here rather than in initState because it comes
    // from MediaQuery, and it can change while the app is running.
    if (Motion.isReduced(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, child) => Opacity(
      opacity: _progress.value.clamp(0, 1),
      child: Transform.translate(
        offset: Offset(0, widget.distance * (1 - _progress.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// A surface that acknowledges a press by shrinking very slightly.
///
/// Material's ink ripple communicates *where* a touch landed. On a large card
/// it does not communicate that the whole card is one target, which is what a
/// reader needs to know before they commit to the tap. The scale is deliberately
/// small — at 0.98 it registers as physical rather than as an effect.
class PressableSurface extends StatefulWidget {
  const PressableSurface({
    required this.child,
    required this.onTap,
    this.decoration,
    this.borderRadius = Radii.cardRadius,
    this.pressedScale = 0.98,
    this.semanticLabel,
    super.key,
  });

  /// The surface content.
  final Widget child;

  /// Invoked on tap. A null callback disables the press response entirely.
  final VoidCallback? onTap;

  /// The surface's background, painted *behind* the ink.
  ///
  /// Callers must pass their background here rather than painting it inside
  /// [child]. Ink splashes are drawn by the [Material] underneath its child, so
  /// an opaque background supplied as the child hides the ripple completely —
  /// the touch feedback is still running, and simply cannot be seen.
  final BoxDecoration? decoration;

  /// Corner radius used for the ink effect.
  final BorderRadius borderRadius;

  /// Scale at full press.
  final double pressedScale;

  /// Accessibility label for the whole surface.
  final String? semanticLabel;

  @override
  State<PressableSurface> createState() => _PressableSurfaceState();
}

class _PressableSurfaceState extends State<PressableSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionTokens.instant,
    reverseDuration: MotionTokens.quick,
    lowerBound: 0,
    upperBound: 1,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (Motion.isReduced(context) || widget.onTap == null) return;
    if (pressed) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;

    return Semantics(
      container: true,
      button: enabled,
      label: widget.semanticLabel,
      // A raw Listener rather than a GestureDetector: a second tap recogniser
      // wrapped around the InkWell would join the same gesture arena, and the
      // arena does not resolve until the pointer lifts — so the press response
      // would appear at the moment the press ended, which is worse than not
      // having one. Listener sees pointer events directly and never competes.
      child: Listener(
        onPointerDown: enabled ? (_) => _setPressed(true) : null,
        onPointerUp: enabled ? (_) => _setPressed(false) : null,
        onPointerCancel: enabled ? (_) => _setPressed(false) : null,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Transform.scale(
            scale: 1 - (1 - widget.pressedScale) * _controller.value,
            child: child,
          ),
          child: _decorated(
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: widget.borderRadius,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wraps [surface] in the caller's background, so that the background sits
  /// beneath the [Material] and the ink can be seen on top of it.
  Widget _decorated(Widget surface) {
    final decoration = widget.decoration;
    if (decoration == null) return surface;
    return DecoratedBox(
      decoration: decoration,
      // Clipped so a splash cannot escape a rounded corner.
      child: ClipRRect(borderRadius: widget.borderRadius, child: surface),
    );
  }
}

/// Cross-fades between two states without the height jump a plain swap causes.
///
/// Used by the depth selector, where changing depth replaces the whole article.
/// Without this the page snaps to a new length while the reader's eye is still
/// on the old text.
class SmoothSwitcher extends StatelessWidget {
  const SmoothSwitcher({required this.child, this.alignment, super.key});

  /// The current content. Give it a key that changes when the state changes.
  final Widget child;

  /// How the outgoing and incoming children are aligned during the swap.
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: Motion.duration(context, MotionTokens.quick),
    curve: MotionTokens.standard,
    alignment: alignment ?? AlignmentDirectional.topStart,
    child: AnimatedSwitcher(
      duration: Motion.duration(context, MotionTokens.quick),
      switchInCurve: MotionTokens.enter,
      switchOutCurve: MotionTokens.exit,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: alignment ?? AlignmentDirectional.topStart,
        children: <Widget>[...previousChildren, ?currentChild],
      ),
      child: child,
    ),
  );
}

/// Screen-transition builders.
///
/// These are plain Flutter transition builders rather than router pages, so
/// that the design layer stays independent of the routing package. The router
/// wraps them; nothing here knows that go_router exists.
abstract final class PageTransitions {
  /// Opening an article.
  ///
  /// A shared-axis movement: the outgoing screen drifts back slightly while the
  /// incoming one rises and fades in. It reads as "further in" rather than
  /// "somewhere else", which is what tapping into an entry actually means.
  static Widget article(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (Motion.isReduced(context)) return child;

    final entering = CurvedAnimation(
      parent: animation,
      curve: MotionTokens.enter,
      reverseCurve: MotionTokens.exit,
    );
    final leaving = CurvedAnimation(
      parent: secondaryAnimation,
      curve: MotionTokens.standard,
    );

    return FadeTransition(
      opacity: entering,
      child: AnimatedBuilder(
        animation: leaving,
        builder: (context, inner) => Transform.translate(
          offset: Offset(0, -12 * leaving.value),
          child: inner,
        ),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(entering),
          child: child,
        ),
      ),
    );
  }

  /// Moving between the tabbed sections.
  ///
  /// The sections sit alongside each other rather than inside each other, so
  /// this is a plain fade with no directional movement that would imply a
  /// hierarchy that does not exist.
  static Widget section(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => Motion.isReduced(context)
      ? child
      : FadeTransition(opacity: animation, child: child);
}
