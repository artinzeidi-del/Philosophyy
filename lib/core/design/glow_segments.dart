import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/motion.dart';

/// A segmented control: a glass track with one lit segment that slides.
///
/// ## Why not `SegmentedButton`
///
/// Material's control is a row of outlined boxes with dividers between them,
/// and selecting one repaints it. Nothing moves, so the eye has to find the
/// selection again after every tap, and the divider rules make it read as a
/// table header rather than as a switch.
///
/// Here the selection is a single object that travels. It is the same object
/// before and after the tap, so the eye follows it instead of re-reading the
/// row — which is the whole reason to animate a control at all, and the reason
/// the movement is worth its cost.
///
/// ## The lit segment
///
/// The selection is a gradient that runs from the accent's shadow to the
/// accent itself, brightest at its leading edge, over a bloom in the same
/// colour. That is the shape the reference navigation uses, and it does a
/// specific job: a flat fill of the accent is a button, while a fill that is
/// brighter at one end reads as lit from somewhere, which is what makes it
/// look active rather than merely coloured.
///
/// The track is glass so the canvas shows through it, and the unselected
/// labels are quiet. Only one thing here is meant to be loud.
class GlowSegments<T> extends StatelessWidget {
  const GlowSegments({
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.expand = false,
    super.key,
  });

  /// The options, in the order they are shown.
  final List<GlowSegment<T>> segments;

  final T selected;
  final ValueChanged<T> onChanged;

  /// Whether the control fills the width it is given.
  ///
  /// A control that names three reading depths wants to be as wide as its
  /// content; one that switches the axis of a whole screen can take the
  /// column.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = segments.indexWhere((segment) => segment.value == selected);
    final count = segments.length;

    final track = DecoratedBox(
      decoration: BoxDecoration(
        color: Glass.fill(context, tint: theme.colorScheme.surfaceContainer),
        borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
        border: Border.all(color: Glass.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: <Widget>[
            // The lit segment is placed by fraction rather than by pixels, so
            // it stays correct at a width this widget never measured. That
            // only works because every segment is the same width: the labels
            // are `Expanded`, and a `Row` inside an `IntrinsicWidth` reports
            // the widest child's intrinsic width for all of them. With
            // content-sized segments the highlight sat under the wrong words.
            if (index >= 0)
              Positioned.fill(
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  alignment: AlignmentDirectional(
                    // -1 at the first segment, +1 at the last; a single
                    // segment sits in the middle rather than dividing by zero.
                    count == 1 ? 0 : (index / (count - 1)) * 2 - 1,
                    0,
                  ),
                  child: _LitSegment(
                    duration: Motion.duration(context, MotionTokens.quick),
                  ),
                ),
              ),
            Row(
              children: <Widget>[
                for (final segment in segments)
                  Expanded(
                    child: _SegmentLabel(
                      segment: segment,
                      selected: segment.value == selected,
                      onTap: () => onChanged(segment.value),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return expand ? track : IntrinsicWidth(child: track);
  }
}

/// One option in a [GlowSegments].
class GlowSegment<T> {
  const GlowSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// The travelling highlight.
class _LitSegment extends StatelessWidget {
  const _LitSegment({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return AnimatedContainer(
      duration: duration,
      curve: MotionTokens.standard,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
        gradient: LinearGradient(
          // Brightest at the trailing edge, so the segment looks lit from one
          // side rather than filled.
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: <Color>[accent.withValues(alpha: 0.55), accent],
        ),
        boxShadow: Glass.glow(accent, strength: 0.85),
      ),
    );
  }
}

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final GlowSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = segment.icon;

    final content = AnimatedDefaultTextStyle(
      duration: Motion.duration(context, MotionTokens.quick),
      style: (theme.textTheme.labelLarge ?? const TextStyle()).copyWith(
        // On the lit segment, and only there, the label is drawn in the ink
        // the accent is built to carry.
        color: selected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 18,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.sm),
            ],
            Flexible(
              child: Text(
                segment.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      selected: selected,
      button: true,
      label: segment.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
          child: content,
        ),
      ),
    );
  }
}
