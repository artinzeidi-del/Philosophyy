import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:philosophyy/app/providers.dart';
import 'package:philosophyy/app/router.dart';
import 'package:philosophyy/core/design/design_tokens.dart';
import 'package:philosophyy/core/design/glass.dart';
import 'package:philosophyy/core/design/motion.dart';
import 'package:philosophyy/core/format/number_format.dart';
import 'package:philosophyy/domain/value_objects/app_language.dart';
import 'package:philosophyy/domain/value_objects/ranks.dart';
import 'package:philosophyy/l10n/generated/app_localizations.dart';

/// The reader's standing, at the head of the home screen.
///
/// ## What it is measuring
///
/// Facts from the corpus that the reader has answered a question about
/// correctly, against every fact the corpus can build a question from. Not
/// answers given, not rounds played — see [Ranks] for why, and for why the
/// denominator is the whole corpus rather than the part they have read.
///
/// ## Why it is a rank and not a score
///
/// A number going up is a number going up. A rank is a claim about the reader,
/// and the last one is not handed out for effort: it needs every fact the app
/// can ask about, which means having read the whole thing.
class RankBanner extends ConsumerWidget {
  const RankBanner({super.key});

  /// The name of a rank, from its index.
  ///
  /// A switch rather than a list, because the generated localisations expose
  /// one getter per string and there is no way to index them. The `_` case
  /// cannot be reached — [Ranks.thresholds] has nine entries — but leaving it
  /// out would make adding a tenth rank a silent failure rather than a
  /// compile error waiting to happen.
  static String nameFor(AppL10n l10n, int level) => switch (level) {
    0 => l10n.rank1,
    1 => l10n.rank2,
    2 => l10n.rank3,
    3 => l10n.rank4,
    4 => l10n.rank5,
    5 => l10n.rank6,
    6 => l10n.rank7,
    7 => l10n.rank8,
    _ => l10n.rank9,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppL10n.of(context);
    final language = ref.watch(activeLanguageProvider);
    final rank = ref.watch(readerRankProvider);

    // Nothing to show before the corpus has loaded: a bar reporting zero of
    // zero would tell the reader they had answered everything.
    if (rank.total <= 0) return const SizedBox.shrink();

    final toNext = rank.toNext;
    final subtitle = rank.mastered == 0
        ? l10n.rankStart
        : rank.isTop
        ? l10n.rankTop
        : AppNumbers.localizeDigits(l10n.rankToNext(toNext ?? 0), language);

    // The label goes on the surface that carries the tap, not on a wrapper
    // around it. Wrapped, a screen reader met two nodes: a container that read
    // the rank, and inside it a button with no name at all — and the button is
    // the one a reader lands on.
    return PressableSurface(
      onTap: () => context.push(AppRouter.quiz),
      borderRadius: Radii.surfaceRadius,
      semanticLabel:
          '${nameFor(l10n, rank.level)}. '
          '${l10n.rankLevel(rank.displayLevel, Ranks.count)}. $subtitle',
      // The one lit surface on the screen after the daily quotation. The
      // glow is the accent's, because this is the thing on the page that is
      // live — it moves when the reader does something.
      decoration: BoxDecoration(
        gradient: Glass.surfaceGradient(context),
        borderRadius: Radii.surfaceRadius,
        border: Border.all(color: scheme.primary.withValues(alpha: 0.32)),
        boxShadow: Glass.glow(scheme.primary, strength: 0.45),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  _RankMedal(level: rank.level),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          nameFor(l10n, rank.level),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.primary,
                          ),
                        ),
                        Text(
                          AppNumbers.localizeDigits(
                            l10n.rankLevel(rank.displayLevel, Ranks.count),
                            language,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              _RankBar(progress: rank.progress),
              const SizedBox(height: Spacing.sm),
              // A `Wrap`, not a `Row`. Both halves are sentences whose
              // length depends on the language and on how many facts the
              // corpus holds, and on a 320-wide phone the Persian pair
              // overflowed by eleven pixels. `Expanded` on the first does
              // not help: the second cannot be made narrower than its own
              // words. When they no longer fit side by side the count drops
              // to its own line.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Spacing.md,
                runSpacing: Spacing.xs,
                children: <Widget>[
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    AppNumbers.localizeDigits(
                      l10n.rankMastered(rank.mastered, rank.total),
                      language,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar itself: a track with a lit fill that grows.
class _RankBar extends StatelessWidget {
  const _RankBar({required this.progress});

  /// How far along the current rank, from 0 to 1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // `LayoutBuilder` rather than a `FractionallySizedBox`, so the fill can
    // carry its own glow: a fraction of the parent cannot cast a shadow past
    // its own edge, and the bloom is what makes the fill read as lit rather
    // than as a coloured rectangle.
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        height: 10,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
          border: Border.all(color: Glass.border(context)),
        ),
        child: Align(
          // Directional, so the bar fills from the right in Persian. A bar
          // that fills leftwards in a right-to-left script reads as draining.
          alignment: AlignmentDirectional.centerStart,
          child: AnimatedContainer(
            duration: Motion.duration(context, MotionTokens.moderate),
            curve: MotionTokens.standard,
            width: (constraints.maxWidth * progress).clamp(
              // Never nothing: an empty track and a full one look the same
              // from across a room, and a reader who has just answered their
              // first question should see that something happened.
              progress > 0 ? 12.0 : 0.0,
              constraints.maxWidth,
            ),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(Radii.pill)),
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: <Color>[
                  scheme.primary.withValues(alpha: 0.75),
                  scheme.primary,
                ],
              ),
              boxShadow: Glass.glow(scheme.primary, strength: 0.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// The badge beside the rank's name.
///
/// Its ring fills as the ladder is climbed, so the shape says how far along the
/// whole thing the reader is while the bar says how far along this rung.
class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CircularProgressIndicator(
            value: (level + 1) / Ranks.count,
            strokeWidth: 3,
            backgroundColor: scheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  scheme.primary.withValues(alpha: 0.28),
                  scheme.primary.withValues(alpha: 0.14),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              // The rank's number rather than an icon: nine ranks need nine
              // distinguishable marks, and nine icons that mean nothing in
              // particular are harder to tell apart than nine numerals.
              AppNumbers.localizeDigits(
                '${level + 1}',
                Localizations.localeOf(context).languageCode == 'fa'
                    ? AppLanguage.fa
                    : AppLanguage.en,
              ),
              // The foreground, not the accent. The disc is already tinted
              // with the accent, and an accent numeral on an accent disc came
              // out at 3.43:1 in the dark theme — the painted-contrast sweep
              // named it. The ring around it carries the accent; the numeral
              // only has to be read.
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
