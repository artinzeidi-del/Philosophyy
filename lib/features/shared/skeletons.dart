import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// A placeholder block shaped like the content that will replace it.
///
/// Skeletons are used instead of a spinner because they say something a spinner
/// cannot: what is coming, and roughly how much of it. The pulse is a slow
/// opacity change rather than a travelling shimmer — a shimmer draws the eye to
/// the loading state, which is exactly the wrong place to send it.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    required this.width,
    required this.height,
    this.radius = Radii.sm,
    super.key,
  });

  /// Width in logical pixels. Use `double.infinity` to fill.
  final double width;

  /// Height in logical pixels.
  final double height;

  /// Corner radius.
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.isReduced(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            scheme.surfaceContainer,
            scheme.surfaceContainerHighest,
            _controller.value,
          ),
          borderRadius: BorderRadius.all(Radius.circular(widget.radius)),
        ),
      ),
    );
  }
}

/// A loading state shaped like a list of cards.
///
/// Used by the browsing and search screens, whose content is a column of
/// equally weighted cards rather than the home screen's feature-then-list
/// arrangement.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.rows = 5, super.key});

  /// How many placeholder cards to draw.
  final int rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Semantics(
      label: l10n.loading,
      liveRegion: true,
      child: ExcludeSemantics(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xxl,
              Spacing.lg,
              Spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SkeletonBox(width: 140, height: 20),
                const SizedBox(height: Spacing.lg),
                for (var index = 0; index < rows; index++) ...<Widget>[
                  const SkeletonBox(
                    width: double.infinity,
                    height: 118,
                    radius: Radii.lg,
                  ),
                  const SizedBox(height: Spacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The home screen's loading state, shaped like the home screen.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Semantics(
      label: l10n.loading,
      liveRegion: true,
      // The individual blocks carry no information, so they are hidden from
      // screen readers; the one label above is what should be announced.
      child: ExcludeSemantics(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.lg,
              Spacing.xxl,
              Spacing.lg,
              Spacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SkeletonBox(width: 220, height: 44),
                const SizedBox(height: Spacing.md),
                const SkeletonBox(width: 160, height: 16),
                const SizedBox(height: Spacing.xxl),
                const SkeletonBox(
                  width: double.infinity,
                  height: 150,
                  radius: Radii.md,
                ),
                const SizedBox(height: Spacing.xxl),
                const SkeletonBox(width: 110, height: 18),
                const SizedBox(height: Spacing.lg),
                for (var index = 0; index < 3; index++) ...<Widget>[
                  const SkeletonBox(
                    width: double.infinity,
                    height: 118,
                    radius: Radii.md,
                  ),
                  const SizedBox(height: Spacing.md),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
