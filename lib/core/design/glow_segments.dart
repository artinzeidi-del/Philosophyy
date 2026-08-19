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
/// row — which is the whole reason to animate a control at all.
///
/// ## Why the row is drawn twice
///
/// The obvious build is a highlight floating over one row of labels, with each
/// label choosing its own colour from whether it is selected. That was the
/// first version and it has two faults. The label's colour snaps at the moment
/// of the tap while the highlight is still travelling, so for two hundred
/// milliseconds there is dark ink on the unlit track. And the highlight is a
/// *sibling* of the text rather than an ancestor, so nothing — not a reader
/// squinting at it, and not the contrast check in `test/support` — can tell
/// what is actually painted behind those words.
///
/// So the row is drawn twice: once in the quiet colour, and once in the ink
/// the accent carries, clipped to the highlight. The second copy is positioned
/// so its words land exactly on the first copy's, which means the colour
/// changes as the highlight passes over each label rather than when the tap
/// lands, and every label genuinely sits on the surface it is measured against.
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

  /// The gap between the track's edge and the lit segment.
  static const double _inset = 4;

  /// The smallest a segment may be.
  static const double minimumTapTarget = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final index = segments.indexWhere((segment) => segment.value == selected);
    final duration = Motion.duration(context, MotionTokens.quick);

    final track = DecoratedBox(
      decoration: BoxDecoration(
        color: Glass.fill(context, tint: theme.colorScheme.surfaceContainer),
        borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
        border: Border.all(color: Glass.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(_inset),
        child: TweenAnimationBuilder<double>(
          duration: duration,
          curve: MotionTokens.standard,
          // -1 at the first segment, +1 at the last; one segment sits in the
          // middle rather than dividing by zero. Animating the fraction rather
          // than a pixel offset is what lets this work without measuring: an
          // earlier version used a `LayoutBuilder` for the width and threw,
          // because `IntrinsicWidth` asks its child for intrinsic dimensions
          // and a `LayoutBuilder` cannot answer.
          tween: Tween<double>(
            end: segments.length == 1 || index < 0
                ? 0
                : (index / (segments.length - 1)) * 2 - 1,
          ),
          builder: (context, position, _) => Stack(
            children: <Widget>[
              // The bloom, under everything and outside the clip, so it can
              // spill past the segment's edge the way light does.
              if (index >= 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: 1 / segments.length,
                    alignment: AlignmentDirectional(position, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(Radii.pill),
                        ),
                        boxShadow: Glass.glow(
                          theme.colorScheme.primary,
                          strength: 0.85,
                        ),
                      ),
                    ),
                  ),
                ),
              _Row(
                segments: segments,
                colour: theme.colorScheme.onSurfaceVariant,
                onTap: onChanged,
              ),
              if (index >= 0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    widthFactor: 1 / segments.length,
                    alignment: AlignmentDirectional(position, 0),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(
                        Radius.circular(Radii.pill),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            // Brightest at the trailing edge, so the segment
                            // looks lit from one side rather than filled.
                            begin: AlignmentDirectional.centerStart,
                            end: AlignmentDirectional.centerEnd,
                            colors: <Color>[
                              theme.colorScheme.primary.withValues(alpha: 0.82),
                              theme.colorScheme.primary,
                            ],
                          ),
                        ),
                        // The second copy of the row, blown back up to the
                        // track's full width inside a window one segment wide.
                        // Aligned by the same fraction, the two cancel exactly:
                        // the copy lands at the track's own left edge whatever
                        // the width turns out to be, so its words sit on the
                        // first copy's without either of them being measured.
                        child: FractionallySizedBox(
                          widthFactor: segments.length.toDouble(),
                          alignment: AlignmentDirectional(position, 0),
                          child: _Row(
                            segments: segments,
                            colour: theme.colorScheme.onPrimary,
                            // The copy is decoration: the row underneath takes
                            // every tap, and two hit targets in one place would
                            // double every gesture.
                            onTap: null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

/// One pass of the labels, all in the same colour.
class _Row<T> extends StatelessWidget {
  const _Row({
    required this.segments,
    required this.colour,
    required this.onTap,
  });

  final List<GlowSegment<T>> segments;
  final Color colour;
  final ValueChanged<T>? onTap;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (final segment in segments)
        Expanded(
          child: _SegmentLabel<T>(
            segment: segment,
            colour: colour,
            onTap: onTap == null ? null : () => onTap!(segment.value),
          ),
        ),
    ],
  );
}

/// Vertical padding chosen so a segment reaches the platform minimum touch
/// target. The spacing token gave 44, four short of it.
const double _segmentPadding = 14;

class _SegmentLabel<T> extends StatelessWidget {
  const _SegmentLabel({
    required this.segment,
    required this.colour,
    required this.onTap,
  });

  final GlowSegment<T> segment;
  final Color colour;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = segment.icon;

    // A minimum height rather than padding alone. The segments came out 44
    // tall, four short of the figure Android's accessibility guideline asks
    // for, and this control is how a reader changes what the whole screen is
    // showing. Nothing looked wrong; the guideline check said so.
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: _segmentPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: colour),
            const SizedBox(width: Spacing.sm),
          ],
          Flexible(
            child: Text(
              segment.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(color: colour),
            ),
          ),
        ],
      ),
    );

    // The lit copy is not interactive and must not be announced: it would give
    // a screen reader the same control twice.
    if (onTap == null) return ExcludeSemantics(child: content);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
        child: content,
      ),
    );
  }
}
