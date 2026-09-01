import 'package:flutter/material.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/gradients.dart';
import 'package:philosophyy/core/design/motion.dart';

/// A feature surface painted with a gradient rather than a flat fill.
///
/// Everything about the type on top is fixed here — one foreground colour, one
/// muted foreground — so a caller cannot land a label on a stop it cannot be
/// read against. That constraint is the whole reason the ramp in
/// [AppGradients] is safe to hand out by index.
class GradientCard extends StatelessWidget {
  const GradientCard({
    required this.child,
    this.gradient = AppGradients.hero,
    this.onTap,
    this.padding = const EdgeInsets.all(Spacing.lg),
    this.borderRadius = Radii.surfaceRadius,
    this.sheenAlignment = const Alignment(0.95, -0.95),
    this.strongShadow = false,
    this.semanticLabel,
    super.key,
  });

  final Widget child;
  final LinearGradient gradient;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Alignment sheenAlignment;

  /// A deeper shadow, for the one hero surface on a screen.
  final bool strongShadow;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: AppGradients.shadowFor(
          gradientShadowTint(context),
          strong: strongShadow,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: GradientSheen(
          alignment: sheenAlignment,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );

    if (onTap == null) {
      return semanticLabel == null
          ? surface
          : Semantics(label: semanticLabel, child: surface);
    }

    // The gradient is painted here rather than handed to PressableSurface's
    // decoration, because the sheen and the clip have to sit between the fill
    // and the content. PressableSurface still supplies the scale and the ink.
    return PressableSurface(
      onTap: onTap,
      borderRadius: borderRadius,
      semanticLabel: semanticLabel,
      child: surface,
    );
  }
}

/// The default text style for content inside a [GradientCard].
///
/// Applied by the callers rather than by the card, so a caller can still choose
/// a size; what it cannot choose is a colour that would fail on the ramp.
TextStyle onGradientStyle(TextStyle? base) =>
    (base ?? const TextStyle()).copyWith(color: AppGradients.onGradient);

/// A square-ish tile: an icon in a tinted chip, a title, a caption.
///
/// The grid these form is how the reference product opens, and it works for a
/// reason worth stating: a list of links tells you what exists, while a grid of
/// tiles tells you how many kinds of thing exist, which is the question someone
/// opening a reference work for the first time actually has.
class TileCard extends StatelessWidget {
  const TileCard({
    required this.icon,
    required this.title,
    this.caption,
    this.badge,
    this.onTap,
    this.accent,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? caption;

  /// A short word shown in a pill in the corner — "new", "AI".
  final String? badge;

  final VoidCallback? onTap;

  /// Tint for the icon chip. Defaults to the theme's primary.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = this.accent ?? theme.colorScheme.primary;
    final caption = this.caption;
    final badge = this.badge;

    return PressableSurface(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
      decoration: BoxDecoration(
        color: Glass.fill(context),
        borderRadius: const BorderRadius.all(Radius.circular(Radii.lg)),
        border: Border.all(color: Glass.border(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // The icon sits at the top of the tile and the words at the bottom,
          // so a grid of tiles has two alignment lines running across it
          // rather than a ragged edge wherever a title happens to wrap.
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                // The icon chip carries a trace of the accent's bloom rather
                // than a flat tint. It is a tenth of the strength the primary
                // action uses, which is enough to look lit and not enough to
                // compete with the one thing on the screen that is asking to
                // be pressed.
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(Radii.md),
                    ),
                    boxShadow: Glass.glow(accent, strength: 0.35),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(Spacing.md),
                    child: Icon(icon, size: 22, color: accent),
                  ),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(Radii.pill),
                      ),
                    ),
                    child: Text(
                      badge,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
              ],
            ),
            // `Expanded`, not `Flexible`: loose flex only *permits* the child
            // to be smaller, so a text block one pixel taller than the space
            // left still overflowed. A tight fit hands it exactly the room
            // that remains, and the ellipsis takes it from there — which means
            // no measurement of the caller's can put a yellow-and-black stripe
            // across the front page, however close it runs.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (caption != null) ...<Widget>[
                      const SizedBox(height: Spacing.xxs),
                      Flexible(
                        child: Text(
                          caption,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
